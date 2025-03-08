import Config

# Use predefined database names from environment
config :game_bot, GameBot.Infrastructure.Persistence.Repo,
  database: "game_bot_test_1741441625"

config :game_bot, GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres,
  database: "game_bot_eventstore_test_1741441625"

config :game_bot, GameBot.Infrastructure.Persistence.EventStore,
  database: "game_bot_eventstore_test_1741441625"

config :game_bot, GameBot.Infrastructure.Persistence.Repo.Postgres,
  database: "game_bot_test_1741441625"

# Store database names in application env for access in scripts
config :game_bot, :test_databases,
  main_db: "game_bot_test_1741441625",
  event_db: "game_bot_eventstore_test_1741441625"
