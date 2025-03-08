# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.

# Start ExUnit with a longer timeout for tests
ExUnit.start(timeout: 30_000)

# Configure the application for testing
Application.put_env(:game_bot, :start_word_service, false)
Application.put_env(:game_bot, :start_nostrum, false)
Application.put_env(:nostrum, :token, "fake_token_for_testing")
Application.put_env(:nostrum, :api_module, GameBot.Test.Mocks.NostrumApiMock)

# Configure event stores to avoid warnings
Application.put_env(:game_bot, :event_stores, [
  GameBot.Infrastructure.Persistence.EventStore
])

# Only start the application if explicitly requested or not in isolated test mode
if System.get_env("ISOLATED_TEST") != "true" do
  # Get repository references
  alias GameBot.Infrastructure.Persistence.Repo
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres, as: EventStoreRepo

  # Ensure clean state before tests run
  # Kill any existing connections that might interfere with tests
  IO.puts("Cleaning up existing database connections before tests...")

  Enum.each(Process.list(), fn pid ->
    info = Process.info(pid, [:dictionary])
    if info && get_in(info, [:dictionary, :"$initial_call"]) == {Postgrex.Protocol, :init, 1} do
      Process.exit(pid, :kill)
    end
  end)

  # Small sleep to allow processes to terminate
  Process.sleep(100)

  # Start required applications in the correct order
  IO.puts("Starting database applications...")
  {:ok, _} = Application.ensure_all_started(:postgrex)
  {:ok, _} = Application.ensure_all_started(:ecto_sql)

  # Actually start the repos explicitly before trying to use them
  # Use a consistent configuration for both repos with reduced timeouts
  repo_config = [
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 5,
    queue_target: 200,
    queue_interval: 1000,
    ownership_timeout: 30_000
  ]

  # Start the repos with retry logic in case of timing issues using a proper named function
  IO.puts("Starting database repositories...")

  # Define a named function for repository startup with retries
  defmodule StartupHelpers do
    def start_repo(repo, config, attempts) do
      try do
        IO.puts("Attempting to start #{inspect(repo)}")
        {:ok, _} = repo.start_link(config)
        IO.puts("Successfully started #{inspect(repo)}")
        :ok
      rescue
        e ->
          if attempts > 1 do
            IO.puts("Failed to start #{inspect(repo)}, retrying... (#{attempts-1} attempts left): #{inspect(e)}")
            Process.sleep(500)
            start_repo(repo, config, attempts - 1)
          else
            IO.puts("Failed to start #{inspect(repo)}: #{inspect(e)}")
            {:error, e}
          end
      end
    end
  end

  # Call the function with explicit arguments
  :ok = StartupHelpers.start_repo(Repo, repo_config, 3)
  :ok = StartupHelpers.start_repo(EventStoreRepo, repo_config, 3)

  # Make sure tables are reset before tests run
  IO.puts("Cleaning database state...")
  try do
    # Apply truncation with a timeout, but handle possible errors safely
    truncate_query = "TRUNCATE event_store.streams, event_store.events, event_store.subscriptions CASCADE"
    IO.puts("Executing: #{truncate_query}")
    result = Repo.query(truncate_query, [], timeout: 5000)
    case result do
      {:ok, _} -> IO.puts("Database tables truncated successfully")
      {:error, error} -> IO.puts("Warning: Error truncating tables: #{inspect(error)}")
    end
  rescue
    e ->
      IO.puts("Warning: Failed to truncate tables: #{inspect(e)}")
  end

  # Configure sandbox mode for testing with consistent settings
  IO.puts("Configuring sandbox mode...")
  Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)
  Ecto.Adapters.SQL.Sandbox.mode(EventStoreRepo, :manual)

  # Start only the necessary applications for testing, excluding Nostrum
  IO.puts("Starting application in test mode...")

  # List of applications to start, excluding those that might cause issues in tests
  apps_to_start = [
    :logger,
    :ecto,
    :ecto_sql,
    :postgrex,
    :telemetry,
    :jason,
    :commanded,
    :commanded_eventstore_adapter,
    :eventstore
  ]

  # Start each application individually instead of starting game_bot
  Enum.each(apps_to_start, fn app ->
    IO.puts("Starting #{app}...")
    case Application.ensure_all_started(app) do
      {:ok, _} -> IO.puts("#{app} started successfully")
      {:error, error} -> IO.puts("Warning: Failed to start #{app}: #{inspect(error)}")
    end
  end)

  IO.puts("Starting GameBot application modules...")

  # Start only the GameBot test components necessary for tests
  # Skip starting the full application with ensure_all_started

  IO.puts("Test environment ready")
end
