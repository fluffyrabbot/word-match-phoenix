# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.

# Configure ExUnit for our test environment with sensible defaults
ExUnit.configure(
  exclude: [:skip_checkout],
  timeout: 120_000,  # Longer timeout since we may have db operations
  trace: false,      # Set to true for detailed test execution tracing if needed
  seed: 0            # Ensure deterministic test order
)

# Start ExUnit
ExUnit.start()

# Configure the application for testing
Application.put_env(:game_bot, :start_word_service, false)
Application.put_env(:game_bot, :start_nostrum, false)
Application.put_env(:nostrum, :token, "fake_token_for_testing")
Application.put_env(:nostrum, :api_module, GameBot.Test.Mocks.NostrumApiMock)

# Configure event stores to avoid warnings
Application.put_env(:game_bot, :event_stores, [
  GameBot.Infrastructure.Persistence.EventStore
])

defmodule GameBot.Test.Setup do
  @moduledoc """
  Setup module for the test environment.

  This module is responsible for initializing all necessary components
  for the test environment, including:
  - Database connections
  - Repository startup and configuration
  - Phoenix endpoint initialization
  - Event store setup
  """

  import ExUnit.Callbacks, only: [on_exit: 1]
  alias GameBot.Infrastructure.Persistence.Repo
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres, as: EventStoreRepo

  # Longer timeout for database operations (in milliseconds)
  @db_operation_timeout 30_000

  @doc """
  Initializes the entire test environment.

  This function should be called once at the beginning of the test run
  to ensure all services are properly configured and started.
  """
  def initialize do
    IO.puts("\n=== INITIALIZING TEST ENVIRONMENT ===")

    # Step 1: Start required applications
    start_required_applications()

    # Step 2: Register cleanup hooks to ensure proper teardown
    register_cleanup_hooks()

    # Step 3: Initialize repositories
    initialize_repositories()

    # Step 4: Initialize Phoenix endpoint
    initialize_phoenix_endpoint()

    # Step 5: Initialize test event store
    initialize_test_event_store()

    # Step 6: Verify database connections
    verify_database_connections()

    IO.puts("=== TEST ENVIRONMENT INITIALIZATION COMPLETE ===\n")
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    # Start owner with better error handling
    try do
      pid = Ecto.Adapters.SQL.Sandbox.start_owner!(GameBot.Infrastructure.Persistence.Repo, shared: not tags[:async])
      on_exit(fn ->
        try do
          Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
        rescue
          e -> IO.puts("Warning: Failed to stop owner: #{inspect(e)}")
        end
      end)
    rescue
      e ->
        IO.puts("Error setting up sandbox: #{inspect(e)}")
        # Try to ensure repo is started and retry once
        RepositoryManager.ensure_started(GameBot.Infrastructure.Persistence.Repo)
        pid = Ecto.Adapters.SQL.Sandbox.start_owner!(GameBot.Infrastructure.Persistence.Repo, shared: not tags[:async])
        on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    end
  end

  @doc """
  Starts all required applications in dependency order.
  """
  def start_required_applications do
    IO.puts("Starting required applications...")

    required_apps = [
      :logger,            # Basic logging
      :crypto,            # Cryptographic functions
      :ssl,               # SSL support
      :postgrex,          # PostgreSQL driver
      :ecto,              # Database wrapper
      :ecto_sql,          # SQL adapters for Ecto
      :telemetry,         # Metrics and instrumentation
      :jason,             # JSON encoding/decoding
      :phoenix,           # Web framework
      :phoenix_html,      # HTML templates
      :eventstore         # Event storage
    ]

    Enum.each(required_apps, fn app ->
      case Application.ensure_all_started(app) do
        {:ok, started} ->
          IO.puts("Started #{app} and dependencies: #{inspect(started)}")
        {:error, {dep, reason}} ->
          IO.puts("Failed to start #{app}. Dependency #{dep} failed with: #{inspect(reason)}")
          raise "Application startup failure"
      end
    end)

    IO.puts("All required applications started successfully")
  end

  @doc """
  Initializes and configures repository connections.
  """
  def initialize_repositories do
    IO.puts("Initializing repositories...")

    # Define the repositories we need to start
    repos = [Repo, EventStoreRepo]

    # Define common configuration for all repositories
    repo_config = [
      pool: Ecto.Adapters.SQL.Sandbox,  # Use sandbox pool for tests
      pool_size: 5,                     # Reduced pool size for fewer connections
      ownership_timeout: 60_000,        # 1 minute timeout for ownership
      queue_target: 200,                # Target queue time in ms
      queue_interval: 1000,             # Queue interval in ms
      timeout: @db_operation_timeout,   # Increased query timeout
      connect_timeout: @db_operation_timeout # Increased connection timeout
    ]

    # Start each repository
    results = Enum.map(repos, fn repo ->
      start_repository(repo, repo_config)
    end)

    # Check if any failed to start
    failures = Enum.filter(results, fn {status, _} -> status == :error end)
    if length(failures) > 0 do
      failure_details = Enum.map_join(failures, "\n", fn {_, {repo, error}} ->
        "  - #{inspect(repo)}: #{inspect(error)}"
      end)
      raise "Failed to start repositories:\n#{failure_details}"
    end

    # Configure sandbox mode for each repo
    Enum.each(repos, fn repo ->
      IO.puts("Setting sandbox mode for #{inspect(repo)}")
      Ecto.Adapters.SQL.Sandbox.mode(repo, :manual)
    end)

    IO.puts("All repositories initialized successfully")
  end

  @doc """
  Starts a single repository with given configuration.
  """
  def start_repository(repo, config) do
    IO.puts("Starting #{inspect(repo)}...")

    try do
      # Get the repository's configuration from the application environment
      app_config = Application.get_env(:game_bot, repo, [])

      # Merge with our test configuration, with our settings taking precedence
      merged_config = Keyword.merge(app_config, config)

      # Stop the repository if it's already running
      try_stop_repository(repo)

      # Start the repository with a specific timeout
      case repo.start_link(merged_config) do
        {:ok, pid} ->
          IO.puts("#{inspect(repo)} started with pid #{inspect(pid)}")
          {:ok, repo}
        {:error, {:already_started, pid}} ->
          IO.puts("#{inspect(repo)} was already started with pid #{inspect(pid)}")
          {:ok, repo}
        {:error, error} ->
          IO.puts("Failed to start #{inspect(repo)}: #{inspect(error)}")
          {:error, {repo, error}}
      end
    rescue
      e ->
        IO.puts("Exception when starting #{inspect(repo)}: #{inspect(e)}")
        {:error, {repo, e}}
    end
  end

  @doc """
  Tries to stop a repository if it's running.
  """
  def try_stop_repository(repo) do
    case Process.whereis(repo) do
      nil ->
        :ok
      pid ->
        IO.puts("Stopping existing #{inspect(repo)} with pid #{inspect(pid)}")
        try do
          repo.stop(pid)
          # Wait a bit to ensure it's stopped
          :timer.sleep(100)
          :ok
        rescue
          e ->
            IO.puts("Error stopping #{inspect(repo)}: #{inspect(e)}")
            :error
        end
    end
  end

  @doc """
  Initializes the Phoenix endpoint for testing.
  """
  def initialize_phoenix_endpoint do
    IO.puts("Initializing Phoenix endpoint...")

    # Get endpoint configuration
    endpoint_module = GameBotWeb.Endpoint
    endpoint_config = Application.get_env(:game_bot, endpoint_module, [])
    secret_key_base = Keyword.get(endpoint_config, :secret_key_base, "test_secret_key_base")

    # Initialize ETS table for the endpoint if it doesn't exist
    try do
      if :ets.info(endpoint_module) == :undefined do
        :ets.new(endpoint_module, [:set, :public, :named_table])
        IO.puts("Created ETS table for #{inspect(endpoint_module)}")
      else
        IO.puts("ETS table for #{inspect(endpoint_module)} already exists")
      end

      # Ensure the secret key base is set
      :ets.insert(endpoint_module, {:secret_key_base, secret_key_base})
      IO.puts("Set secret_key_base in ETS table")

      IO.puts("Phoenix endpoint initialized successfully")
    rescue
      e ->
        IO.puts("Error initializing Phoenix endpoint: #{inspect(e)}")
        reraise e, __STACKTRACE__
    end
  end

  @doc """
  Initializes the test event store.
  """
  def initialize_test_event_store do
    IO.puts("Initializing test event store...")

    # Get the configured test event store module
    test_store = Application.get_env(:game_bot, :event_store_adapter, GameBot.TestEventStore)

    # Stop the test store if it's already running
    case Process.whereis(test_store) do
      nil -> :ok
      pid ->
        IO.puts("Stopping existing test event store with pid #{inspect(pid)}")
        try do
          test_store.stop()
        rescue
          _ -> :ok
        end
    end

    # Start the test store
    IO.puts("Starting test event store: #{inspect(test_store)}")
    case test_store.start_link() do
      {:ok, pid} ->
        IO.puts("Test event store started with pid: #{inspect(pid)}")
      {:error, {:already_started, pid}} ->
        IO.puts("Test event store was already started with pid: #{inspect(pid)}")
        # Reset the event store state
        test_store.reset_state()
      error ->
        IO.puts("Failed to start test event store: #{inspect(error)}")
        raise "Event store initialization failure: #{inspect(error)}"
    end

    IO.puts("Test event store initialized successfully")
  end

  @doc """
  Verifies that database connections are working properly.
  """
  def verify_database_connections do
    IO.puts("Verifying database connections...")

    # First explicitly check out connections to verify
    IO.puts("Explicitly checking out connections for verification...")

    # Helper function to safely verify a repo connection
    verify_repo = fn repo, name ->
      try do
        # First try with explicit checkout
        Ecto.Adapters.SQL.Sandbox.checkout(repo)

        # Then verify with a query
        repo.query!("SELECT 1", [])
        IO.puts("#{name} connection verified (with checkout)")

        # Check the connection back in
        Ecto.Adapters.SQL.Sandbox.checkin(repo)
        :ok
      rescue
        e in DBConnection.OwnershipError ->
          IO.puts("Ownership error for #{name}, trying with shared mode: #{inspect(e)}")

          # Try with shared mode if checkout fails
          test_pid = self()
          Ecto.Adapters.SQL.Sandbox.mode(repo, {:shared, test_pid})

          try do
            repo.query!("SELECT 1", [])
            IO.puts("#{name} connection verified (with shared mode)")
            :ok
          rescue
            e ->
              IO.puts("Error connecting to #{name} with shared mode: #{inspect(e)}")
              {:error, e}
          end

        e ->
          IO.puts("Error connecting to #{name}: #{inspect(e)}")
          {:error, e}
      end
    end

    # Verify both repositories
    main_result = verify_repo.(Repo, "main repository")
    event_result = verify_repo.(EventStoreRepo, "event store repository")

    # Reset to manual mode
    Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)
    Ecto.Adapters.SQL.Sandbox.mode(EventStoreRepo, :manual)

    # Check results and fail if needed
    case {main_result, event_result} do
      {:ok, :ok} ->
        IO.puts("All database connections verified")
        :ok
      _ ->
        IO.puts("WARNING: Database connection verification issues detected")
        IO.puts("Continuing anyway to allow tests to run")
    end
  end

  @doc """
  Registers cleanup hooks to be executed when the test process exits.
  """
  def register_cleanup_hooks do
    IO.puts("Registering test environment cleanup hooks...")

    # Register cleanup function to be called when the test process exits
    ExUnit.after_suite(fn _ ->
      IO.puts("\n=== CLEANING UP TEST ENVIRONMENT ===")

      # Clean up any lingering repository connections
      cleanup_repository_connections()

      # Force terminate event store
      cleanup_event_store()

      # Shutdown repositories
      shutdown_repositories()

      # Force terminate all connections in PostgreSQL
      terminate_all_postgres_connections()

      # Trigger garbage collection
      :erlang.garbage_collect()

      IO.puts("=== TEST ENVIRONMENT CLEANUP COMPLETE ===\n")
    end)
  end

  @doc """
  Terminates all PostgreSQL connections except to the postgres database.
  """
  def terminate_all_postgres_connections do
    IO.puts("Terminating all PostgreSQL connections...")

    # Get database names for logging
    main_db = Application.get_env(:game_bot, :test_databases)[:main_db] ||
              "game_bot_test#{System.get_env("MIX_TEST_PARTITION")}"
    event_db = Application.get_env(:game_bot, :test_databases)[:event_db] ||
               "game_bot_eventstore_test#{System.get_env("MIX_TEST_PARTITION")}"

    # Create a connection to the postgres database
    postgres_config = [
      hostname: "localhost",
      username: "postgres",
      password: "csstarahid",
      database: "postgres",
      timeout: @db_operation_timeout,
      connect_timeout: @db_operation_timeout
    ]

    # Connect to postgres database to execute termination commands
    with {:ok, conn} <- Postgrex.start_link(postgres_config) do
      # First terminate connections to specific test databases
      terminate_query = """
      SELECT pg_terminate_backend(pid)
      FROM pg_stat_activity
      WHERE datname IN ('#{main_db}', '#{event_db}')
      AND pid <> pg_backend_pid();
      """

      case Postgrex.query(conn, terminate_query, [], timeout: @db_operation_timeout) do
        {:ok, result} ->
          IO.puts("Terminated #{result.num_rows} connections to test databases")
        {:error, error} ->
          IO.puts("Error terminating connections: #{inspect(error)}")
      end

      # Then terminate all non-postgres connections as a fallback
      terminate_all_query = """
      SELECT pg_terminate_backend(pid)
      FROM pg_stat_activity
      WHERE datname != 'postgres'
      AND pid <> pg_backend_pid();
      """

      case Postgrex.query(conn, terminate_all_query, [], timeout: @db_operation_timeout) do
        {:ok, result} ->
          IO.puts("Terminated #{result.num_rows} connections to all non-postgres databases")
        {:error, error} ->
          IO.puts("Error terminating connections: #{inspect(error)}")
      end

      # Close the connection
      try do
        Postgrex.disconnect(conn)
      rescue
        _ -> :ok
      end
    else
      {:error, error} ->
        IO.puts("Error connecting to postgres database: #{inspect(error)}")
    end
  end

  @doc """
  Cleans up any lingering repository connections.
  """
  def cleanup_repository_connections do
    IO.puts("Cleaning up repository connections...")

    # Define the repositories we need to clean up
    repos = [Repo, EventStoreRepo]

    # For each repository, close all connections in the pool
    Enum.each(repos, fn repo ->
      IO.puts("Closing connections for #{inspect(repo)}")

      # Try to close all connections gracefully
      try do
        # Force a checkout to make sure all connections are properly owned
        Ecto.Adapters.SQL.Sandbox.checkout(repo)

        # Then release all connections
        Ecto.Adapters.SQL.Sandbox.checkin(repo)

        # Reset sandbox mode to manual
        Ecto.Adapters.SQL.Sandbox.mode(repo, :manual)
      rescue
        e -> IO.puts("Error while cleaning up #{inspect(repo)}: #{inspect(e)}")
      end
    end)
  end

  @doc """
  Shuts down the repositories
  """
  def shutdown_repositories do
    IO.puts("Shutting down repositories...")

    # Define the repositories we need to shut down
    repos = [Repo, EventStoreRepo]

    # Attempt to stop each repository
    Enum.each(repos, fn repo ->
      IO.puts("Stopping #{inspect(repo)}")

      # Try to stop the repository gracefully
      try do
        if pid = Process.whereis(repo) do
          repo.stop(pid)
          IO.puts("#{inspect(repo)} stopped successfully")
        else
          IO.puts("#{inspect(repo)} was not running")
        end
      rescue
        e -> IO.puts("Error while stopping #{inspect(repo)}: #{inspect(e)}")
      end
    end)
  end

  @doc """
  Cleans up the event store
  """
  def cleanup_event_store do
    IO.puts("Cleaning up event store...")

    # Get the configured test event store module
    test_store = Application.get_env(:game_bot, :event_store_adapter, GameBot.TestEventStore)

    # Attempt to stop the event store
    try do
      if Process.whereis(test_store) do
        test_store.stop()
        IO.puts("Event store stopped successfully")
      else
        IO.puts("Event store was not running")
      end
    rescue
      e -> IO.puts("Error while stopping event store: #{inspect(e)}")
    end
  end
end

# Initialize the test environment
GameBot.Test.Setup.initialize()
