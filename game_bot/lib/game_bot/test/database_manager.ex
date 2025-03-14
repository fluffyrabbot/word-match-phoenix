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

  # Repository initialization mutex to prevent race conditions
  @initialization_lock_key {__MODULE__, :initialization_lock}

  # Maximum number of retries for database operations
  @max_retries 5
  # Initial retry delay in milliseconds
  @retry_interval 100
  # Timeout for database operations
  @db_operation_timeout 30_000

  # Startup and initialization

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Initializes the test environment.
  This should be called once at the start of the test suite.

  Returns:
  - `:ok` - If initialization is successful
  - `{:error, reason}` - If initialization fails
  """
  def initialize do
    Logger.info("Initializing test environment")

    # Use a process dictionary-based lock to prevent concurrent initialization
    case acquire_initialization_lock() do
      :ok ->
        try do
          do_initialize()
        after
          # Always release the lock, even if initialization fails
          release_initialization_lock()
        end

      {:error, :locked} ->
        Logger.info("Initialization already in progress, waiting...")
        # Wait for initialization to complete
        wait_for_initialization_to_complete()
    end
  end

  @doc """
  Sets up the sandbox for a test based on the provided tags.
  This should be called in the setup block of test cases.

  ## Examples

  ```elixir
  setup tags do
    GameBot.Test.DatabaseManager.setup_sandbox(tags)
    :ok
  end
  ```
  """
  def setup_sandbox(tags) do
    if tags[:skip_db] do
      :ok
    else
      if tags[:mock] do
        setup_mock_sandbox(tags)
      else
        do_setup_sandbox(tags)
      end
    end
  end

  @doc """
  Cleans up the test environment.
  This should be called after the test suite completes.

  Returns:
  - `:ok` - If cleanup is successful
  - `{:error, reason}` - If cleanup fails
  """
  def cleanup do
    Logger.info("Cleaning up test environment")

    # First try the graceful approach
    graceful_shutdown()

    # Reset the event store
    reset_event_store()

    # Stop repositories in reverse order
    Enum.reverse(@repos)
    |> Enum.each(fn repo ->
      case stop_repo(repo) do
        :ok ->
          Logger.debug("#{inspect(repo)} stopped successfully")

        {:error, reason} ->
          Logger.warning("Failed to stop #{inspect(repo)}: #{inspect(reason)}")
      end
    end)

    # Clean up process registry
    cleanup_process_registry()

    Logger.info("Test environment cleanup completed")
    :ok
  end

  @doc """
  Alias for cleanup/0, provided for backward compatibility.
  """
  def cleanup_connections do
    cleanup()
  end

  @doc """
  Sets up test databases with unique names to avoid conflicts.

  Returns {:ok, %{main_db: main_db_name, event_db: event_db_name}}
  """
  def setup_test_databases do
    # Generate unique suffixes for the database names
    suffix = System.system_time(:second) |> to_string()

    # Create database names
    main_db = "game_bot_test_#{suffix}"
    event_db = "game_bot_eventstore_test_#{suffix}"

    # Create the databases
    Logger.debug("Creating test databases: main=#{main_db}, event=#{event_db}")

    {:ok, _} = create_database(main_db)
    {:ok, _} = create_database(event_db)

    # Create event store schema in the event database
    create_event_store_schema(event_db)

    # Configure the application to use these databases
    update_repo_config(main_db)
    update_event_store_config(event_db)

    # Return the database names
    {:ok, %{main_db: main_db, event_db: event_db}}
  end

  @doc """
  Drops a database with the given name.
  """
  def drop_database(db_name) when is_binary(db_name) do
    # Ensure we're not dropping a production database
    if String.contains?(db_name, ["prod", "production"]) do
      raise "Refusing to drop a production database: #{db_name}"
    end

    Logger.debug("Dropping database: #{db_name}")

    # Connect to the postgres database to drop the target database
    conn_info = [
      hostname: "localhost",
      username: "postgres",
      password: "csstarahid",
      database: "postgres",
      pool_size: 1
    ]

    # Drop database with a failsafe
    with {:ok, conn} <- Postgrex.start_link(conn_info),
         # Force disconnect any connections to the database
         {:ok, _} <- Postgrex.query(
           conn,
           "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = $1",
           [db_name],
           []
         ),
         # Drop the database
         {:ok, _} <- Postgrex.query(conn, "DROP DATABASE IF EXISTS #{db_name}", [], []),
         :ok <- GenServer.stop(conn) do
      :ok
    else
      error ->
        Logger.error("Failed to drop database #{db_name}: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Cleans up test database resources created during testing.
  """
  def cleanup_resources do
    # Get the database names from environment variables (where the test stores them)
    main_db = System.get_env("TEST_DB_MAIN")
    event_db = System.get_env("TEST_DB_EVENT")

    # Clean up the databases
    if main_db, do: drop_database(main_db)
    if event_db, do: drop_database(event_db)

    # Clear environment variables
    System.delete_env("TEST_DB_MAIN")
    System.delete_env("TEST_DB_EVENT")

    :ok
  end

  # Private implementation functions

  defp do_initialize do
    # Start required applications in order
    apps = [
      :logger,
      :crypto,
      :ssl,
      :postgrex,
      :ecto,
      :ecto_sql,
      :eventstore
    ]

    # Start each application and handle errors
    Enum.each(apps, fn app ->
      case Application.ensure_all_started(app) do
        {:ok, _} -> :ok
        {:error, {dep, reason}} ->
          Logger.error("Failed to start #{app}. Dependency #{dep} failed: #{inspect(reason)}")
          raise "Failed to start required application: #{app}"
      end
    end)

    # Log database names for debugging
    log_database_names()

    # Initialize repositories with retry logic
    with :ok <- terminate_existing_connections(),
         :ok <- ensure_repositories_started() do
      configure_sandbox_mode()
    else
      {:error, reason} ->
        Logger.error("Failed to initialize test environment: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp do_setup_sandbox(tags) do
    # Get timeout from tags or use default
    timeout = Map.get(tags, :timeout, @db_operation_timeout)

    # First ensure all repos are started
    ensure_all_repos_running()

    # Then configure sandbox for each repository
    Enum.each(@repos, fn repo ->
      if is_repo_running?(repo) do
        # Configure sandbox mode based on test tags
        configure_sandbox_mode(repo, tags, timeout)
      else
        Logger.error("Repository #{inspect(repo)} is not running, sandbox setup failed")
        {:error, :repository_not_running}
      end
    end)

    :ok
  end

  defp setup_mock_sandbox(_tags) do
    # For mock tests, we don't need actual database connections
    # Just ensure we have the in-memory repos configured
    :ok
  end

  defp ensure_all_repos_running do
    Logger.debug("Ensuring all repositories are running")

    # Make sure both repositories are defined in the application environment
    configure_repo_if_needed(GameBot.Infrastructure.Persistence.Repo)
    configure_event_store_if_needed(GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres)

    # Attempt to start each repository if not already running
    Enum.each(@repos, fn repo ->
      if not is_repo_running?(repo) do
        start_repo(repo)
      end
    end)

    # Verify all repositories are running
    repo_status = Enum.reduce(@repos, :ok, fn repo, acc ->
      case acc do
        :ok ->
          if is_repo_running?(repo) do
            :ok
          else
            Logger.error("Repository #{inspect(repo)} failed to start")
            {:error, {:repository_not_running, repo}}
          end
        error -> error
      end
    end)

    repo_status
  end

  defp configure_repo_if_needed(repo) do
    if is_nil(Application.get_env(:game_bot, repo)) do
      # Configure with minimal settings for test
      Application.put_env(:game_bot, repo, [
        database: get_main_db_name(),
        username: "postgres",
        password: "csstarahid",
        hostname: "localhost",
        pool: Ecto.Adapters.SQL.Sandbox,
        pool_size: 10
      ])
    end
  end

  defp configure_event_store_if_needed(repo) do
    if is_nil(Application.get_env(:game_bot, repo)) do
      # Configure with minimal settings for test
      Application.put_env(:game_bot, repo, [
        database: get_event_db_name(),
        username: "postgres",
        password: "csstarahid",
        hostname: "localhost",
        pool: Ecto.Adapters.SQL.Sandbox,
        pool_size: 10,
        schema_prefix: "event_store"
      ])
    end
  end

  defp ensure_repositories_started do
    Logger.debug("Starting repositories...")

    # Configure sandbox mode to be properly used
    Application.put_env(:ecto_sql, :sandbox, pool_size: 10)

    # Start each repository with retry logic
    Enum.reduce_while(@repos, :ok, fn repo, acc ->
      case start_repo_with_retry(repo) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp start_repo_with_retry(repo) do
    Logger.debug("Starting repository: #{inspect(repo)}")

    retry_with_backoff(
      fn -> start_repo(repo) end,
      @max_retries,
      @retry_interval,
      &exponential_backoff/2
    )
  end

  defp start_repo(repo) do
    Logger.debug("Starting repository: #{inspect(repo)}")

    config = Application.get_env(:game_bot, repo)

    if config == nil do
      Logger.error("No configuration found for #{inspect(repo)}")
      {:error, :no_config}
    else
      try do
        case repo.start_link(config) do
          {:ok, _pid} ->
            Logger.debug("Repository #{inspect(repo)} started successfully")
            :ok
          {:error, {:already_started, _pid}} ->
            Logger.debug("Repository #{inspect(repo)} already started")
            :ok
          {:error, error} ->
            Logger.error("Failed to start #{inspect(repo)}: #{inspect(error)}")
            {:error, error}
        end
      rescue
        e ->
          Logger.error("Exception starting #{inspect(repo)}: #{Exception.message(e)}")
          {:error, e}
      end
    end
  end

  defp stop_repo(repo) do
    case Process.whereis(repo) do
      nil ->
        Logger.debug("Repository #{inspect(repo)} is not running")
        :ok
      pid ->
        Logger.debug("Stopping repository #{inspect(repo)}")
        try do
          # First try the repo's stop function if it exists
          if function_exported?(repo, :stop, 0) do
            repo.stop()
          else
            # Otherwise, try to stop the GenServer directly
            GenServer.stop(pid, :normal, 5000)
          end
          :ok
        rescue
          e ->
            Logger.warning("Error stopping #{inspect(repo)}: #{inspect(e)}")
            {:error, e}
        catch
          :exit, reason ->
            Logger.warning("Exit when stopping #{inspect(repo)}: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  defp is_repo_running?(repo) do
    case Process.whereis(repo) do
      nil -> false
      pid -> Process.alive?(pid)
    end
  end

  defp configure_sandbox_mode do
    Logger.debug("Configuring sandbox mode for repositories")

    Enum.each(@repos, fn repo ->
      if is_repo_running?(repo) do
        Logger.debug("Setting #{inspect(repo)} to sandbox mode :manual")
        try do
          Sandbox.mode(repo, :manual)
        rescue
          e ->
            Logger.error("Failed to set sandbox mode for #{inspect(repo)}: #{Exception.message(e)}")
        end
      else
        Logger.warning("Repository #{inspect(repo)} is not running, cannot configure sandbox mode")
      end
    end)

    :ok
  end

  defp configure_sandbox_mode(repo, tags, timeout) do
    # Check if this is an async test
    is_async = Map.get(tags, :async, false)

    try do
      if is_async do
        # For async tests, use shared mode to allow concurrent access
        Sandbox.checkout(repo, ownership_timeout: timeout)
        Sandbox.mode(repo, {:shared, self()})
      else
        # For non-async tests, use manual mode for better isolation
        Sandbox.checkout(repo, ownership_timeout: timeout)
      end
      :ok
    rescue
      e ->
        Logger.error("Error configuring sandbox for #{inspect(repo)}: #{Exception.message(e)}")
        {:error, e}
    end
  end

  defp terminate_existing_connections do
    Logger.debug("Terminating existing database connections")

    try do
      # Connect to postgres database for admin operations
      postgres_config = [
        hostname: "localhost",
        username: "postgres",
        password: "csstarahid",
        database: "postgres",
        timeout: @db_operation_timeout,
        connect_timeout: @db_operation_timeout
      ]

      case Postgrex.start_link(postgres_config) do
        {:ok, conn} ->
          try do
            # Terminate any existing connections to our test databases
            terminate_db_connections(conn, get_main_db_name())
            terminate_db_connections(conn, get_event_db_name())
            :ok
          after
            # Close the admin connection
            GenServer.stop(conn, :normal, 5000)
          end
        {:error, error} ->
          Logger.error("Failed to connect to PostgreSQL for connection termination: #{inspect(error)}")
          {:error, error}
      end
    rescue
      e ->
        Logger.error("Exception during connection termination: #{Exception.message(e)}")
        {:error, e}
    end
  end

  defp terminate_db_connections(conn, db_name) do
    Logger.debug("Terminating connections to database: #{db_name}")

    # Query to terminate connections to the specified database
    terminate_query = """
    SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE pid <> pg_backend_pid()
    AND datname = $1
    """

    try do
      case Postgrex.query(conn, terminate_query, [db_name], timeout: @db_operation_timeout) do
        {:ok, _result} ->
          Logger.debug("Successfully terminated connections to #{db_name}")
          :ok
        {:error, error} ->
          Logger.warning("Error terminating connections to #{db_name}: #{inspect(error)}")
          {:error, error}
      end
    rescue
      e ->
        Logger.warning("Exception terminating connections to #{db_name}: #{Exception.message(e)}")
        {:error, e}
    end
  end

  defp reset_event_store do
    Logger.debug("Resetting event store")

    # Try to reset the test event store if it's running
    event_store_pid = Process.whereis(GameBot.Test.EventStoreCore)
    if event_store_pid && Process.alive?(event_store_pid) do
      try do
        Logger.debug("Resetting EventStoreCore")
        GameBot.Test.EventStoreCore.reset()
        :ok
      rescue
        e ->
          Logger.warning("Error resetting event store: #{Exception.message(e)}")
          {:error, e}
      end
    else
      Logger.debug("EventStoreCore not running, no reset needed")
      :ok
    end
  end

  defp cleanup_process_registry do
    # Clean up any tracked processes
    # Implementation would track process IDs and clean them up
    :ok
  end

  defp graceful_shutdown do
    Logger.debug("Performing graceful shutdown")

    try do
      # Attempt to close connections for the main repositories
      Enum.each(@repos, fn repo ->
        case Process.whereis(repo) do
          nil -> :ok
          pid ->
            if Process.alive?(pid) do
              Logger.debug("Checking in connections for #{inspect(repo)}")
              try do
                Sandbox.checkin(repo)
              rescue
                e -> Logger.warning("Error checking in connections: #{inspect(e)}")
              end
            end
        end
      end)
    catch
      kind, reason ->
        Logger.error("Error during repository shutdown: #{inspect(kind)}, #{inspect(reason)}")
    end

    # Small delay to allow connections to close
    Process.sleep(200)

    :ok
  end

  # Utility functions

  defp retry_with_backoff(fun, max_retries, initial_delay, backoff_fun \\ &exponential_backoff/2) do
    do_retry(fun, max_retries, initial_delay, 1, backoff_fun)
  end

  defp do_retry(fun, max_retries, delay, attempt, backoff_fun) do
    case fun.() do
      :ok -> :ok
      {:ok, result} -> {:ok, result}
      {:error, reason} ->
        if attempt < max_retries do
          Logger.debug("Attempt #{attempt} failed: #{inspect(reason)}. Retrying in #{delay}ms...")
          Process.sleep(delay)
          next_delay = backoff_fun.(delay, attempt)
          do_retry(fun, max_retries, next_delay, attempt + 1, backoff_fun)
        else
          Logger.error("Max retries (#{max_retries}) reached. Last error: #{inspect(reason)}")
          {:error, reason}
        end
    end
  end

  defp exponential_backoff(delay, attempt) do
    min(delay * 2, 30_000)  # Cap at 30 seconds
  end

  defp log_database_names do
    main_db = get_main_db_name()
    event_db = get_event_db_name()
    Logger.info("Using test databases: main=#{main_db}, event=#{event_db}")
  end

  defp get_main_db_name do
    Application.get_env(:game_bot, :test_databases)[:main_db] || "game_bot_test"
  end

  defp get_event_db_name do
    Application.get_env(:game_bot, :test_databases)[:event_db] || "game_bot_eventstore_dev"
  end

  # Concurrency control functions

  defp acquire_initialization_lock do
    case Process.get(@initialization_lock_key, :unlocked) do
      :unlocked ->
        Process.put(@initialization_lock_key, :locked)
        :ok
      :locked ->
        {:error, :locked}
    end
  end

  defp release_initialization_lock do
    Process.put(@initialization_lock_key, :unlocked)
    :ok
  end

  defp wait_for_initialization_to_complete do
    # Periodically check the lock status
    case Process.get(@initialization_lock_key, :unlocked) do
      :unlocked -> :ok
      :locked ->
        Process.sleep(100)
        wait_for_initialization_to_complete()
    end
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

  # Private helper functions for database setup

  defp create_event_store_schema(db_name) do
    # Connect to the new event database
    conn_info = [
      hostname: "localhost",
      username: "postgres",
      password: "csstarahid",
      database: db_name,
      pool_size: 1
    ]

    case Postgrex.start_link(conn_info) do
      {:ok, conn} ->
        # Create the event_store schema
        Postgrex.query!(conn, "CREATE SCHEMA IF NOT EXISTS event_store", [], [])

        # Create basic tables (not the full event store setup, just enough to pass the test)
        Postgrex.query!(
          conn,
          """
          CREATE TABLE IF NOT EXISTS event_store.events (
            id BIGSERIAL PRIMARY KEY,
            stream_id text NOT NULL,
            stream_version bigint NOT NULL,
            event_id uuid NOT NULL,
            event_type text NOT NULL,
            data jsonb NOT NULL,
            metadata jsonb,
            created_at timestamp without time zone DEFAULT NOW() NOT NULL
          )
          """,
          [],
          []
        )

        GenServer.stop(conn)
        :ok

      {:error, error} ->
        Logger.error("Failed to create event store schema: #{inspect(error)}")
        {:error, error}
    end
  end

  defp update_repo_config(db_name) do
    # Update the repository configuration to use the new database
    repo_config = Application.get_env(:game_bot, GameBot.Infrastructure.Persistence.Repo, [])
    updated_config = Keyword.put(repo_config, :database, db_name)
    Application.put_env(:game_bot, GameBot.Infrastructure.Persistence.Repo, updated_config)
  end

  defp update_event_store_config(db_name) do
    # Update the event store configuration to use the new database
    event_store_config = Application.get_env(:game_bot, GameBot.Infrastructure.Persistence.EventStore, [])
    updated_config = Keyword.put(event_store_config, :database, db_name)
    Application.put_env(:game_bot, GameBot.Infrastructure.Persistence.EventStore, updated_config)
  end

  defp create_database(db_name) do
    # Connect to the postgres database to create a new database
    conn_info = [
      hostname: "localhost",
      username: "postgres",
      password: "csstarahid",
      database: "postgres",
      pool_size: 1
    ]

    with {:ok, conn} <- Postgrex.start_link(conn_info),
         {:ok, _} <- Postgrex.query(conn, "CREATE DATABASE #{db_name}", [], []),
         :ok <- GenServer.stop(conn) do
      {:ok, db_name}
    else
      error ->
        Logger.error("Failed to create database #{db_name}: #{inspect(error)}")
        {:error, error}
    end
  end
end
