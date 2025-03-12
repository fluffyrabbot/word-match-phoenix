import Config

# Configure EventStore for testing
config :game_bot, GameBot.TestEventStore,
  column_data_type: "jsonb",
  serializer: GameBot.Infrastructure.Persistence.EventStore.Serializer,
  types: EventStore.PostgresTypes,
  username: "postgres",
  password: "csstarahid",
  database: "game_bot_eventstore_test",
  hostname: "localhost",
  pool_size: 1,
  pool_overflow: 0

# Configure Commanded for event sourcing
config :game_bot, :commanded,
  event_store_adapter: Commanded.EventStore.Adapters.EventStore

# Minimal logger config
config :logger, level: :info
