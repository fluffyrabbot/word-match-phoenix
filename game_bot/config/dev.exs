import Config

# Configure your database
config :game_bot, GameBot.Infrastructure.Repo,
  username: "postgres",
  password: "csstarahid",
  hostname: "localhost",
  database: "game_bot_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Configure EventStore for development
config :game_bot, GameBot.Infrastructure.EventStore,
  serializer: GameBot.Infrastructure.EventStore.Serializer,
  username: System.get_env("EVENT_STORE_USER", "postgres"),
  password: System.get_env("EVENT_STORE_PASS", "csstarahid"),
  database: System.get_env("EVENT_STORE_DB", "game_bot_eventstore_dev"),
  hostname: System.get_env("EVENT_STORE_HOST", "localhost"),
  schema_prefix: "game_events",
  column_data_type: "jsonb",
  types: EventStore.PostgresTypes,
  pool_size: 10

# Configure Commanded for development
config :game_bot, :commanded,
  event_store_adapter: Commanded.EventStore.Adapters.EventStore,
  event_store: GameBot.Infrastructure.EventStore.Config,
  pubsub: :local,
  registry: :local

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
# Binding to loopback ipv4 address prevents access from other machines.
config :game_bot, GameBotWeb.Endpoint,
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "T/gRw3ACX1gjNcXR7Ph8r+5wfRLp0bI+HwZyXQXyANgJLySVNfOilPsr2qKBb8EM",
  watchers: []

# ## SSL Support
#
# In order to use HTTPS in development, a self-signed
# certificate can be generated by running the following
# Mix task:
#
#     mix phx.gen.cert
#
# Run `mix help phx.gen.cert` for more information.
#
# The `http:` config above can be replaced with:
#
#     https: [
#       port: 4001,
#       cipher_suite: :strong,
#       keyfile: "priv/cert/selfsigned_key.pem",
#       certfile: "priv/cert/selfsigned.pem"
#     ],
#
# If desired, both `http:` and `https:` keys can be
# configured to run both http and https servers on
# different ports.

# Watch static and templates for browser reloading.
config :game_bot, GameBotWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/game_bot_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :game_bot, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include HEEx debug annotations as HTML comments in rendered markup
  debug_heex_annotations: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true
