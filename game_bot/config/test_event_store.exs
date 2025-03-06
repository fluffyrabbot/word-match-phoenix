import Config

# Configure EventStore for testing
config :game_bot, GameBot.Infrastructure.EventStore.Config,
  serializer: EventStore.JsonSerializer,
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
