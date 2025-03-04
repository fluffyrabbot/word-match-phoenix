# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :game_bot,
  ecto_repos: [GameBot.Infrastructure.Repo],
  generators: [timestamp_type: :utc_datetime],
  event_stores: [GameBot.Infrastructure.EventStore.Config]

# Configure Commanded for event sourcing
config :game_bot, GameBot.Infrastructure.CommandedApp,
  event_store: [
    adapter: Commanded.EventStore.Adapters.EventStore,
    event_store: GameBot.Infrastructure.EventStore.Config
  ],
  pubsub: :local,
  registry: :local

# Configure EventStore
config :game_bot, GameBot.Infrastructure.EventStore.Config,
  serializer: EventStore.JsonSerializer,
  username: "postgres",
  password: "csstarahid",
  database: "game_bot_eventstore",
  hostname: "localhost",
  pool_size: 10

# Configures the endpoint
config :game_bot, GameBotWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: GameBotWeb.ErrorHTML, json: GameBotWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: GameBot.PubSub,
  live_view: [signing_salt: "juvFeCTM"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
