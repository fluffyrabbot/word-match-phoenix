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
  pool_size: 2

# Configure the main repositories
config :game_bot, ecto_repos: [
  GameBot.Infrastructure.Persistence.Repo,
  GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
]

# Configure the main repository
config :game_bot, GameBot.Infrastructure.Persistence.Repo,
  username: "postgres",
  password: "csstarahid",
  hostname: "localhost",
  database: "game_bot_test",
  port: 5432,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# Configure the event store adapter
config :game_bot, GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres,
  username: "postgres",
  password: "csstarahid",
  hostname: "localhost",
  database: "game_bot_test",
  port: 5432,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# Configure EventStore for testing (for compatibility with existing code)
config :game_bot, GameBot.Infrastructure.EventStore.Config,
  serializer: GameBot.Infrastructure.EventStore.Serializer,
  username: "postgres",
  password: "csstarahid",
  database: "game_bot_test",
  hostname: "localhost",
  schema_prefix: "event_store",
  column_data_type: "jsonb",
  pool_size: 5,
  max_append_retries: 3

# Configure Commanded for testing
config :game_bot, GameBot.Infrastructure.CommandedApp,
  event_store: [
    adapter: Commanded.EventStore.Adapters.EventStore,
    event_store: GameBot.Infrastructure.EventStore.Config
  ],
  pubsub: :local,
  registry: :local

# Configure Nostrum for testing
config :nostrum,
  token: "test_token",
  gateway_intents: :all,
  api_module: GameBot.Test.Mocks.NostrumApiMock,
  cache_module: GameBot.Test.Mocks.NostrumCacheMock

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

# Configure test adapters
config :game_bot,
  event_store_adapter: GameBot.TestEventStore,
  start_word_service: false,
  start_nostrum: false

# Configure Discord message handling settings
config :game_bot,
  rate_limit_window_seconds: 60,
  max_messages_per_window: 30,
  max_word_length: 50,
  min_word_length: 2

# Initialize sandbox for tests
config :game_bot, :sql_sandbox, true
