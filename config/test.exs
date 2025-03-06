# Add this to the test.exs config file

# Configure the mock for testing
config :game_bot, :event_store,
  max_retries: 3,
  initial_backoff_ms: 50,
  max_append_retries: 3,
  max_stream_size: 1000,
  implementation: GameBot.Test.Mocks.EventStore

# Configure the Event Store for testing (if needed)
config :game_bot, GameBot.Infrastructure.EventStore,
  serializer: GameBot.Infrastructure.EventStore.JsonSerializer,
  username: "postgres",
  password: "postgres",
  database: "game_bot_eventstore_test",
  hostname: "localhost"

# Configure the event store test database
config :game_bot, GameBot.EventStore,
  serializer: EventStore.JsonSerializer,
  username: "postgres",
  password: "postgres",
  database: "game_bot_eventstore_test",
  hostname: "localhost"
