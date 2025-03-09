# Ensure protocols are not consolidated in a way that prevents test implementations
Code.put_compiler_option(:ignore_module_conflict, true)
Code.compiler_options(ignore_module_conflict: true)

# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.

# Configure ExUnit with appropriate settings
ExUnit.configure(
  exclude: [:skip_db],
  timeout: 60_000,
  trace: false,
  seed: 0,
  formatters: [ExUnit.CLIFormatter]
)

# Start ExUnit
ExUnit.start()

# Initialize test environment using centralized DatabaseHelper
case GameBot.Test.DatabaseHelper.initialize_test_environment() do
  :ok ->
    IO.puts("\n=== Test Environment Initialized Successfully ===\n")
  {:error, reason} ->
    IO.puts("\n=== Failed to Initialize Test Environment ===")
    IO.puts("Reason: #{inspect(reason)}")
    System.halt(1)
end

# Register cleanup for after the test suite
ExUnit.after_suite(fn _ ->
  IO.puts("\n=== Cleaning up after test suite ===")
  GameBot.Test.DatabaseHelper.cleanup_connections()
  IO.puts("=== Test suite cleanup complete ===\n")
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

  @db_operation_timeout 30_000
  @max_retries 3
  @retry_delay 1000

  @doc """
  Initializes the entire test environment.

  This function should be called once at the beginning of the test run
  to ensure all services are properly configured and started.
  """
  def initialize do
    IO.puts("\nWorking with databases: main=#{get_main_db_name()}, event=#{get_event_db_name()}")

    # Start required applications
    start_required_applications()

    # Initialize repositories
    initialize_repositories()

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
  """
  def setup_sandbox(tags) do
    if !tags[:mock] do
      setup_postgres_sandbox(tags)
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
GameBot.Test.Setup.initialize()

# Store test result
result = ExUnit.run()

# Add clear visual separator
IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("TEST EXECUTION COMPLETED")
IO.puts(String.duplicate("=", 80) <> "\n")

# Cleanup with reduced output
IO.puts("Starting cleanup process...")
Logger.configure(level: :error)

# Exit with proper status code
if !result, do: System.halt(1)
