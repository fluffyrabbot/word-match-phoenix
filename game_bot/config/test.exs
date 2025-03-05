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
config :game_bot, GameBot.Infrastructure.EventStore,
  serializer: GameBot.Infrastructure.EventStore.Serializer,
  username: System.get_env("EVENT_STORE_USER", "postgres"),
  password: System.get_env("EVENT_STORE_PASS", "postgres"),
  database: System.get_env("EVENT_STORE_DB", "game_bot_eventstore_test"),
  hostname: System.get_env("EVENT_STORE_HOST", "localhost"),
  schema_prefix: "game_events",
  column_data_type: "jsonb",
  types: EventStore.PostgresTypes,
  pool_size: 5,
  schema_wait: true,  # Wait for schema to be ready in tests
  max_append_retries: 1,
  max_stream_size: 100,
  subscription_timeout: :timer.seconds(5)

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

config :game_bot, :event_store, GameBot.TestEventStore

# Use in-memory store for tests
config :game_bot, event_store_adapter: GameBot.TestEventStore
