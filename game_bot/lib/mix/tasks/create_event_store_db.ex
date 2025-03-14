defmodule Mix.Tasks.GameBot.CreateEventStoreDb do
  @moduledoc """
  Mix task to create the event store database.

  This task creates the eventstore database and initializes its schema
  for development and testing purposes.

  ## Usage

  ```
  # Create the development event store database
  mix game_bot.create_event_store_db

  # Create the test event store database
  mix game_bot.create_event_store_db --env=test
  ```
  """

  use Mix.Task
  import Mix.Ecto, only: [parse_repo: 1]

  @shortdoc "Creates the event store database"

  def run(args) do
    # Parse command line arguments
    {opts, _, _} = OptionParser.parse(args,
      switches: [env: :string],
      aliases: [e: :env]
    )

    # Determine environment
    env = opts[:env] || "dev"
    Application.put_env(:game_bot, :env, env)

    # Start required applications
    {:ok, _} = Application.ensure_all_started(:postgrex)
    {:ok, _} = Application.ensure_all_started(:ecto)

    # Load configurations for the specified environment
    db_config = get_db_config(env)

    IO.puts("Creating event store database: #{db_config[:database]}")

    # Create database
    create_database(db_config)

    IO.puts("Database created successfully!")

    # Create event store schema
    create_event_store_schema(db_config)

    IO.puts("Event store schema created successfully!")
  end

  defp get_db_config("dev") do
    Application.get_env(:game_bot, GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres)
  end

  defp get_db_config("test") do
    # For test, use the test database name
    config = Application.get_env(:game_bot, GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres)
    Keyword.put(config, :database, "game_bot_eventstore_test")
  end

  defp create_database(config) do
    # Connect to postgres database
    connection_info = config
      |> Keyword.drop([:database, :pool, :pool_size])
      |> Keyword.put(:database, "postgres")

    case Postgrex.start_link(connection_info) do
      {:ok, conn} ->
        database = config[:database]
        case Postgrex.query(conn, "CREATE DATABASE #{database}", [], []) do
          {:ok, _} ->
            IO.puts("Database '#{database}' created successfully")
          {:error, %{postgres: %{code: :duplicate_database}}} ->
            IO.puts("Database '#{database}' already exists")
          {:error, error} ->
            IO.puts("Error creating database: #{inspect(error)}")
            raise "Failed to create database #{database}"
        end

        # Use Process.exit instead of Postgrex.stop since stop is not available
        Process.exit(conn, :normal)
        Process.sleep(100)  # Allow time for process to terminate
        :ok

      {:error, error} ->
        IO.puts("Error connecting to PostgreSQL: #{inspect(error)}")
        raise "Failed to connect to PostgreSQL"
    end
  end

  defp create_event_store_schema(config) do
    # Connect to the created event store database
    case Postgrex.start_link(config) do
      {:ok, conn} ->
        # Create schema
        schema = config[:schema_prefix] || "event_store"

        # Create schema if it doesn't exist
        create_schema_query = "CREATE SCHEMA IF NOT EXISTS #{schema};"
        case Postgrex.query(conn, create_schema_query, [], []) do
          {:ok, _} ->
            IO.puts("Schema '#{schema}' created or already exists")
          {:error, error} ->
            IO.puts("Error creating schema: #{inspect(error)}")
            raise "Failed to create schema #{schema}"
        end

        # Create events table
        create_events_table_query = """
        CREATE TABLE IF NOT EXISTS #{schema}.events (
          id BIGSERIAL PRIMARY KEY,
          stream_id text NOT NULL,
          stream_version bigint NOT NULL,
          event_id uuid NOT NULL,
          event_type text NOT NULL,
          data jsonb NOT NULL,
          metadata jsonb,
          created_at timestamp without time zone DEFAULT now() NOT NULL,

          CONSTRAINT events_stream_id_stream_version_unique UNIQUE(stream_id, stream_version)
        );
        """

        case Postgrex.query(conn, create_events_table_query, [], []) do
          {:ok, _} ->
            IO.puts("Events table created or already exists")
          {:error, error} ->
            IO.puts("Error creating events table: #{inspect(error)}")
            raise "Failed to create events table"
        end

        # Create snapshots table
        create_snapshots_table_query = """
        CREATE TABLE IF NOT EXISTS #{schema}.snapshots (
          id BIGSERIAL PRIMARY KEY,
          stream_id text NOT NULL,
          stream_version bigint NOT NULL,
          snapshot_type text NOT NULL,
          data jsonb NOT NULL,
          metadata jsonb,
          created_at timestamp without time zone DEFAULT now() NOT NULL,

          CONSTRAINT snapshots_stream_id_unique UNIQUE(stream_id)
        );
        """

        case Postgrex.query(conn, create_snapshots_table_query, [], []) do
          {:ok, _} ->
            IO.puts("Snapshots table created or already exists")
          {:error, error} ->
            IO.puts("Error creating snapshots table: #{inspect(error)}")
            raise "Failed to create snapshots table"
        end

        # Create subscriptions table
        create_subscriptions_table_query = """
        CREATE TABLE IF NOT EXISTS #{schema}.subscriptions (
          id BIGSERIAL PRIMARY KEY,
          subscription_name text NOT NULL,
          last_seen_event_id bigint DEFAULT 0 NOT NULL,
          created_at timestamp without time zone DEFAULT now() NOT NULL,

          CONSTRAINT subscriptions_subscription_name_unique UNIQUE(subscription_name)
        );
        """

        case Postgrex.query(conn, create_subscriptions_table_query, [], []) do
          {:ok, _} ->
            IO.puts("Subscriptions table created or already exists")
          {:error, error} ->
            IO.puts("Error creating subscriptions table: #{inspect(error)}")
            raise "Failed to create subscriptions table"
        end

        # Use Process.exit instead of Postgrex.stop since stop is not available
        Process.exit(conn, :normal)
        Process.sleep(100)  # Allow time for process to terminate
        :ok

      {:error, error} ->
        IO.puts("Error connecting to event store database: #{inspect(error)}")
        raise "Failed to connect to event store database"
    end
  end
end
