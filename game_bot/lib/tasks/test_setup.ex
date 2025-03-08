defmodule Mix.Tasks.GameBot.TestSetup do
  @moduledoc """
  Task for setting up the test environment.

  This will:
  1. Create the test databases if they don't exist
  2. Create the event_store schema in the eventstore DB
  3. Create the tables needed for the event store
  4. Configure sandbox mode for testing
  """

  use Mix.Task
  require Logger
  import Mix.Ecto

  @shortdoc "Sets up databases and tables for testing"
  def run(_args) do
    # Start dependencies
    Mix.Task.run("app.config")
    Application.ensure_all_started(:postgrex)
    Application.ensure_all_started(:ecto_sql)

    # Configure the repositories
    repos = Application.get_env(:game_bot, :ecto_repos, [])
    eventstore_repo = GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres

    # Make sure we include the event store repo if it's not in the list
    repos = Enum.uniq(repos ++ [eventstore_repo])

    # Ensure databases exist
    Enum.each(repos, fn repo ->
      ensure_repo(repo, [])
      ensure_database_created(repo)
    end)

    # Create schema for event store
    create_event_store_schema(eventstore_repo)

    # Create event store tables
    create_event_store_tables(eventstore_repo)

    # Configure for sandbox testing
    configure_sandbox_mode(repos)

    Mix.shell().info("Test setup complete.")
  end

  defp ensure_database_created(repo) do
    config = repo.config()
    database = Keyword.get(config, :database)

    if database do
      case check_database_exists(database) do
        {:ok, true} ->
          Mix.shell().info("Database #{database} already exists")
        {:ok, false} ->
          Mix.shell().info("Creating database #{database}")
          create_database(database)
        {:error, error} ->
          Mix.raise("Error checking database existence: #{inspect(error)}")
      end
    else
      Mix.shell().info("Skipping database creation as no database name was provided")
    end
  end

  defp check_database_exists(database) do
    # Connect to default postgres database
    config = [
      hostname: "localhost",
      username: "postgres",
      password: "csstarahid",
      database: "postgres"
    ]

    {:ok, conn} = Postgrex.start_link(config)

    try do
      # Check if database exists
      query = "SELECT 1 FROM pg_database WHERE datname = $1"
      case Postgrex.query(conn, query, [database]) do
        {:ok, %{rows: [[1]]}} -> {:ok, true}
        {:ok, %{rows: []}} -> {:ok, false}
        {:error, error} -> {:error, error}
      end
    after
      GenServer.stop(conn)
    end
  end

  defp create_database(database) do
    # Connect to default postgres database
    config = [
      hostname: "localhost",
      username: "postgres",
      password: "csstarahid",
      database: "postgres"
    ]

    {:ok, conn} = Postgrex.start_link(config)

    try do
      command = ~s(CREATE DATABASE "#{database}" ENCODING 'UTF8')
      case Postgrex.query(conn, command, []) do
        {:ok, _} ->
          Mix.shell().info("Database #{database} created successfully")
          :ok
        {:error, error} ->
          Mix.raise("Failed to create database: #{inspect(error)}")
      end
    after
      GenServer.stop(conn)
    end
  end

  defp create_event_store_schema(repo) do
    database = repo.config()[:database]

    if database do
      # Connect to the event store database
      config = [
        hostname: "localhost",
        username: "postgres",
        password: "csstarahid",
        database: database
      ]

      {:ok, conn} = Postgrex.start_link(config)

      try do
        command = "CREATE SCHEMA IF NOT EXISTS event_store"
        case Postgrex.query(conn, command, []) do
          {:ok, _} ->
            Mix.shell().info("Event store schema created successfully")
            :ok
          {:error, error} ->
            Mix.shell().info("Error creating event store schema: #{inspect(error)}")
            {:error, error}
        end
      after
        GenServer.stop(conn)
      end
    else
      Mix.shell().info("Skipping schema creation as no database name was provided")
      :ok
    end
  end

  defp create_event_store_tables(repo) do
    database = repo.config()[:database]

    if database do
      # Connect to the event store database
      config = [
        hostname: "localhost",
        username: "postgres",
        password: "csstarahid",
        database: database
      ]

      {:ok, conn} = Postgrex.start_link(config)

      tables = [
        # Create streams table
        """
        CREATE TABLE IF NOT EXISTS event_store.streams (
          id text NOT NULL,
          version bigint NOT NULL DEFAULT 0,
          CONSTRAINT streams_pkey PRIMARY KEY (id)
        )
        """,

        # Create events table
        """
        CREATE TABLE IF NOT EXISTS event_store.events (
          event_id bigserial NOT NULL,
          stream_id text NOT NULL,
          event_type text NOT NULL,
          event_data jsonb NOT NULL,
          event_metadata jsonb,
          event_version bigint NOT NULL,
          created_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'),
          CONSTRAINT events_pkey PRIMARY KEY (event_id),
          CONSTRAINT events_stream_id_fkey FOREIGN KEY (stream_id)
            REFERENCES event_store.streams(id) ON DELETE CASCADE
        )
        """,

        # Create subscriptions table
        """
        CREATE TABLE IF NOT EXISTS event_store.subscriptions (
          id bigserial NOT NULL,
          stream_id text NOT NULL,
          subscriber_pid text NOT NULL,
          options jsonb,
          CONSTRAINT subscriptions_pkey PRIMARY KEY (id),
          CONSTRAINT subscriptions_stream_id_fkey FOREIGN KEY (stream_id)
            REFERENCES event_store.streams(id) ON DELETE CASCADE
        )
        """
      ]

      try do
        Enum.each(tables, fn command ->
          case Postgrex.query(conn, command, []) do
            {:ok, _} -> Mix.shell().info("Created table successfully")
            {:error, error} -> Mix.shell().info("Error creating table: #{inspect(error)}")
          end
        end)
      after
        GenServer.stop(conn)
      end
    else
      Mix.shell().info("Skipping table creation as no database name was provided")
    end
  end

  defp configure_sandbox_mode(repos) do
    Enum.each(repos, fn repo ->
      Mix.shell().info("Configuring sandbox mode for #{inspect(repo)}")

      # Make sure the repo is using the sandbox pool
      config = repo.config()
      sandbox_config = Keyword.put(config, :pool, Ecto.Adapters.SQL.Sandbox)

      # Update application environment
      app_env_key = repo |> Module.split() |> List.first() |> String.to_atom()
      Application.put_env(app_env_key, repo, sandbox_config)
    end)
  end
end
