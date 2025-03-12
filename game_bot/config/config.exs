# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Configure the repositories
config :game_bot, ecto_repos: [
  GameBot.Infrastructure.Persistence.Repo,
  GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
]

# Configure EventStore explicitly
config :game_bot, event_stores: [
  GameBot.Infrastructure.Persistence.EventStore
]

# Configure EventStore for all environments
config :eventstore, column_data_type: "jsonb"

# Explicitly set the event store adapter
config :game_bot, eventstore_adapter: GameBot.Infrastructure.Persistence.EventStore

# Set up command bus
config :game_bot, GameBot.Infrastructure.CommandedApp,
  event_store: [
    adapter: Commanded.EventStore.Adapters.EventStore,
    event_store: GameBot.Infrastructure.Persistence.EventStore
  ],
  pubsub: :local,
  registry: :local

# Configure the main repository
config :game_bot, GameBot.Infrastructure.Persistence.Repo, types: EventStore.PostgresTypes

# Configure Nostrum
config :nostrum,
  token: System.get_env("DISCORD_BOT_TOKEN"),
  gateway_intents: :all

# Event system configuration
config :game_bot, :event_system,
  use_enhanced_pubsub: false  # Start with this disabled, enable after testing

# Import event optimization configuration
import_config "event_optimization.exs"

# Configures the endpoint
config :game_bot, GameBotWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: GameBotWeb.ErrorHTML, json: GameBotWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: GameBot.PubSub,
  live_view: [signing_salt: "jFiEJECy"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :game_bot, GameBot.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.2.7",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
