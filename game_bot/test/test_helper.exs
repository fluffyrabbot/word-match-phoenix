# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.

# Start ExUnit
ExUnit.start()

# Configure the application for testing
Application.put_env(:game_bot, :start_word_service, false)
Application.put_env(:game_bot, :start_nostrum, false)
Application.put_env(:nostrum, :token, "mock_token")
Application.put_env(:nostrum, :api_module, GameBot.Test.Mocks.NostrumApiMock)

# Only start the application if explicitly requested or not in isolated test mode
if System.get_env("ISOLATED_TEST") != "true" do
  # Get repository references
  alias GameBot.Infrastructure.Persistence.Repo
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres, as: EventStoreRepo

  # Ensure clean state before tests run
  # Kill any existing connections that might interfere with tests
  Enum.each(Process.list(), fn pid ->
    info = Process.info(pid, [:dictionary])
    if info && get_in(info, [:dictionary, :"$initial_call"]) == {Postgrex.Protocol, :init, 1} do
      Process.exit(pid, :kill)
    end
  end)

  # Start required applications in the correct order
  {:ok, _} = Application.ensure_all_started(:postgrex)
  {:ok, _} = Application.ensure_all_started(:ecto_sql)

  # Actually start the repos explicitly before trying to use them
  # Use a consistent configuration for both repos
  repo_config = [
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10,
    ownership_timeout: 60_000
  ]

  {:ok, _} = Repo.start_link(repo_config)
  {:ok, _} = EventStoreRepo.start_link(repo_config)

  # Make sure tables are reset before tests run
  try do
    Repo.query!("TRUNCATE event_store.streams, event_store.events, event_store.subscriptions CASCADE")
  rescue
    _ -> :ok
  end

  # Configure sandbox mode for testing with consistent settings
  Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)
  Ecto.Adapters.SQL.Sandbox.mode(EventStoreRepo, :manual)

  # Start the rest of the application
  {:ok, _} = Application.ensure_all_started(:game_bot)
end
