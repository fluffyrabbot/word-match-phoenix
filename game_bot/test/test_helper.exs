# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.

# Configure ExUnit for our test environment with sensible defaults
ExUnit.configure(
  capture_log: true,
  assert_receive_timeout: 500,
  exclude: [:skip_checkout],
  timeout: 120_000,  # Longer timeout since we may have db operations
  colors: [enabled: true],
  diff_enabled: true,
  max_cases: 1  # Run tests serially to avoid connection issues
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
