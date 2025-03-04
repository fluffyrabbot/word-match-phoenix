# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
ExUnit.start()

# Stop any running applications
Application.stop(:game_bot)
Application.stop(:commanded)
Application.stop(:eventstore)

# Configure test environment to not start WordService automatically
Application.put_env(:game_bot, :start_word_service, false)

# Start applications in order
{:ok, _} = Application.ensure_all_started(:commanded)
{:ok, _} = Application.ensure_all_started(:eventstore)
{:ok, _} = Application.ensure_all_started(:game_bot)

# Configure Ecto sandbox mode
Ecto.Adapters.SQL.Sandbox.mode(GameBot.Infrastructure.Repo, :manual)

# Configure EventStore sandbox mode
config = Application.get_env(:game_bot, GameBot.Infrastructure.EventStore.Config)
config = Keyword.put(config, :schema, "public")

# Initialize EventStore
:ok = EventStore.Tasks.Create.exec(config, [])
:ok = EventStore.Tasks.Init.exec(config, [])
