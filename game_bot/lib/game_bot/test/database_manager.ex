defmodule GameBot.Test.DatabaseManager do
  @moduledoc """
  Centralized database management for tests.

  This module provides a single interface for all database operations needed during testing:
  - Database creation and cleanup
  - Connection pooling and management
  - Transaction handling
  - Sandbox mode configuration
  - Process monitoring and cleanup

  ## Usage

  ```elixir
  # In test_helper.exs:
  GameBot.Test.DatabaseManager.initialize()

  # In test setup:
  setup tags do
    GameBot.Test.DatabaseManager.setup_sandbox(tags)
    :ok
  end
  ```
  """

  use GenServer
  require Logger
  alias GameBot.Test.DatabaseConfig
  alias Ecto.Adapters.SQL.Sandbox
  alias GameBot.Infrastructure.Persistence.Repo

  # GenServer state structure
  defmodule State do
    @moduledoc false
    defstruct [
      :admin_conn,
      :main_db_pid,
      :event_db_pid,
      :monitor_ref,
      active_connections: %{},
      test_processes: %{},
      cleanup_scheduled: false
    ]
  end

  # Server name
  @name __MODULE__

  # Startup and initialization

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Initializes the test environment.
  This should be called once at the start of the test suite.
  """
  def initialize do
    case start_link() do
      {:ok, pid} ->
        setup_databases(pid)
      {:error, {:already_started, pid}} ->
        Logger.info("DatabaseManager already running with PID: #{inspect(pid)}")
        setup_databases(pid)
      error ->
        Logger.error("Failed to start DatabaseManager: #{inspect(error)}")
        error
    end
  end

  @doc """
  Sets up the sandbox for a test based on the provided tags.
  """
  def setup_sandbox(tags) do
    GenServer.call(@name, {:setup_sandbox, tags})
  end

  @doc """
  Cleans up all database resources.
  """
  def cleanup do
    GenServer.call(@name, :cleanup)
  end

  @doc """
  Checks out a connection for an async test.
  """
  def checkout_connection(repo) do
    GenServer.call(@name, {:checkout, repo, self()})
  end

  @doc """
  Checks in a connection after an async test.
  """
  def checkin_connection(repo) do
    GenServer.call(@name, {:checkin, repo, self()})
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    # Trap exits so we can cleanup on shutdown
    Process.flag(:trap_exit, true)

    # Set up admin connection
    case setup_admin_connection() do
      {:ok, admin_conn} ->
        # Monitor test processes for cleanup
        monitor_ref = Process.monitor(Process.whereis(ExUnit.Server))
        {:ok, %State{admin_conn: admin_conn, monitor_ref: monitor_ref}}
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:setup_sandbox, tags}, {pid, _}, state) do
    case setup_sandbox_mode(tags, pid, state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:setup_databases, {pid, _}, state) do
    case do_setup_databases(state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:checkout, repo, pid}, _from, state) do
    case checkout_connection_for_process(repo, pid, state) do
      {:ok, conn, new_state} -> {:reply, {:ok, conn}, new_state}
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:checkin, repo, pid}, _from, state) do
    new_state = checkin_connection_for_process(repo, pid, state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:cleanup, _from, state) do
    case cleanup_databases(state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, _reason}, %{monitor_ref: ref} = state) do
    # ExUnit server went down, clean up everything
    cleanup_databases(state)
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Test process went down, clean up its resources
    new_state = cleanup_test_process(pid, state)
    {:noreply, new_state}
  end

  @impl true
  def terminate(_reason, state) do
    # Ensure cleanup on shutdown
    cleanup_databases(state)
    :ok
  end

  # Private functions

  defp setup_admin_connection do
    config = DatabaseConfig.admin_config()
    case Postgrex.start_link(config) do
      {:ok, conn} ->
        # Test the connection
        case Postgrex.query(conn, "SELECT 1", [], timeout: DatabaseConfig.timeouts()[:operation_timeout]) do
          {:ok, _} -> {:ok, conn}
          error ->
            Logger.error("Failed to verify admin connection: #{inspect(error)}")
            GenServer.stop(conn)
            {:error, :connection_failed}
        end
      error ->
        Logger.error("Failed to create admin connection: #{inspect(error)}")
        error
    end
  end

  defp setup_databases(pid) do
    GenServer.call(pid, :setup_databases)
  end

  defp setup_sandbox_mode(tags, test_pid, state) do
    try do
      # Get timeout from tags or use default
      timeout = Map.get(tags, :timeout, 60_000)

      # Determine sandbox mode based on async flag
      use_async = Map.get(tags, :async, false)

      Logger.debug("Setting up sandbox mode - async: #{use_async}, timeout: #{timeout}")

      # Set up repositories with appropriate sandbox mode
      result = Enum.reduce(@repos, {:ok, state}, fn repo, acc ->
        case acc do
          {:ok, current_state} ->
            case setup_repo_sandbox(repo, use_async, test_pid, timeout) do
              :ok -> {:ok, current_state}
              {:error, reason} -> {:error, reason}
            end
          error -> error
        end
      end)

      # Return result
      result
    catch
      kind, reason ->
        stacktrace = Process.info(self(), :current_stacktrace)
        Logger.error("Failed to setup sandbox: #{inspect(reason)}, trace: #{inspect(stacktrace)}")
        {:error, {kind, reason, stacktrace}}
    end
  end

  # Helper function to set up a repository's sandbox mode
  defp setup_repo_sandbox(repo, async?, test_pid, timeout) do
    try do
      if not Process.whereis(repo) do
        Logger.error("Repository #{inspect(repo)} is not running")
        {:error, :repository_not_running}
      else
        # Configure sandbox mode based on async flag
        if async? do
          # For async tests, use shared mode with the test process
          # This mode allows the test process to share its connection with other processes
          Sandbox.mode(repo, {:shared, test_pid})
        else
          # For non-async tests, use manual mode
          # This mode requires explicit checkout but provides better isolation
          Sandbox.mode(repo, :manual)
        end

        # Always checkout a connection with appropriate timeout
        Sandbox.checkout(repo, ownership_timeout: timeout)

        # If it's an async test, we're done
        # For non-async tests, allow the test process to access the repo
        if not async? do
          Sandbox.allow(repo, test_pid, self())
        end

        :ok
      end
    rescue
      e ->
        Logger.error("Error setting up sandbox for #{inspect(repo)}: #{inspect(e)}")
        {:error, e}
    end
  end

  defp checkout_connection_for_process(repo, pid, state) do
    try do
      # Check out a connection from the pool
      :ok = Sandbox.checkout(repo)

      # Start a transaction
      :ok = Sandbox.mode(repo, {:manual, pid})

      # Track the connection
      conn = Process.whereis(repo)
      new_state = track_connection(state, repo, conn, pid)

      {:ok, conn, new_state}
    rescue
      e ->
        Logger.error("Failed to checkout connection: #{inspect(e)}")
        {:error, :checkout_failed}
    end
  end

  defp checkin_connection_for_process(repo, pid, state) do
    try do
      # End the transaction
      Sandbox.checkin(repo)

      # Remove tracking
      untrack_connection(state, repo, pid)
    rescue
      _ -> state
    end
  end

  defp track_connection(state, repo, conn, pid) do
    connections = Map.get(state.active_connections, pid, %{})
    new_connections = Map.put(connections, repo, conn)
    %{state | active_connections: Map.put(state.active_connections, pid, new_connections)}
  end

  defp untrack_connection(state, repo, pid) do
    case Map.get(state.active_connections, pid) do
      nil -> state
      connections ->
        new_connections = Map.delete(connections, repo)
        if map_size(new_connections) == 0 do
          %{state | active_connections: Map.delete(state.active_connections, pid)}
        else
          %{state | active_connections: Map.put(state.active_connections, pid, new_connections)}
        end
    end
  end

  defp cleanup_test_process(pid, state) do
    # Clean up any active connections
    case Map.get(state.test_processes, pid) do
      nil -> state
      %{connections: connections} ->
        Enum.each(connections, fn conn ->
          try do
            Sandbox.checkin(conn)
          catch
            _, _ -> :ok
          end
        end)
        %{state |
          test_processes: Map.delete(state.test_processes, pid),
          active_connections: Map.delete(state.active_connections, pid)
        }
    end
  end

  defp cleanup_databases(state) do
    # Terminate all active connections
    terminate_connections(state)

    # Drop and recreate databases
    with :ok <- drop_database(DatabaseConfig.main_test_db(), state),
         :ok <- drop_database(DatabaseConfig.event_test_db(), state),
         :ok <- create_database(DatabaseConfig.main_test_db(), state),
         :ok <- create_database(DatabaseConfig.event_test_db(), state) do
      {:ok, %{state |
        active_connections: %{},
        test_processes: %{}
      }}
    else
      {:error, reason} = error ->
        Logger.error("Database cleanup failed: #{inspect(reason)}")
        error
    end
  end

  defp terminate_connections(%{active_connections: connections} = state) do
    Enum.each(connections, fn {_pid, repo_conns} ->
      Enum.each(repo_conns, fn {repo, _conn} ->
        try do
          Sandbox.checkin(repo)
        catch
          _, _ -> :ok
        end
      end)
    end)
    %{state | active_connections: %{}}
  end

  defp drop_database(db_name, %{admin_conn: conn}) do
    # First terminate all connections to the database
    terminate_query = """
    SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE datname = $1 AND pid <> pg_backend_pid();
    """

    drop_query = "DROP DATABASE IF EXISTS \"#{db_name}\";"

    with {:ok, _} <- Postgrex.query(conn, terminate_query, [db_name], timeout: DatabaseConfig.timeouts()[:operation_timeout]),
         Process.sleep(100), # Give connections time to close
         {:ok, _} <- Postgrex.query(conn, drop_query, [], timeout: DatabaseConfig.timeouts()[:operation_timeout]) do
      :ok
    else
      {:error, reason} = error ->
        Logger.error("Failed to drop database #{db_name}: #{inspect(reason)}")
        error
    end
  end

  defp create_database(db_name, %{admin_conn: conn}) do
    create_query = "CREATE DATABASE \"#{db_name}\" ENCODING 'UTF8';"

    case Postgrex.query(conn, create_query, [], timeout: DatabaseConfig.timeouts()[:operation_timeout]) do
      {:ok, _} -> :ok
      {:error, reason} = error ->
        Logger.error("Failed to create database #{db_name}: #{inspect(reason)}")
        error
    end
  end

  # Actual database setup logic
  defp do_setup_databases(state) do
    with {:ok, main_pid} <- create_main_db(state),
         {:ok, event_pid} <- create_event_db(state) do
      {:ok, %State{state | main_db_pid: main_pid, event_db_pid: event_pid}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_main_db(%{admin_conn: admin_conn}) do
    main_db = DatabaseConfig.main_test_db()
    # Implementation of creating main database
    # This is a placeholder - actual implementation would create the database
    Logger.debug("Creating main database: #{main_db}")
    {:ok, make_ref()}
  end

  defp create_event_db(%{admin_conn: admin_conn}) do
    event_db = DatabaseConfig.event_test_db()
    # Implementation of creating event database
    # This is a placeholder - actual implementation would create the database
    Logger.debug("Creating event database: #{event_db}")
    {:ok, make_ref()}
  end
end
