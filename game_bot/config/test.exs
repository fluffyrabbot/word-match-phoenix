import Config

# Generate unique database names for each test run to avoid connection conflicts
unique_suffix = System.get_env("MIX_TEST_PARTITION") || System.system_time(:second)
main_db_name = "game_bot_test_#{unique_suffix}"
event_db_name = "game_bot_eventstore_test_#{unique_suffix}"

# Get the pool size from environment or use default
pool_size = String.to_integer(System.get_env("ECTO_POOL_SIZE") || "10")

# Configure the main repositories
config :game_bot, ecto_repos: [
  GameBot.Infrastructure.Persistence.Repo,
  GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
]

# Set explicit event stores to avoid warnings
config :game_bot, event_stores: [
  GameBot.Infrastructure.Persistence.EventStore
]

# Configure the main repository with appropriate timeouts
# Increased timeouts for better reliability
config :game_bot, GameBot.Infrastructure.Persistence.Repo,
  username: "postgres",
  password: "csstarahid",
  hostname: "localhost",
  database: main_db_name,
  port: 5432,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: pool_size,
  pool_timeout: 15000,
  ownership_timeout: 60_000,
  queue_target: 5000,
  queue_interval: 5000,
  timeout: 30_000,
  connect_timeout: 30_000,
  idle_interval: 5000,
  backoff_type: :exp,
  max_restarts: 3,
  max_seconds: 5,
  types: EventStore.PostgresTypes

# Configure the Postgres adapter for the EventStore
# Increased timeouts for better reliability
config :game_bot, GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres,
  username: "postgres",
  password: "csstarahid",
  hostname: "localhost",
  database: event_db_name,
  port: 5432,
  types: EventStore.PostgresTypes,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: pool_size,
  pool_timeout: 15000,
  ownership_timeout: 60_000,
  queue_target: 200,
  queue_interval: 1000,
  timeout: 30_000,
  connect_timeout: 30_000,
  idle_interval: 5000,
  backoff_type: :exp,
  max_restarts: 3,
  max_seconds: 5

# Configure the event store for testing
# Increased timeouts for better reliability
config :game_bot, GameBot.Infrastructure.Persistence.EventStore,
  serializer: GameBot.Infrastructure.Persistence.EventStore.Serializer,
  username: "postgres",
  password: "csstarahid",
  hostname: "localhost",
  database: event_db_name,
  port: 5432,
  schema: "event_store",
  schema_prefix: "event_store",
  column_data_type: "jsonb",
  types: EventStore.PostgresTypes,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: pool_size,
  pool_timeout: 15000,
  ownership_timeout: 60_000,
  timeout: 30_000,
  connect_timeout: 30_000,
  idle_interval: 5000,
  backoff_type: :exp,
  max_restarts: 3,
  max_seconds: 5

# Configure the Postgres repository
config :game_bot, GameBot.Infrastructure.Persistence.Repo.Postgres,
  username: "postgres",
  password: "csstarahid",
  hostname: "localhost",
  database: main_db_name,
  port: 5432,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: pool_size,
  ownership_timeout: 60_000,
  queue_target: 200,
  queue_interval: 1000,
  timeout: 30_000,
  connect_timeout: 30_000

# Configure event store directly
config :eventstore,
  column_data_type: "jsonb",
  registry: :local,
  serializer: GameBot.Infrastructure.Persistence.EventStore.Serializer

# For testing, explicitly configure EventStore modules
config :game_bot, :event_store_adapter, GameBot.TestEventStore

# Configure Commanded for testing
config :game_bot, GameBot.Infrastructure.CommandedApp,
  event_store: [
    adapter: Commanded.EventStore.Adapters.InMemory,
    event_store: GameBot.TestEventStore
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

# Print more information during tests
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

# Store database names in application env for access in scripts
config :game_bot, :test_databases,
  main_db: main_db_name,
  event_db: event_db_name
