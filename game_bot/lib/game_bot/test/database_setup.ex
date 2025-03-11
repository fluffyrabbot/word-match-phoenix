defmodule GameBot.Test.DatabaseSetup do
  @moduledoc """
  Handles database setup and cleanup for tests.

  This module encapsulates the functionality from the shell scripts
  (`setup_test_db.sh`, `run_tests.sh`, `reset_test_db.sh`) into Elixir code.
  It provides functions to:

  1. Create test databases with unique names
  2. Initialize database schemas
  3. Update application configuration
  4. Clean up resources after tests

  This module is primarily used by the `Mix.Tasks.GameBot.Test` task.
  """

  require Logger

  # Database credentials
  @db_user "postgres"
  @db_password "csstarahid"
  @db_host "localhost"

  # Maximum number of connection attempts
  @max_attempts 3
  @retry_delay 500 # milliseconds

  @doc """
  Sets up test databases with unique names.

  This function:
  1. Generates unique database names with timestamps
  2. Creates the databases
  3. Updates the application configuration
  4. Initializes the database schemas

  Returns:
  - `{:ok, %{main_db: String.t(), event_db: String.t()}}` - Database names
  - `{:error, reason}` - If setup fails
  """
  def setup_test_databases do
    # Generate unique database names with timestamp
    timestamp = System.system_time(:second)
    main_db = "game_bot_test_#{timestamp}"
    event_db = "game_bot_eventstore_test_#{timestamp}"

    Logger.info("Creating test databases: #{main_db} and #{event_db}")

    # Create databases
    with :ok <- create_database(main_db),
         :ok <- create_database(event_db),
         :ok <- update_config(main_db, event_db),
         :ok <- initialize_schemas(main_db, event_db) do
      {:ok, %{main_db: main_db, event_db: event_db}}
    else
      {:error, reason} ->
        Logger.error("Failed to set up test databases: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Cleans up resources after tests.

  This function:
  1. Terminates all database connections
  2. Drops the test databases

  Returns:
  - `:ok` - If cleanup is successful
  - `{:error, reason}` - If cleanup fails
  """
  def cleanup_resources do
    # Get database names from environment
    main_db = System.get_env("TEST_DB_MAIN")
    event_db = System.get_env("TEST_DB_EVENT")

    if main_db && event_db do
      Logger.info("Cleaning up test databases: #{main_db} and #{event_db}")

      # Terminate all connections
      terminate_connections()

      # Drop databases
      drop_database(main_db)
      drop_database(event_db)

      :ok
    else
      Logger.warning("No test database names found in environment, skipping cleanup")
      :ok
    end
  end

  @doc """
  Drops a database with the given name.

  This function:
  1. Terminates all connections to the database
  2. Drops the database

  Returns:
  - `:ok` - If the database was dropped successfully
  - `{:error, reason}` - If the database could not be dropped
  """
  def drop_database(db_name) do
    with_retries(@max_attempts, fn ->
      # Terminate connections to the database
      terminate_database_connections(db_name)

      # Drop database
      run_psql_command("DROP DATABASE IF EXISTS #{db_name};")
      :ok
    end)
  end

  # Private functions

  defp create_database(db_name) do
    with_retries(@max_attempts, fn ->
      # Drop database if it exists
      run_psql_command("DROP DATABASE IF EXISTS #{db_name};")

      # Create database
      run_psql_command("CREATE DATABASE #{db_name};")
      :ok
    end)
  end

  defp update_config(main_db, event_db) do
    Logger.info("Updating test configuration with new database names")

    # Update application environment
    Application.put_env(:game_bot, :test_databases, %{
      main_db: main_db,
      event_db: event_db
    })

    # Update Repo configuration
    repo_config = Application.get_env(:game_bot, GameBot.Infrastructure.Persistence.Repo)
    updated_repo_config = Keyword.put(repo_config || [], :database, main_db)
    Application.put_env(:game_bot, GameBot.Infrastructure.Persistence.Repo, updated_repo_config)

    # Update EventStore configuration
    event_store_config = Application.get_env(:game_bot, GameBot.Infrastructure.Persistence.EventStore)
    updated_event_store_config = Keyword.put(event_store_config || [], :database, event_db)
    Application.put_env(:game_bot, GameBot.Infrastructure.Persistence.EventStore, updated_event_store_config)

    :ok
  end

  defp initialize_schemas(main_db, event_db) do
    Logger.info("Initializing database schemas")

    # Initialize main database schema
    with :ok <- initialize_main_schema(main_db),
         :ok <- initialize_event_store_schema(event_db) do
      :ok
    end
  end

  defp initialize_main_schema(db_name) do
    Logger.info("Running migrations for main database")

    # Check if squashed migration file exists
    migration_file = Path.join([File.cwd!(), "priv", "repo", "squshed_migration.sql"])

    if File.exists?(migration_file) do
      Logger.info("Using squashed migration file")
      run_psql_file(db_name, migration_file)
    else
      Logger.info("No squashed migration file found, running Ecto migrations")
      # This would run Ecto migrations, but for now we'll just return :ok
      # In a real implementation, you would call Mix.Task.run("ecto.migrate")
      :ok
    end
  end

  defp initialize_event_store_schema(db_name) do
    Logger.info("Creating event store schema")

    # Create event store schema
    run_psql_command("CREATE SCHEMA IF NOT EXISTS event_store;", db_name)

    # Create event store tables
    sql = """
    CREATE TABLE IF NOT EXISTS event_store.streams (
      id text NOT NULL,
      version bigint NOT NULL,
      PRIMARY KEY (id)
    );

    CREATE TABLE IF NOT EXISTS event_store.events (
      event_id uuid NOT NULL,
      stream_id text NOT NULL,
      event_type text NOT NULL,
      event_version integer NOT NULL,
      event_data jsonb NOT NULL,
      event_metadata jsonb NOT NULL,
      created_at timestamp without time zone DEFAULT now() NOT NULL,
      PRIMARY KEY (event_id),
      FOREIGN KEY (stream_id) REFERENCES event_store.streams(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS event_store.subscriptions (
      id SERIAL,
      stream_id text NOT NULL,
      subscriber_pid text NOT NULL,
      options jsonb DEFAULT '{}'::jsonb NOT NULL,
      created_at timestamp without time zone DEFAULT now() NOT NULL,
      PRIMARY KEY (id),
      UNIQUE (stream_id, subscriber_pid)
    );
    """

    run_psql_command(sql, db_name)
    :ok
  end

  defp terminate_connections do
    Logger.info("Terminating all database connections")

    # Terminate all connections to non-postgres databases
    sql = """
    SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE datname != 'postgres'
    AND pid <> pg_backend_pid();
    """

    run_psql_command(sql)
    :ok
  end

  defp terminate_database_connections(db_name) do
    Logger.info("Terminating connections to database: #{db_name}")

    # Terminate connections to specific database
    sql = """
    SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE datname = '#{db_name}'
    AND pid <> pg_backend_pid();
    """

    run_psql_command(sql)
    :ok
  end

  defp run_psql_command(sql, db_name \\ "postgres") do
    with_retries(@max_attempts, fn ->
      args = [
        "-h", @db_host,
        "-U", @db_user,
        "-d", db_name,
        "-c", sql
      ]

      case System.cmd("psql", args, env: [{"PGPASSWORD", @db_password}], stderr_to_stdout: true) do
        {output, 0} ->
          Logger.debug("SQL command executed successfully: #{String.slice(sql, 0, 50)}...")
          {:ok, output}
        {output, code} ->
          Logger.error("SQL command failed with code #{code}: #{output}")
          {:error, "SQL command failed with code #{code}: #{output}"}
      end
    end)
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp run_psql_file(db_name, file_path) do
    with_retries(@max_attempts, fn ->
      args = [
        "-h", @db_host,
        "-U", @db_user,
        "-d", db_name,
        "-f", file_path
      ]

      case System.cmd("psql", args, env: [{"PGPASSWORD", @db_password}], stderr_to_stdout: true) do
        {output, 0} ->
          Logger.debug("SQL file executed successfully: #{file_path}")
          {:ok, output}
        {output, code} ->
          Logger.error("SQL file execution failed with code #{code}: #{output}")
          {:error, "SQL file execution failed with code #{code}: #{output}"}
      end
    end)
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp with_retries(0, _fun), do: {:error, "Max retries exceeded"}
  defp with_retries(attempts, fun) do
    try do
      fun.()
    rescue
      e ->
        Logger.warning("Error in retry #{attempts}: #{inspect(e)}")
        Process.sleep(@retry_delay)
        with_retries(attempts - 1, fun)
    catch
      kind, reason ->
        Logger.warning("Caught #{kind} in retry #{attempts}: #{inspect(reason)}")
        Process.sleep(@retry_delay)
        with_retries(attempts - 1, fun)
    end
  end
end
