# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.

# Start ExUnit
ExUnit.start()

# Prevent automatic starts
Application.put_env(:game_bot, :start_word_service, false)
Application.put_env(:nostrum, :token, "mock_token")
Application.put_env(:nostrum, :api_module, GameBot.Test.Mocks.NostrumApiMock)

# Start required applications in order
{:ok, _} = Application.ensure_all_started(:logger)
{:ok, _} = Application.ensure_all_started(:postgrex)
{:ok, _} = Application.ensure_all_started(:ecto_sql)

# Start the Repo
{:ok, _} = GameBot.Infrastructure.Persistence.Repo.start_link()

# Start EventStore
{:ok, _} = Application.ensure_all_started(:eventstore)

# Initialize EventStore database
Mix.Task.run("event_store.drop", ["--quiet"])
Mix.Task.run("event_store.create", ["--quiet"])
Mix.Task.run("event_store.init", ["--quiet"])

# Start the main application
{:ok, _} = Application.ensure_all_started(:game_bot)

# Configure sandbox mode for tests
Ecto.Adapters.SQL.Sandbox.mode(GameBot.Infrastructure.Persistence.Repo, :manual)
