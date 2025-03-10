import Config

# Configure main database
config :game_bot, GameBot.Infrastructure.Persistence.Repo,
  username: "postgres",
  password: "csstarahid",
  hostname: "localhost",
  database: "game_bot_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5

# Configure event store database
config :game_bot, GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres,
  username: "postgres",
  password: "csstarahid",
  hostname: "localhost",
  database: "game_bot_eventstore_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5

# Configure eventstore settings
config :game_bot, GameBot.Infrastructure.Persistence.EventStore,
  column_data_type: "jsonb",
  serializer: GameBot.Infrastructure.Persistence.EventStore.JsonSerializer,
  types: GameBot.PostgresTypes,
  username: "postgres",
  password: "csstarahid",
  hostname: "localhost",
  database: "game_bot_eventstore_test",
  schema: "event_store"
