# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.

# Start ExUnit
ExUnit.start()

# Configure the application for testing
Application.put_env(:game_bot, :start_word_service, false)
Application.put_env(:game_bot, :start_nostrum, false)
Application.put_env(:nostrum, :token, "mock_token")
Application.put_env(:nostrum, :api_module, GameBot.Test.Mocks.NostrumApiMock)

# Only start the application if explicitly requested or not in isolated test mode
if System.get_env("ISOLATED_TEST") != "true" do
  # Get repository references
  alias GameBot.Infrastructure.Persistence.Repo
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres

  # Start required applications in the correct order
  {:ok, _} = Application.ensure_all_started(:postgrex)
  {:ok, _} = Application.ensure_all_started(:ecto_sql)

  # Actually start the repos explicitly before trying to use them
  {:ok, _} = Repo.start_link([])
  {:ok, _} = Postgres.start_link([])

  # Configure sandbox mode for testing
  Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)
  Ecto.Adapters.SQL.Sandbox.mode(Postgres, :manual)

  # Create event store schema and tables
  event_store_schema = """
  CREATE SCHEMA IF NOT EXISTS event_store;

  CREATE TABLE IF NOT EXISTS event_store.streams (
    id text PRIMARY KEY,
    version bigint NOT NULL DEFAULT 0
  );

  CREATE TABLE IF NOT EXISTS event_store.events (
    event_id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    stream_id text NOT NULL REFERENCES event_store.streams(id) ON DELETE CASCADE,
    event_type text NOT NULL,
    event_data jsonb NOT NULL,
    event_metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    event_version bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    UNIQUE(stream_id, event_version)
  );

  CREATE TABLE IF NOT EXISTS event_store.subscriptions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    stream_id text NOT NULL REFERENCES event_store.streams(id) ON DELETE CASCADE,
    subscriber_pid text NOT NULL,
    options jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
  );
  """

  # Execute schema creation
  Repo.query!(event_store_schema)

  # Start the rest of the application
  {:ok, _} = Application.ensure_all_started(:game_bot)
end
