defmodule Mix.Tasks.GameBot.EventStoreSetup do
  @moduledoc """
  Mix task to set up the event store database specifically for testing.
  This ensures proper initialization of all required event store tables.

  ## Examples

      mix game_bot.event_store_setup
  """

  use Mix.Task

  @shortdoc "Sets up event store database for testing"

  @doc false
  def run(_args) do
    # Ensure we're in test environment
    Mix.env() == :test || Mix.raise("This task can only be run in the test environment")

    # Start required applications
    {:ok, _} = Application.ensure_all_started(:postgrex)

    # Get database config
    config = Application.get_env(:game_bot, GameBot.Infrastructure.Persistence.EventStore)

    # Connect to the event store database
    {:ok, conn} = Postgrex.start_link(
      hostname: config[:hostname],
      username: config[:username],
      password: config[:password],
      database: config[:database],
      port: config[:port] || 5432
    )

    Mix.shell().info("Setting up event store schema and tables...")

    # Create the schema
    schema = config[:schema] || "event_store"

    # Drop the schema and recreate it
    clean_database(conn, schema)

    # Create the schema
    {:ok, _} = Postgrex.query(conn, "CREATE SCHEMA IF NOT EXISTS #{schema};", [])

    # Create the streams table
    create_streams_table(conn, schema)

    # Create the events table
    create_events_table(conn, schema)

    # Create the subscriptions table
    create_subscriptions_table(conn, schema)

    # Stop the connection
    GenServer.stop(conn)

    Mix.shell().info("Event store setup complete!")
    :ok
  end

  defp clean_database(conn, schema) do
    # Drop the schema if it exists to ensure a clean slate
    Mix.shell().info("Cleaning up previous event store schema...")
    {:ok, _} = Postgrex.query(conn, "DROP SCHEMA IF EXISTS #{schema} CASCADE;", [])
  end

  defp create_streams_table(conn, schema) do
    query = """
    CREATE TABLE IF NOT EXISTS #{schema}.streams (
      id text PRIMARY KEY,
      version bigint NOT NULL DEFAULT 0
    );
    """

    {:ok, _} = Postgrex.query(conn, query, [])
  end

  defp create_events_table(conn, schema) do
    query = """
    CREATE TABLE IF NOT EXISTS #{schema}.events (
      event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      stream_id text NOT NULL REFERENCES #{schema}.streams(id) ON DELETE CASCADE,
      event_type text NOT NULL,
      event_data jsonb NOT NULL,
      event_metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
      event_version bigint NOT NULL,
      created_at timestamp with time zone NOT NULL DEFAULT now(),
      UNIQUE (stream_id, event_version)
    );
    """

    {:ok, _} = Postgrex.query(conn, query, [])
  end

  defp create_subscriptions_table(conn, schema) do
    query = """
    CREATE TABLE IF NOT EXISTS #{schema}.subscriptions (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      stream_id text NOT NULL REFERENCES #{schema}.streams(id) ON DELETE CASCADE,
      subscriber_pid text NOT NULL,
      options jsonb NOT NULL DEFAULT '{}'::jsonb,
      created_at timestamp with time zone NOT NULL DEFAULT now()
    );
    """

    {:ok, _} = Postgrex.query(conn, query, [])
  end
end
