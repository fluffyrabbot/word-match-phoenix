import Config

# Use predefined database names from environment
config :game_bot, GameBot.Infrastructure.Persistence.Repo,
  database: "game_bot_test_1741513046",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5,
  ownership_timeout: 60_000

config :game_bot, GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres,
  database: "game_bot_eventstore_test_1741513046",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5,
  ownership_timeout: 60_000

config :game_bot, GameBot.Infrastructure.Persistence.EventStore,
  database: "game_bot_eventstore_test_1741513046",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5,
  ownership_timeout: 60_000

config :game_bot, GameBot.Infrastructure.Persistence.Repo.Postgres,
  database: "game_bot_test_1741513046",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5,
  ownership_timeout: 60_000

# Store database names in application env for access in scripts
config :game_bot, :test_databases,
  main_db: "game_bot_test_1741513046",
  event_db: "game_bot_eventstore_test_1741513046"
