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
    # First ensure any existing instances are terminated
    if Process.whereis(@name) do
      Logger.info("Stopping existing DatabaseManager instance")
      GenServer.stop(@name, :normal, 10_000) # Longer timeout to ensure proper cleanup
      Process.sleep(500) # Give it time to fully shutdown
    end

    Logger.info("Starting DatabaseManager with synchronized initialization")
    case start_link() do
      {:ok, pid} ->
        # Wait for the GenServer to be fully initialized before proceeding
        # This helps prevent race conditions between GenServer initialization and database setup
        Logger.info("Waiting for DatabaseManager to fully initialize...")
        wait_for_process_initialization(pid)

        # Now explicitly call setup_databases with a timeout
        case GenServer.call(@name, :setup_databases, 60_000) do
          :ok ->
            # Verify databases are properly connected
            verify_database_connections()
          error ->
            Logger.error("Database setup failed: #{inspect(error)}")
            error
        end

      {:error, {:already_started, pid}} ->
        Logger.info("DatabaseManager already running with PID: #{inspect(pid)}")
        # Even if already started, verify it's fully initialized
        wait_for_process_initialization(pid)

        # Check if databases are already set up
        case verify_database_connections() do
          :ok -> :ok
          {:error, _} ->
            # Try to set up databases again if verification fails
            GenServer.call(@name, :setup_databases, 60_000)
        end

      error ->
        Logger.error("Failed to start DatabaseManager: #{inspect(error)}")
        error
    end
  end

  # Private helper to wait for process initialization
  defp wait_for_process_initialization(pid) do
    # Simple ping check to ensure the GenServer is responsive
    ref = Process.monitor(pid)

    # Try to ping the process a few times
    result = Enum.reduce_while(1..5, {:error, :not_ready}, fn attempt, _acc ->
      try do
        # Try to send a synchronous call to the process
        # This will only succeed if the process is fully initialized
        :sys.get_state(pid, 1000)
        {:halt, :ok}
      catch
        :exit, _ ->
          Process.sleep(200 * attempt) # Exponential backoff
          if attempt == 5, do: {:halt, {:error, :process_not_responding}}, else: {:cont, {:error, :retry}}
      end
    end)

    # Clean up the monitor
    Process.demonitor(ref, [:flush])

    result
  end

  # Verify that database connections are working properly
  defp verify_database_connections do
    repos = [
      GameBot.Infrastructure.Persistence.Repo,
      GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
    ]

    # Check each repository with a simple query
    Enum.reduce_while(repos, :ok, fn repo, _acc ->
      if Process.whereis(repo) do
        try do
          # Try a simple query to verify the connection works
          case repo.query("SELECT 1", [], timeout: 5000) do
            {:ok, _} ->
              Logger.info("Successfully verified connection to #{inspect(repo)}")
              {:cont, :ok}
            {:error, reason} ->
              Logger.error("Database connection verification failed for #{inspect(repo)}: #{inspect(reason)}")
              {:halt, {:error, {:connection_verification_failed, repo, reason}}}
          end
        rescue
          e ->
            Logger.error("Error during database verification for #{inspect(repo)}: #{inspect(e)}")
            {:halt, {:error, {:connection_verification_exception, repo, e}}}
        end
      else
        Logger.error("Repository #{inspect(repo)} is not running")
        {:halt, {:error, {:repository_not_running, repo}}}
      end
    end)
  end

  @doc """
  Sets up the sandbox for a test based on the provided tags.
  """
  def setup_sandbox(tags) do
    # Enhanced setup_sandbox function with better error handling and recovery
    max_retries = 3
    base_delay = 500

    Logger.info("Setting up sandbox for test with tags: #{inspect(tags)}")

    # Try to set up sandbox with retries and exponential backoff
    result = Enum.reduce_while(1..max_retries, {:error, :not_attempted}, fn attempt, _acc ->
      # Calculate retry delay with exponential backoff and jitter
      delay = if attempt > 1 do
        (base_delay * :math.pow(2, attempt - 1) |> round()) + :rand.uniform(250)
      else
        0
      end

      if delay > 0 do
        Logger.debug("Retrying sandbox setup in #{delay}ms (attempt #{attempt}/#{max_retries})...")
        Process.sleep(delay)
      end

      # Attempt to set up sandbox
      try do
        # Use a longer timeout for later retry attempts
        timeout = 15_000 * attempt
        case GenServer.call(@name, {:setup_sandbox, tags}, timeout) do
          :ok ->
            Logger.info("Sandbox setup successful")
            {:halt, :ok}

          {:error, reason} = error ->
            cond do
              # If we've hit max retries, give up
              attempt == max_retries ->
                Logger.error("Failed to set up sandbox after #{max_retries} attempts: #{inspect(reason)}")
                {:halt, error}

              # If it's a recoverable error, retry
              recoverable_sandbox_error?(reason) ->
                Logger.warning("Recoverable error during sandbox setup (attempt #{attempt}): #{inspect(reason)}")
                # For specific errors, try recovery actions
                recovery_result = attempt_sandbox_recovery(reason)
                Logger.debug("Recovery attempt result: #{inspect(recovery_result)}")
                {:cont, error}

              # Non-recoverable errors should fail immediately
              true ->
                Logger.error("Non-recoverable error during sandbox setup: #{inspect(reason)}")
                {:halt, error}
            end
        end
      catch
        :exit, {:timeout, _} = reason ->
          Logger.warning("Timeout during sandbox setup (attempt #{attempt})")
          if attempt == max_retries do
            {:halt, {:error, {:setup_timeout, reason}}}
          else
            {:cont, {:error, {:setup_timeout, reason}}}
          end

        :exit, reason ->
          Logger.error("Unexpected exit during sandbox setup: #{inspect(reason)}")
          if attempt == max_retries || !recoverable_exit?(reason) do
            {:halt, {:error, {:setup_exit, reason}}}
          else
            {:cont, {:error, {:setup_exit, reason}}}
          end

        kind, reason ->
          Logger.error("Exception during sandbox setup: #{inspect(kind)}, #{inspect(reason)}")
          if attempt == max_retries do
            {:halt, {:error, {kind, reason}}}
          else
            {:cont, {:error, {kind, reason}}}
          end
      end
    end)

    # Verify setup success with a final health check
    case result do
      :ok ->
        # Perform a final verification that the sandbox is properly set up
        if verify_sandbox_setup() do
          :ok
        else
          Logger.error("Sandbox appears to be set up but failed verification")
          {:error, :sandbox_verification_failed}
        end

      error -> error
    end
  end

  # Determine if a sandbox error is recoverable
  defp recoverable_sandbox_error?({:repository_unavailable, _, _}), do: true
  defp recoverable_sandbox_error?({:sandbox_setup_failed, _, {:checkout_failed, _}}), do: true
  defp recoverable_sandbox_error?({:setup_timeout, _}), do: true
  defp recoverable_sandbox_error?(_), do: false

  # Determine if an exit reason is recoverable
  defp recoverable_exit?({:timeout, _}), do: true
  defp recoverable_exit?({:noproc, _}), do: true
  defp recoverable_exit?({:shutdown, _}), do: false
  defp recoverable_exit?(_), do: false

  # Attempt recovery actions based on specific error types
  defp attempt_sandbox_recovery({:repository_unavailable, repo, _reason}) do
    Logger.debug("Attempting to recover unavailable repository: #{inspect(repo)}")

    # Try to restart the repository
    config = case repo do
      GameBot.Infrastructure.Persistence.Repo -> DatabaseConfig.main_db_config()
      GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres -> DatabaseConfig.event_db_config()
      _ -> nil
    end

    if config do
      try do
        # Stop the repo if it's running
        if Process.whereis(repo) do
          repo.stop()
          Process.sleep(500)  # Give it time to stop
        end

        # Start the repo with the appropriate config
        case repo.start_link(config) do
          {:ok, _} -> {:ok, :restarted}
          error -> {:error, {:restart_failed, error}}
        end
      catch
        kind, reason -> {:error, {kind, reason}}
      end
    else
      {:error, :unknown_repo_type}
    end
  end

  defp attempt_sandbox_recovery({:sandbox_setup_failed, repo, {:checkout_failed, _}}) do
    Logger.debug("Attempting to recover failed checkout for repo: #{inspect(repo)}")

    try do
      # Try to check in any existing connections
      Sandbox.checkin(repo)
      # Reset the repo's sandbox mode
      Sandbox.mode(repo, :manual)
      {:ok, :reset_sandbox}
    catch
      kind, reason -> {:error, {kind, reason}}
    end
  end

  defp attempt_sandbox_recovery(_) do
    {:error, :no_recovery_available}
  end

  # Verify that sandbox setup was successful
  defp verify_sandbox_setup do
    repos = [
      GameBot.Infrastructure.Persistence.Repo,
      GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
    ]

    # Check each repository
    Enum.all?(repos, fn repo ->
      case Process.whereis(repo) do
        nil -> false
        pid ->
          # Check process is alive
          if Process.alive?(pid) do
            # Try a simple query
            try do
              case repo.query("SELECT 1", [], timeout: 5000) do
                {:ok, _} -> true
                _ -> false
              end
            catch
              _, _ -> false
            end
          else
            false
          end
      end
    end)
  end

  @doc """
  Cleans up all database resources.
  """
  def cleanup do
    # Increased timeout for cleanup to ensure it completes
    GenServer.call(@name, :cleanup, 30_000)
  end

  @doc """
  Checks out a connection for an async test.
  """
  def checkout_connection(repo) do
    # Added timeout to prevent indefinite hanging
    GenServer.call(@name, {:checkout, repo, self()}, 15_000)
  end

  @doc """
  Checks in a connection after an async test.
  """
  def checkin_connection(repo) do
    # Added timeout to prevent indefinite hanging
    GenServer.call(@name, {:checkin, repo, self()}, 15_000)
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
  def handle_call(:setup_databases, {_pid, _}, state) do
    case do_setup_databases(state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:checkout, repo, pid}, _from, state) do
    case checkout_connection_for_process(repo, pid, state) do
      {:ok, conn, new_state} -> {:reply, {:ok, conn}, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
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
  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{monitor_ref: ref} = state) do
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

  defp setup_sandbox_mode(tags, test_pid, state) do
    # Extract async flag from tags
    async? = Map.get(tags, :async, false)

    # Get the test process
    test_process = test_pid

    # Set a longer timeout for sandbox operations
    timeout = Map.get(tags, :timeout, 30_000)

    Logger.info("Setting up sandbox mode for test process #{inspect(test_process)} (async: #{async?})")

    # Enhanced repository verification and recovery
    verified_repos = Enum.map(@repos, fn repo ->
      verify_and_recover_repo(repo)
    end)

    # Check if all repos were verified successfully
    if Enum.all?(verified_repos, fn {status, _, _} -> status == :ok end) do
      # All repos are available, proceed with sandbox setup
      setup_results = Enum.map(@repos, fn repo ->
        setup_sandbox_for_repo(repo, async?, test_process, timeout)
      end)

      # Check if all setups were successful
      if Enum.all?(setup_results, fn {status, _, _} -> status == :ok end) do
        Logger.info("Sandbox mode successfully configured for all repositories")
        {:ok, state}
      else
        # Find the first error
        {_, repo, reason} = Enum.find(setup_results, fn
          {:error, _, _} -> true
          _ -> false
        end)

        Logger.error("Failed to set up sandbox for #{inspect(repo)}: #{inspect(reason)}")
        {:error, {:sandbox_setup_failed, repo, reason}}
      end
    else
      # Some repos couldn't be verified/recovered
      {_, repo, reason} = Enum.find(verified_repos, fn
        {:error, _, _} -> true
        _ -> false
      end)

      Logger.error("Repository #{inspect(repo)} could not be verified or recovered: #{inspect(reason)}")
      {:error, {:repository_unavailable, repo, reason}}
    end
  end

  # Helper function to get the configuration for a given repository
  defp get_repo_config(repo) do
    case repo do
      GameBot.Infrastructure.Persistence.Repo ->
        DatabaseConfig.main_db_config()
      GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres ->
        DatabaseConfig.event_db_config()
      _ ->
        Logger.error("Unknown repository type: #{inspect(repo)}")
        nil
    end
  end

  # Verify repo is running and attempt recovery if not
  defp verify_and_recover_repo(repo) do
    case Process.whereis(repo) do
      nil ->
        Logger.warning("Repository #{inspect(repo)} is not running, attempting to restart")
        # Get the appropriate config using our helper function
        config = get_repo_config(repo)

        if config do
          # Attempt to restart the repository
          case start_repo(repo, config) do
            {:ok, pid} ->
              Logger.info("Successfully restarted repository #{inspect(repo)}")
              verify_repo_available(repo, pid)
            error ->
              Logger.error("Failed to restart repository #{inspect(repo)}: #{inspect(error)}")
              {:error, repo, :restart_failed}
          end
        else
          {:error, repo, :unknown_repo_type}
        end

      pid ->
        # Repository process exists, verify it's responsive
        verify_repo_available(repo, pid)
    end
  end

  # Verify the repository is available and responsive - using standardized health check
  defp verify_repo_available(repo, pid) do
    case check_repository_health(repo, pid) do
      {:ok, pid} ->
        # Repository is fully healthy
        {:ok, repo, pid}
      {:error, reason} ->
        # Repository has issues, preserve the triple return format
        {:error, repo, reason}
    end
  end

  # Set up sandbox for a specific repository
  defp setup_sandbox_for_repo(repo, async?, test_process, timeout) do
    try do
      # Check out a connection with a proper timeout
      case Sandbox.checkout(repo, ownership_timeout: timeout) do
        :ok ->
          Logger.debug("Successfully checked out connection for #{inspect(repo)}")

          # For non-async tests, allow the test process to access the repo
          if not async? do
            case Sandbox.allow(repo, test_process, self()) do
              :ok ->
                Logger.debug("Successfully allowed test process to access #{inspect(repo)}")
                {:ok, repo, :allowed}
              other ->
                Logger.warning("Failed to allow test process for #{inspect(repo)}: #{inspect(other)}")
                {:error, repo, {:allow_failed, other}}
            end
          else
            # For async tests, we just need the checkout
            {:ok, repo, :checked_out}
          end

        {:error, reason} ->
          Logger.warning("Failed to checkout connection for #{inspect(repo)}: #{inspect(reason)}")
          {:error, repo, {:checkout_failed, reason}}
      end
    rescue
      e ->
        Logger.error("Exception during sandbox setup for #{inspect(repo)}: #{inspect(e)}")
        {:error, repo, {:exception, e}}
    end
  end

  defp checkout_connection_for_process(repo, pid, state) do
    try do
      # Check out a connection from the pool
      :ok = Sandbox.checkout(repo)

      # Start a transaction - fix the mode parameter
      # The error indicates {:manual, pid} is not a valid parameter
      # It should be just :manual, and we use allow separately
      :ok = Sandbox.mode(repo, :manual)
      :ok = Sandbox.allow(repo, pid, self())

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
      Logger.info("Successfully set up test databases")
      {:ok, %State{
        main_db_pid: state.main_db_pid,
        event_db_pid: state.event_db_pid,
        event_store_pid: state.event_store_pid
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

  defp do_setup_databases(state) do
    Logger.info("Setting up test databases...")

    # First ensure any existing repos are stopped
    stop_existing_repos()

    # Then try to create and start each database with proper error handling
    with :ok <- ensure_no_existing_connections(state),
         {:ok, _} <- create_or_reset_database(DatabaseConfig.main_test_db(), state),
         :ok <- wait_for_database_availability(DatabaseConfig.main_test_db(), state),
         {:ok, _} <- create_or_reset_database(DatabaseConfig.event_test_db(), state),
         :ok <- wait_for_database_availability(DatabaseConfig.event_test_db(), state),
         # Use our new standardized function to start all repositories
         {:ok, repo_pids} <- start_all_repos(),
         # Extract the PIDs for specific repositories
         main_pid = find_repo_pid(repo_pids, GameBot.Infrastructure.Persistence.Repo),
         event_pid = find_repo_pid(repo_pids, GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres),
         # Start the event store
         {:ok, event_store_pid} <- start_event_store()
    do
      Logger.info("Successfully set up test databases")
      # Preserve all existing state fields while updating only the PIDs
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

  # Helper function to find a repository's PID from the list of started repositories
  defp find_repo_pid(repo_pids, target_repo) do
    {^target_repo, pid} = Enum.find(repo_pids, fn {repo, _pid} -> repo == target_repo end)
    pid
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
    max_attempts = 5

    Logger.debug("Waiting for database #{db_name} to become available...")

    result = Enum.reduce_while(1..max_attempts, {:error, :not_ready}, fn attempt, _acc ->
      Logger.debug("Database availability check #{attempt}/#{max_attempts} for #{db_name}")

      case Postgrex.query(conn, "SELECT 1", [], [database: db_name, timeout: 5000]) do
        {:ok, _} ->
          Logger.info("Database #{db_name} is available")
          {:halt, :ok}
        {:error, reason} ->
          Logger.warning("Database #{db_name} not ready (attempt #{attempt}): #{inspect(reason)}")
          # Exponential backoff with jitter
          delay = 200 * attempt + :rand.uniform(100)
          Process.sleep(delay)

          if attempt == max_attempts do
            {:halt, {:error, {:database_not_available, reason}}}
          else
            {:cont, {:error, :retry}}
          end
      end
    end)

    # Ensure we log the final outcome
    case result do
      :ok -> :ok
      {:error, reason} ->
        Logger.error("Database #{db_name} availability check failed after #{max_attempts} attempts: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp create_or_reset_database(db_name, state) do
    Logger.info("Setting up database: #{db_name}")

    # Use retry logic with exponential backoff for database creation
    max_retries = 3

    Enum.reduce_while(1..max_retries, {:error, :not_attempted}, fn attempt, _acc ->
      Logger.debug("Database creation attempt #{attempt}/#{max_retries} for #{db_name}")

      result = case create_database(db_name, state) do
        :ok ->
          Logger.debug("Database #{db_name} created successfully")
          {:ok, db_name}

        {:error, %Postgrex.Error{postgres: %{code: :duplicate_database}}} ->
          Logger.info("Database #{db_name} exists, attempting reset...")
          case reset_existing_database(db_name, state) do
            :ok -> {:ok, db_name}
            error -> error
          end

        {:error, reason} = error ->
          # Log detailed error information
          Logger.error("Database creation failed for #{db_name}: #{inspect(reason)}")

          # If this isn't the last attempt, try to cleanup before retrying
          if attempt < max_retries do
            Logger.debug("Cleaning up after failed creation attempt...")
            # Try to terminate any partial connections or resources
            ensure_no_existing_connections(state)
            # Wait a bit before retry
            Process.sleep(500 * attempt) # Exponential backoff
            {:cont, error}
          else
            # Last attempt failed
            {:halt, error}
          end
      end

      case result do
        {:ok, _} = success -> {:halt, success}
        {:error, _} ->
          if attempt < max_retries do
            delay = 500 * attempt
            Logger.debug("Retrying database creation in #{delay}ms...")
            Process.sleep(delay)
            {:cont, result}
          else
            {:halt, result}
          end
      end
    end)
  end

  defp reset_existing_database(db_name, %{admin_conn: conn}) do
    # More comprehensive reset procedure with better error handling
    Logger.debug("Resetting existing database: #{db_name}")

    # First terminate all connections to the database
    terminate_query = """
    SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE datname = $1 AND pid <> pg_backend_pid();
    """

    # Terminate existing connections with retry
    terminate_result = Enum.reduce_while(1..3, {:error, :not_attempted}, fn attempt, _acc ->
      case Postgrex.query(conn, terminate_query, [db_name], timeout: DatabaseConfig.timeouts()[:operation_timeout]) do
        {:ok, _} ->
          Logger.debug("Successfully terminated connections to #{db_name}")
          {:halt, :ok}
        {:error, reason} ->
          Logger.warning("Failed to terminate connections to #{db_name} (attempt #{attempt}): #{inspect(reason)}")
          if attempt < 3 do
            Process.sleep(200 * attempt)
            {:cont, {:error, reason}}
          else
            # Don't fail if termination fails - this is best effort
            Logger.warning("Max retries reached for connection termination. Continuing anyway.")
            {:halt, :ok}
          end
      end
    end)

    # Only proceed if termination was successful or we decided to continue anyway
    case terminate_result do
      :ok ->
        # Give connections time to close
        Process.sleep(200)

        # Try to verify the database is accessible
        verify_database_access(db_name, conn)

      {:error, reason} ->
        Logger.error("Failed to reset database #{db_name}: #{inspect(reason)}")
        {:error, {:reset_failed, reason}}
    end
  end

  # New helper function to verify database access
  defp verify_database_access(db_name, conn) do
    case Postgrex.query(conn, "SELECT 1", [], [database: db_name, timeout: 5000]) do
      {:ok, _} ->
        Logger.debug("Successfully verified access to database #{db_name}")
        :ok
      {:error, reason} ->
        Logger.warning("Cannot access database #{db_name}: #{inspect(reason)}")
        # Return :ok instead of failing
        :ok
    end
  end

  defp stop_existing_repos do
    # Use the standard repositories list and add any additional repos that might need cleanup
    repos_to_stop = @repos ++ [
      # Additional repos that might exist but aren't in the standard list
      GameBot.Infrastructure.Persistence.Repo.Postgres
    ]

    Enum.each(repos_to_stop, fn repo ->
      case Process.whereis(repo) do
        nil -> :ok
        pid ->
          try do
            Logger.debug("Stopping repository #{inspect(repo)}")
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
    # Maximum number of retry attempts
    max_retries = 5
    # Base delay between retries (ms)
    base_delay = 200

    # Ensure the repo is stopped first with proper error handling
    stop_repo_safely(repo)

    # Use retry logic with exponential backoff
    start_repo_with_retries(repo, config, max_retries, base_delay)
  end

  defp stop_repo_safely(repo) do
    Logger.debug("Safely stopping repository: #{inspect(repo)}")

    case Process.whereis(repo) do
      nil ->
        Logger.debug("Repository #{inspect(repo)} is not running")
        :ok

      pid ->
        # Set up a monitor to detect when the process terminates
        ref = Process.monitor(pid)

        try do
          # Try to stop the repo gracefully
          repo.stop()

          # Wait for the process to terminate with timeout
          receive do
            {:DOWN, ^ref, :process, ^pid, reason} ->
              Logger.debug("Repository #{inspect(repo)} stopped with reason: #{inspect(reason)}")
              :ok
          after
            5000 ->
              # If it doesn't terminate in time, force kill it
              Logger.warning("Repository #{inspect(repo)} did not stop in time, forcing termination")
              Process.demonitor(ref, [:flush])
              Process.exit(pid, :kill)
              Process.sleep(100) # Brief pause to allow kill to propagate
              :ok
          end
        catch
          kind, reason ->
            Logger.warning("Error stopping repository #{inspect(repo)}: #{inspect(kind)}, #{inspect(reason)}")
            Process.demonitor(ref, [:flush])
            # Still try to force kill if necessary
            if Process.alive?(pid) do
              Process.exit(pid, :kill)
              Process.sleep(100)
            end
            :ok
        end
    end
  end

  defp start_repo_with_retries(_repo, _config, 0, _delay) do
    # No more retries left
    {:error, :max_retries_exceeded}
  end

  defp start_repo_with_retries(repo, config, retries, delay) do
    # Log attempt information
    Logger.debug("Starting repository #{inspect(repo)} (attempts remaining: #{retries})")

    # Add operation timeout to config if not present
    config_with_timeout = config
                         |> Keyword.put_new(:timeout, 15_000)
                         |> Keyword.put_new(:pool_timeout, 15_000)

    # Attempt to start the repository
    start_result = try do
      repo.start_link(config_with_timeout)
    catch
      kind, reason ->
        Logger.warning("Exception when starting #{inspect(repo)}: #{inspect(kind)}, #{inspect(reason)}")
        {:error, {kind, reason}}
    end

    # Process the result
    case start_result do
      {:ok, pid} ->
        # Verify the process is alive and responsive
        if verify_repo_health(repo, pid) do
          Logger.info("Repository #{inspect(repo)} started successfully with PID: #{inspect(pid)}")
          {:ok, pid}
        else
          # Process started but is not responding properly
          Logger.warning("Repository #{inspect(repo)} started but failed health check")
          # Try to stop it before retry
          stop_repo_safely(repo)
          # Calculate next retry delay with exponential backoff and jitter
          next_delay = calculate_next_delay(delay, retries)
          Process.sleep(next_delay)
          start_repo_with_retries(repo, config, retries - 1, delay)
        end

      {:error, {:already_started, pid}} ->
        # Verify the process is alive and responsive
        if verify_repo_health(repo, pid) do
          Logger.info("Repository #{inspect(repo)} was already running with PID: #{inspect(pid)}")
          {:ok, pid}
        else
          # Process exists but is not responding properly
          Logger.warning("Repository #{inspect(repo)} exists but failed health check")
          # Try to stop it before retry
          stop_repo_safely(repo)
          # Calculate next retry delay with exponential backoff and jitter
          next_delay = calculate_next_delay(delay, retries)
          Process.sleep(next_delay)
          start_repo_with_retries(repo, config, retries - 1, delay)
        end

      {:error, reason} ->
        # Log detailed error information
        Logger.warning("Failed to start repository #{inspect(repo)}: #{inspect(reason)}")

        # Calculate next retry delay with exponential backoff and jitter
        next_delay = calculate_next_delay(delay, retries)

        # Add additional delay for specific error types
        adjusted_delay = case reason do
          {:shutdown, _} -> next_delay * 2  # Longer delay for shutdown errors
          {:already_started, _} -> next_delay * 2  # Longer delay for already started errors
          _ -> next_delay
        end

        Logger.debug("Retrying in #{adjusted_delay}ms...")
        Process.sleep(adjusted_delay)
        start_repo_with_retries(repo, config, retries - 1, delay)
    end
  end

  # Calculate next delay with exponential backoff and jitter
  defp calculate_next_delay(base_delay, attempt_remaining) do
    # Exponential increase: base_delay * 2^(max_attempts - remaining_attempts)
    max_attempts = 5
    attempt = max_attempts - attempt_remaining + 1
    # Add some randomness to avoid thundering herd problem
    jitter = :rand.uniform(div(base_delay, 2))
    (base_delay * :math.pow(2, attempt) |> round()) + jitter
  end

  # Verify that the repository is responsive
  defp verify_repo_health(repo, pid) do
    case check_repository_health(repo, pid) do
      {:ok, _} ->
        # Repository is healthy
        true
      {:error, _reason} ->
        # Repository has issues
        false
    end
  end

  defp start_event_store do
    # First verify both repositories are healthy before starting event store
    repos_health = Enum.map(@repos, fn repo ->
      case Process.whereis(repo) do
        nil ->
          Logger.warning("Repository #{inspect(repo)} is not running")
          {repo, :not_running}
        pid ->
          case check_repository_health(repo, pid) do
            {:ok, _} -> {repo, :healthy}
            {:error, reason} ->
              Logger.warning("Repository #{inspect(repo)} is not healthy: #{inspect(reason)}")
              {repo, {:unhealthy, reason}}
          end
      end
    end)

    # Only proceed if all repositories are healthy
    if Enum.all?(repos_health, fn {_, status} -> status == :healthy end) do
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
    else
      # Return error with info about unhealthy repositories
      unhealthy_repos = Enum.filter(repos_health, fn {_, status} -> status != :healthy end)
      Logger.error("Cannot start event store: repositories not healthy: #{inspect(unhealthy_repos)}")
      {:error, {:unhealthy_repositories, unhealthy_repos}}
    end
  end

  # Standardized repository health check function
  # This replaces both verify_repo_health and verify_repo_available
  # with a single consistent approach
  defp check_repository_health(repo, pid) do
    # First check if the process exists and is alive
    if is_pid(pid) && Process.alive?(pid) do
      # Step 1: Check if the process responds to system calls
      process_responsive = try do
        case :sys.get_state(pid, 2000) do
          state when is_map(state) or is_tuple(state) -> true
          _ -> false
        end
      catch
        kind, reason ->
          Logger.warning("Repository #{inspect(repo)} process not responsive: #{inspect(kind)}, #{inspect(reason)}")
          false
      end

      # Step 2: If process responds, try a database query
      if process_responsive do
        try do
          case repo.query("SELECT 1", [], timeout: 5000) do
            {:ok, _} ->
              Logger.debug("Repository #{inspect(repo)} is fully healthy")
              {:ok, pid}
            {:error, reason} ->
              Logger.warning("Repository #{inspect(repo)} query failed: #{inspect(reason)}")
              {:error, {:query_failed, reason}}
          end
        rescue
          e ->
            Logger.warning("Exception when querying repository #{inspect(repo)}: #{inspect(e)}")
            {:error, {:query_exception, e}}
        catch
          kind, reason ->
            Logger.warning("Unexpected error during repository query: #{inspect(kind)}, #{inspect(reason)}")
            {:error, {kind, reason}}
        end
      else
        # Process exists but doesn't respond to :sys.get_state
        {:error, :unresponsive_process}
      end
    else
      # Process doesn't exist or isn't alive
      {:error, :process_not_alive}
    end
  end

  # Starts all repositories using their appropriate configurations.
  defp start_all_repos do
    Logger.info("Starting all repositories...")

    # Build repository configurations using our @repos list and helper function
    repo_configs = Enum.map(@repos, fn repo ->
      {repo, get_repo_config(repo)}
    end)

    # Start each repository with its configuration
    results = Enum.map(repo_configs, fn {repo, config} ->
      if config do
        case start_repo(repo, config) do
          {:ok, pid} ->
            Logger.info("Repository #{inspect(repo)} started successfully")
            {:ok, {repo, pid}}
          {:error, reason} = _error ->
            Logger.error("Failed to start repository #{inspect(repo)}: #{inspect(reason)}")
            {:error, {repo, reason}}
        end
      else
        # No valid configuration for this repository
        Logger.error("No valid configuration for repository #{inspect(repo)}")
        {:error, {repo, :no_config}}
      end
    end)

    # Check if all repositories started successfully
    if Enum.all?(results, fn result -> match?({:ok, _}, result) end) do
      # Extract the successful repository/pid pairs
      repo_pids = Enum.map(results, fn {:ok, repo_pid} -> repo_pid end)
      {:ok, repo_pids}
    else
      # Find the first error
      {:error, error} = Enum.find(results, fn result -> match?({:error, _}, result) end)
      {:error, error}
    end
  end
end
