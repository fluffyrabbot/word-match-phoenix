# Ensure protocols are not consolidated in a way that prevents test implementations
Code.put_compiler_option(:ignore_module_conflict, true)
Code.compiler_options(ignore_module_conflict: true)

# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.

# ===================================================================
# DATABASE INITIALIZATION NOTE:
#
# Test database initialization follows this sequence:
# 1. Configure ExUnit and start applications
# 2. Use GameBot.Test.DatabaseManager.initialize() for database setup
# 3. Any direct calls to GameBot.Test.Setup.* are deprecated
#    and should be migrated to use DatabaseManager functions
# ===================================================================

# Configure ExUnit with appropriate settings
ExUnit.configure(
  exclude: [:skip_db, :skip_in_ci],
  timeout: 60_000,
  trace: false,
  seed: 0,
  formatters: [ExUnit.CLIFormatter],
  max_cases: System.schedulers_online() * 2
)

# Define a maximum retry count for database initialization
max_db_init_retries = 3
db_retry_delay = 1000

# Start ExUnit
ExUnit.start()

# Initialize Phoenix endpoint for tests
Application.put_env(:game_bot, GameBotWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  server: false,
  secret_key_base: "T3vbojxPj5xC0BUswQBDiQ0+6v2QLkvCw/PQQgzxmxqTmH+vCb0uibzPYpZsysVz",
  live_view: [signing_salt: "your_signing_salt"],
  pubsub_server: GameBot.PubSub
)

# Initialize PubSub for tests
children =
  case Process.whereis(GameBot.PubSub) do
    nil ->
      [{Phoenix.PubSub, name: GameBot.PubSub}]
    _pid ->
      []  # PubSub already started, don't start it again
  end

# Start PubSub under a test supervisor if needed
if children != [] do
  {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one, name: GameBot.TestSupervisor)
end

# Start required applications in correct order
# Ensure we start them in the right order with proper error handling
required_apps = [
  :phoenix,
  :phoenix_ecto,
  :postgrex,
  :ecto,
  :ecto_sql,
  :eventstore
]

# Start each application with error handling
Enum.each(required_apps, fn app ->
  case Application.ensure_all_started(app) do
    {:ok, _} -> :ok
    {:error, {dep, reason}} ->
      IO.puts("\n=== Failed to start #{app}. Dependency #{dep} failed ===")
      IO.puts("Reason: #{inspect(reason)}")
      System.halt(1)
  end
end)

# Note: For improved test database setup, use the new mix task:
#   mix game_bot.test
#
# This task handles database setup, test execution, and cleanup automatically.
# See README_TEST_INFRASTRUCTURE.md for details.

# Initialize test environment using centralized DatabaseManager with retry logic
# This implementation uses a retry loop with exponential backoff to handle
# temporary failures during initialization
result = Enum.reduce_while(1..max_db_init_retries, {:error, :not_attempted}, fn attempt, _acc ->
  IO.puts("\n=== Initializing test environment (attempt #{attempt}/#{max_db_init_retries}) ===")

  case GameBot.Test.DatabaseManager.initialize() do
    :ok ->
      IO.puts("\n=== Test Environment Initialized Successfully ===\n")
      {:halt, :ok}

    {:error, reason} ->
      IO.puts("\n=== Failed to Initialize Test Environment ===")
      IO.puts("Reason: #{inspect(reason)}")

      if attempt < max_db_init_retries do
        # Wait with exponential backoff before retrying
        retry_delay = db_retry_delay * attempt
        IO.puts("Retrying in #{retry_delay}ms...")
        Process.sleep(retry_delay)
        {:cont, {:error, reason}}
      else
        IO.puts("Maximum retry attempts reached. Giving up.")
        {:halt, {:error, reason}}
      end
  end
end)

# Verify the result and terminate if initialization failed
case result do
  :ok -> :ok  # Continue with test execution
  {:error, reason} ->
    IO.puts("\n=== FATAL: Test environment initialization failed after multiple attempts ===")
    IO.puts("Final error: #{inspect(reason)}")
    IO.puts("Terminating test run.")
    System.halt(1)
end

# Register cleanup for after the test suite with proper error handling
ExUnit.after_suite(fn _ ->
  IO.puts("\n=== Cleaning up after test suite ===")

  case GameBot.Test.DatabaseManager.cleanup() do
    :ok ->
      IO.puts("=== Test suite cleanup complete ===\n")

    {:error, reason} ->
      IO.puts("=== Warning: Test suite cleanup failed ===")
      IO.puts("Reason: #{inspect(reason)}")
      IO.puts("This may affect future test runs. Manual cleanup may be required.")
  end
end)

# Configure the application for testing
Application.put_env(:game_bot, :start_word_service, false)
Application.put_env(:game_bot, :start_nostrum, false)
Application.put_env(:nostrum, :token, "fake_token_for_testing")
Application.put_env(:nostrum, :api_module, GameBot.Test.Mocks.NostrumApiMock)

# Configure event stores to avoid warnings
Application.put_env(:game_bot, :event_stores, [
  GameBot.Infrastructure.Persistence.EventStore
])

# Define a helper module to ensure protocol implementations are registered properly
defmodule GameBot.Test.ProtocolHelpers do
  @moduledoc """
  Helper functions for dealing with protocol consolidation in tests.
  """

  @doc """
  Force protocol implementations to be recompiled if needed.
  """
  def ensure_protocol_implementations do
    # Force relevant modules to be available to protocols
    modules = [
      # Module aliases that implement protocols
      GameBot.Domain.Events.TestEvents.ValidatorTestEvent,
      GameBot.Domain.Events.TestEvents.ValidatorOptionalFieldsEvent
    ]

    # Reset any consolidated protocols that might interfere with our test implementations
    for protocol <- [GameBot.Domain.Events.EventValidator] do
      # Clean up consolidated protocol
      consolidated_path = :code.priv_dir(:game_bot)
                         |> Path.join("/protocol_consolidation/#{Atom.to_string(protocol)}.beam")

      # If the consolidated protocol exists, delete it to force runtime protocol dispatch
      if File.exists?(consolidated_path) do
        File.rm(consolidated_path)
        IO.puts("Removed consolidated protocol: #{consolidated_path}")
      end
    end

    # Force recompilation of protocol implementation file
    test_events_path = Path.join([File.cwd!(), "test", "support", "test_events.ex"])
    if File.exists?(test_events_path) do
      # Remove any existing compiled modules
      for module <- modules do
        :code.purge(module)
        :code.delete(module)
      end

      # Recompile the file
      Code.compile_file(test_events_path)
      IO.puts("Recompiled test events file: #{test_events_path}")
    else
      IO.puts("Warning: Test events file not found at #{test_events_path}")
    end

    # Ensure modules are loaded
    for module <- modules do
      # Make sure the module is loaded
      if Code.ensure_loaded?(module) do
        IO.puts("Protocol implementation module loaded: #{inspect(module)}")
      else
        IO.puts("Warning: Failed to load module: #{inspect(module)}")
      end
    end
  end
end

# Run protocol implementation checks
GameBot.Test.ProtocolHelpers.ensure_protocol_implementations()

defmodule GameBot.Test.Setup do
  @moduledoc """
  Setup module for the test environment.

  This module provides legacy functionality for test setup.
  The primary initialization is now handled by GameBot.Test.DatabaseManager.
  This module is kept for compatibility with tests that directly use its functions.

  For new tests, prefer using the DatabaseManager approach:
  - Use GameBot.Test.DatabaseManager.initialize() for environment setup
  - Use GameBot.Test.DatabaseManager.setup_sandbox(tags) for sandbox configuration
  """

  import ExUnit.Callbacks, only: [on_exit: 1]
  alias GameBot.Infrastructure.Persistence.Repo
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres, as: EventStoreRepo

  @db_operation_timeout 30_000
  @max_retries 3
  @retry_delay 1000

  @doc """
  Initializes the entire test environment.

  DEPRECATED: Use GameBot.Test.DatabaseManager.initialize() instead.
  This function is kept for backward compatibility with existing tests.
  """
  def initialize do
    IO.puts("\n[DEPRECATED] Using legacy Setup.initialize(). Consider migrating to DatabaseManager.initialize().")
    IO.puts("Working with databases: main=#{get_main_db_name()}, event=#{get_event_db_name()}")

    # Start required applications is now handled by the main test_helper.exs initialization
    # Initialize repositories is now handled by DatabaseManager.initialize()

    # Return :ok for compatibility
    :ok
  end

  defp get_main_db_name do
    Application.get_env(:game_bot, :test_databases)[:main_db]
  end

  defp get_event_db_name do
    Application.get_env(:game_bot, :test_databases)[:event_db]
  end

  @doc """
  Sets up the sandbox based on the test tags.

  DEPRECATED: For new tests, use GameBot.Test.DatabaseManager.setup_sandbox/1 instead.
  This function now delegates to DatabaseManager.setup_sandbox/1 for compatibility.
  """
  def setup_sandbox(tags) do
    if !tags[:mock] do
      # Delegate to DatabaseManager for consistency
      case GameBot.Test.DatabaseManager.setup_sandbox(tags) do
        :ok -> :ok
        {:error, reason} ->
          IO.puts("Warning: Failed to set up sandbox through DatabaseManager: #{inspect(reason)}")
          # Fall back to legacy implementation for backwards compatibility
          setup_postgres_sandbox(tags)
      end
    else
      :ok
    end
  end

  defp setup_postgres_sandbox(tags) do
    with_retries(@max_retries, fn ->
      {:ok, repo_pid} = start_sandbox_owner(Repo, tags)
      {:ok, event_store_pid} = start_sandbox_owner(EventStoreRepo, tags)

      on_exit(fn ->
        try do
          stop_sandbox_owner(repo_pid)
          stop_sandbox_owner(event_store_pid)
        rescue
          e ->
            IO.puts("Warning: Failed to stop owners: #{inspect(e)}")
            terminate_repo_connections()
        end
      end)

      :ok
    end)
  end

  defp start_sandbox_owner(repo, tags) do
    case Ecto.Adapters.SQL.Sandbox.start_owner!(repo, shared: not tags[:async]) do
      pid when is_pid(pid) -> {:ok, pid}
      error -> {:error, error}
    end
  end

  defp stop_sandbox_owner(pid) do
    try do
      Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
    rescue
      e -> IO.puts("Warning: Failed to stop owner #{inspect(pid)}: #{inspect(e)}")
    end
  end

  defp with_retries(0, _fun), do: raise "Max retries exceeded"
  defp with_retries(retries, fun) do
    try do
      fun.()
    rescue
      e ->
        IO.puts("Error in retry #{retries}: #{inspect(e)}")
        :timer.sleep(@retry_delay)
        with_retries(retries - 1, fun)
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
        {:ok, _} -> :ok
        {:error, {dep, reason}} ->
          IO.puts("Failed to start #{app}. Dependency #{dep} failed with: #{inspect(reason)}")
          raise "Application startup failure"
      end
    end)
  end

  @doc """
  Initializes and configures repository connections.
  """
  def initialize_repositories do
    IO.puts("Initializing repositories...")

    repos = [Repo, EventStoreRepo]

    # Stop any existing repos
    Enum.each(repos, &ensure_repo_stopped/1)

    # Start repos with their config from test.exs
    Enum.each(repos, &ensure_repo_started/1)

    # Configure sandbox mode
    Enum.each(repos, &configure_sandbox/1)
  end

  defp ensure_repo_stopped(repo) do
    case Process.whereis(repo) do
      nil -> :ok
      _pid ->
        try do
          repo.stop()
          Process.sleep(100)
        rescue
          _ -> terminate_repo_connections()
        end
    end
  end

  defp ensure_repo_started(repo) do
    IO.puts("Starting #{inspect(repo)}...")

    # Get the repository's configuration from test.exs
    config = Application.get_env(:game_bot, repo)

    if config == nil do
      raise "No configuration found for #{inspect(repo)} in test.exs"
    end

    case repo.start_link(config) do
      {:ok, _pid} ->
        Process.sleep(100) # Give repo time to initialize
        :ok
      {:error, {:already_started, _pid}} ->
        :ok
      {:error, error} ->
        raise "Failed to start #{inspect(repo)}: #{inspect(error)}"
    end
  end

  defp configure_sandbox(repo) do
    :ok = Ecto.Adapters.SQL.Sandbox.mode(repo, :manual)
  end

  defp terminate_repo_connections do
    # Force close all connections
    terminate_postgres_connections()
  end

  defp terminate_postgres_connections do
    query = """
    SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE pid <> pg_backend_pid()
    AND datname IN ($1, $2)
    """

    {:ok, conn} = Postgrex.start_link(
      hostname: "localhost",
      username: "postgres",
      password: "csstarahid",
      database: "postgres"
    )

    Postgrex.query!(conn, query, [get_main_db_name(), get_event_db_name()])
    GenServer.stop(conn)
  end
end

# Configure the application for testing
# GameBot.Test.Setup.initialize()  # REMOVED: Functionality consolidated into DatabaseManager-based initialization

defmodule GameBot.Test.Cleanup do
  def cleanup_test_resources do
    # Stop test event store
    if Process.whereis(GameBot.Test.EventStoreCore) do
      GameBot.Test.EventStoreCore.reset()
    end

    # Close database connections
    GameBot.Test.DatabaseHelper.cleanup_connections()

    # Clear ETS tables
    for table <- [:game_bot_cache, :game_bot_session_cache, :game_bot_metrics] do
      if :ets.info(table) != :undefined do
        :ets.delete_all_objects(table)
      end
    end
  end
end

# Register cleanup for after each test
ExUnit.after_suite(fn _ ->
  GameBot.Test.Cleanup.cleanup_test_resources()
end)
