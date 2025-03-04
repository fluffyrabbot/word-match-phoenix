import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :game_bot, GameBot.Infrastructure.Repo,
  username: "postgres",
  password: "csstarahid",
  hostname: "localhost",
  database: "game_bot_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Configure EventStore for testing
config :game_bot, GameBot.Infrastructure.EventStore.Config,
  serializer: EventStore.JsonSerializer,
  username: "postgres",
  password: "csstarahid",
  database: "game_bot_eventstore_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool_size: 1,
  schema: "public"

# Configure Commanded for testing
config :game_bot, GameBot.Infrastructure.CommandedApp,
  event_store: [
    adapter: Commanded.EventStore.Adapters.EventStore,
    event_store: GameBot.Infrastructure.EventStore.Config
  ],
  pubsub: :local,
  registry: :local

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :game_bot, GameBotWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "T3vbojxPj5xC0BUswQBDiQ0+6v2QLkvCw/PQQgzxmxqTmH+vCb0uibzPYpZsysVz",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
