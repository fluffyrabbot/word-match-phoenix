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
      :event_store_pid,
      :monitor_ref,
      active_connections: %{},
      test_processes: %{},
      cleanup_scheduled: false
    ]
  end

  # Server name
  @name __MODULE__

  # Add module attribute for repos
  @repos [
    GameBot.Infrastructure.Persistence.Repo,
    GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
  ]

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
  def handle_info({:EXIT, pid, reason}, state) do
    Logger.debug("Received EXIT message from #{inspect(pid)} with reason: #{inspect(reason)}")
    # If this is a normal exit from one of our managed processes, just remove it from state
    new_state = case reason do
      :normal ->
        %{state |
          main_db_pid: if(state.main_db_pid == pid, do: nil, else: state.main_db_pid),
          event_db_pid: if(state.event_db_pid == pid, do: nil, else: state.event_db_pid),
          event_store_pid: if(state.event_store_pid == pid, do: nil, else: state.event_store_pid)
        }
      _ -> state
    end
    {:noreply, new_state}
  end

  @impl true
  def terminate(_reason, state) do
    # Ensure cleanup on shutdown
    cleanup_databases(state)

    # Stop event store if it's running
    if state.event_store_pid do
      try do
        GameBot.Test.EventStoreCore.reset()
        Process.exit(state.event_store_pid, :normal)
      catch
        _, _ -> :ok
      end
    end

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
        Logger.error("Failed to setup sandbox: #{inspect(reason)}")
        {:error, {kind, reason}}
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
          Sandbox.mode(repo, {:shared, test_pid})
        else
          # For non-async tests, use manual mode
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
      {:ok, _} ->
        Logger.info("Successfully created database #{db_name}")
        :ok
      {:error, %Postgrex.Error{postgres: %{code: :duplicate_database}}} ->
        Logger.info("Database #{db_name} already exists")
        :ok
      {:error, reason} = error ->
        Logger.error("Failed to create database #{db_name}: #{inspect(reason)}")
        error
    end
  end

  # Actual database setup logic
  defp do_setup_databases(state) do
    Logger.info("Setting up test databases...")

    # First ensure any existing repos are stopped
    stop_existing_repos()

    # Then try to create and start each database with proper error handling
    with :ok <- ensure_no_existing_connections(state),
         {:ok, _} <- create_or_reset_database(DatabaseConfig.main_test_db(), state),
         :ok <- wait_for_database_availability(DatabaseConfig.main_test_db(), state),
         {:ok, main_pid} <- start_repo(GameBot.Infrastructure.Persistence.Repo, DatabaseConfig.main_db_config()),
         {:ok, _} <- create_or_reset_database(DatabaseConfig.event_test_db(), state),
         :ok <- wait_for_database_availability(DatabaseConfig.event_test_db(), state),
         {:ok, event_pid} <- start_repo(GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres, DatabaseConfig.event_db_config()),
         {:ok, event_store_pid} <- start_event_store()
    do
      Logger.info("Successfully set up test databases")
      {:ok, %State{state |
        main_db_pid: main_pid,
        event_db_pid: event_pid,
        event_store_pid: event_store_pid
      }}
    else
      {:error, reason} ->
        Logger.error("Failed to set up test databases: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp ensure_no_existing_connections(%{admin_conn: conn}) do
    # Terminate ALL existing connections to our test databases
    terminate_query = """
    SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE datname IN ($1, $2) AND pid <> pg_backend_pid();
    """

    case Postgrex.query(conn, terminate_query, [DatabaseConfig.main_test_db(), DatabaseConfig.event_test_db()],
      timeout: DatabaseConfig.timeouts()[:operation_timeout]) do
      {:ok, _} ->
        Logger.debug("Terminated all existing database connections")
        Process.sleep(200) # Give connections time to fully close
        :ok
      {:error, reason} ->
        Logger.warning("Failed to terminate existing connections: #{inspect(reason)}")
        :ok # Continue anyway as this is best-effort
    end
  end

  defp wait_for_database_availability(db_name, %{admin_conn: conn}) do
    # Try to connect to the database a few times before giving up
    Enum.reduce_while(1..5, {:error, :not_ready}, fn attempt, _acc ->
      case Postgrex.query(conn, "SELECT 1", [], [database: db_name, timeout: 5000]) do
        {:ok, _} ->
          {:halt, :ok}
        {:error, _} ->
          Process.sleep(200 * attempt) # Exponential backoff
          if attempt == 5, do: {:halt, {:error, :database_not_available}}, else: {:cont, {:error, :retry}}
      end
    end)
  end

  defp create_or_reset_database(db_name, state) do
    Logger.info("Setting up database: #{db_name}")
    case create_database(db_name, state) do
      :ok ->
        Logger.debug("Database #{db_name} ready")
        {:ok, db_name}
      {:error, %Postgrex.Error{postgres: %{code: :duplicate_database}}} ->
        Logger.info("Database #{db_name} exists, attempting reset...")
        case reset_existing_database(db_name, state) do
          :ok -> {:ok, db_name}
          error -> error
        end
      error -> error
    end
  end

  defp reset_existing_database(db_name, %{admin_conn: conn}) do
    # First terminate all connections to the database
    terminate_query = """
    SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE datname = $1 AND pid <> pg_backend_pid();
    """

    case Postgrex.query(conn, terminate_query, [db_name], timeout: DatabaseConfig.timeouts()[:operation_timeout]) do
      {:ok, _} ->
        Logger.debug("Terminated existing connections to #{db_name}")
        :ok
      {:error, reason} ->
        Logger.warning("Failed to terminate connections to #{db_name}: #{inspect(reason)}")
        :ok  # Continue anyway, as some connections might not be terminatable
    end

    # Give connections time to close
    Process.sleep(100)

    :ok
  end

  defp stop_existing_repos do
    repos = [
      GameBot.Infrastructure.Persistence.Repo,
      GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres,
      GameBot.Infrastructure.Persistence.Repo.Postgres
    ]

    Enum.each(repos, fn repo ->
      case Process.whereis(repo) do
        nil -> :ok
        pid ->
          try do
            repo.stop()
            # Wait for it to actually stop
            ref = Process.monitor(pid)
            receive do
              {:DOWN, ^ref, :process, ^pid, _} -> :ok
            after
              1000 ->
                Process.exit(pid, :kill)
                :ok
            end
          rescue
            _ -> :ok
          end
      end
    end)

    # Also stop the event store if it's running
    if Process.whereis(GameBot.Test.EventStoreCore) do
      try do
        GameBot.Test.EventStoreCore.reset()
      catch
        _, _ -> :ok
      end
    end
  end

  defp start_repo(repo, config) do
    # Ensure the repo is stopped first
    try do
      repo.stop()
    catch
      _, _ -> :ok
    end

    # Wait a moment for the repo to fully stop
    Process.sleep(100)

    # Now start it with the new config
    case repo.start_link(config) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      error -> error
    end
  end

  defp start_event_store do
    # Configure and start the event store
    Application.put_env(:game_bot, :event_store_adapter, GameBot.Test.EventStoreCore)

    # First try to reset any existing store
    if Process.whereis(GameBot.Test.EventStoreCore) do
      try do
        GameBot.Test.EventStoreCore.reset()
        Process.sleep(100) # Give it time to reset
      catch
        _, _ -> :ok
      end
    end

    # Now start or restart the store
    case GameBot.Test.EventStoreCore.start_link() do
      {:ok, pid} ->
        Process.sleep(100) # Give it time to initialize
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        # Reset the store and continue
        GameBot.Test.EventStoreCore.reset()
        Process.sleep(100)
        {:ok, pid}
      error -> error
    end
  end
end
