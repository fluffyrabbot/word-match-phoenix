import Config

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.

# Configure EventStore for production
config :game_bot, GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres,
  username: System.get_env("EVENT_STORE_USER"),
  password: System.get_env("EVENT_STORE_PASS"),
  database: System.get_env("EVENT_STORE_DB", "game_bot_eventstore"),
  hostname: System.get_env("EVENT_STORE_HOST"),
  schema_prefix: "game_events",
  column_data_type: "jsonb",
  types: EventStore.PostgresTypes,
  pool_size: String.to_integer(System.get_env("EVENT_STORE_POOL_SIZE", "20")),
  ssl: true
