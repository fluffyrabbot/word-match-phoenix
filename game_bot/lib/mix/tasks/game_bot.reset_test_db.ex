defmodule Mix.Tasks.GameBot.ResetTestDb do
  @shortdoc "Forcefully resets the test databases by terminating connections"
  @moduledoc """
  This task forcefully resets the test databases by:
  1. Terminating all connections to the test databases
  2. Dropping the test databases
  3. Creating the test databases
  4. Creating the event store schema

  Usage:
      mix game_bot.reset_test_db

  This is primarily intended for test scenarios where database connections
  might be stuck or in an inconsistent state that prevents normal cleanup.
  """

  use Mix.Task

  # Maximum number of retries for database operations
  @max_retries 5  # Increased from 3 to 5
  # Delay between retries in milliseconds
  @retry_delay 1000
  # Longer timeout for database operations (in milliseconds)
  @db_operation_timeout 30_000

  @doc false
  def run(_args) do
    # Disable paging to prevent interactive prompts
    System.put_env("PAGER", "cat")
    System.put_env("PGSTYLEPAGER", "cat")

    # Start necessary applications
    Application.ensure_all_started(:postgrex)
    Application.ensure_all_started(:ecto_sql)

    # Determine database names from mix config or generate new ones
    {main_db, event_db} = get_database_names()
    IO.puts("Working with databases: main=#{main_db}, event=#{event_db}")

    # Get repo config
    repo_config = Application.get_env(:game_bot, GameBot.Infrastructure.Persistence.Repo)
    _eventstore_config = Application.get_env(:game_bot, GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres)

    # Extract connection info without database name and with longer timeouts
    repo_conn_info = repo_config
                     |> Keyword.drop([:database, :pool, :pool_size, :name])
                     |> Keyword.put(:database, "postgres")
                     |> Keyword.put(:timeout, @db_operation_timeout)
                     |> Keyword.put(:connect_timeout, @db_operation_timeout)
                     |> Keyword.put(:ownership_timeout, @db_operation_timeout)

    # Try to stop any repositories that might be running
    try_stop_repo(GameBot.Infrastructure.Persistence.Repo)
    try_stop_repo(GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres)

    # Attempt to connect to the postgres database
    IO.puts("=== Starting test database reset procedure ===")

    case Postgrex.start_link(repo_conn_info) do
      {:ok, conn} ->
        process_databases(conn, main_db, event_db)

        # Clean up by closing the connection
        IO.puts("Closing connection...")
        try do
          close_connection(conn)
        rescue
          _ -> IO.puts("Error disconnecting, but this is expected after database operations")
        end

      {:error, error} ->
        IO.puts("CRITICAL ERROR: Failed to connect to Postgres: #{inspect(error)}")
        raise "Failed to connect to PostgreSQL server"
    end

    # Explicitly garbage collect to help release any lingering references
    :erlang.garbage_collect()

    # Finished
    IO.puts("=== Test databases reset completely ===")
  end

  # Get database names from config or generate new ones with timestamp
  defp get_database_names do
    # Check if timestamp is provided in environment
    env_timestamp = System.get_env("TEST_DB_TIMESTAMP")

    if env_timestamp && env_timestamp != "" do
      # Use the timestamp from environment
      main_db = "game_bot_test_#{env_timestamp}"
      event_db = "game_bot_eventstore_test_#{env_timestamp}"
      IO.puts("Using database names from environment: main=#{main_db}, event=#{event_db}")
      {main_db, event_db}
    else
      # Try to get names from config
      main_db_from_config = try do
        Application.get_env(:game_bot, :test_databases)[:main_db]
      rescue
        _ -> nil
      end

      event_db_from_config = try do
        Application.get_env(:game_bot, :test_databases)[:event_db]
      rescue
        _ -> nil
      end

      # Check if the values match the expected pattern
      main_db_valid = main_db_from_config && Regex.match?(~r/^game_bot_test_\d+$/, main_db_from_config)
      event_db_valid = event_db_from_config && Regex.match?(~r/^game_bot_eventstore_test_\d+$/, event_db_from_config)

      if main_db_valid && event_db_valid do
        {main_db_from_config, event_db_from_config}
      else
        # Generate new names with timestamp
        timestamp = :os.system_time(:seconds)
        partition = System.get_env("MIX_TEST_PARTITION") || ""
        suffix = "#{partition}#{timestamp}"

        {"game_bot_test_#{suffix}", "game_bot_eventstore_test_#{suffix}"}
      end
    end
  end

  # Safely close a connection without paging issues
  defp close_connection(conn) do
    try do
      # Ensure no in-progress query that might produce a pager
      Postgrex.query(conn, "SELECT 1", [], [mode: :savepoint])
      Postgrex.disconnect(conn)
    rescue
      _ -> IO.puts("Error during connection cleanup")
    end
  end

  # Try to stop a repository process
  defp try_stop_repo(repo) do
    case Process.whereis(repo) do
      nil -> IO.puts("Repository #{inspect(repo)} is not running")
      pid ->
        IO.puts("Stopping repository #{inspect(repo)} (pid: #{inspect(pid)})")
        try do
          repo.stop(pid)
          Process.sleep(100) # Give it time to stop
        rescue
          e -> IO.puts("Error stopping repo: #{inspect(e)}")
        end
    end
  end

  # Process both databases with comprehensive error handling
  defp process_databases(conn, main_db, event_db) do
    # Start with diagnostic info
    print_diagnostic_info(conn)

    # First kill all connections to both databases
    IO.puts("Terminating all database connections...")
    with_retry(fn -> terminate_all_connections(conn) end)

    # Then specifically target our test databases
    IO.puts("Terminating connections to test databases...")
    with_retry(fn -> kill_connections(conn, main_db) end)
    with_retry(fn -> kill_connections(conn, event_db) end)

    # Sleep briefly to allow connections to fully terminate
    IO.puts("Waiting for connections to terminate...")
    Process.sleep(1000)

    # Report any remaining connections
    check_remaining_connections(conn, main_db)
    check_remaining_connections(conn, event_db)

    # Drop databases with retries and force option
    IO.puts("Dropping databases...")
    with_retry(fn -> force_drop_database(conn, main_db) end)
    with_retry(fn -> force_drop_database(conn, event_db) end)

    # Create databases with retries
    IO.puts("Creating databases...")
    with_retry(fn -> create_database(conn, main_db) end)
    with_retry(fn -> create_database(conn, event_db) end)

    # Create event store schema with retries
    IO.puts("Creating event store schema...")
    with_retry(fn -> create_event_store_schema(conn, event_db) end)
  end

  # Print diagnostic information about the current PostgreSQL environment
  defp print_diagnostic_info(conn) do
    IO.puts("=== PostgreSQL Diagnostic Information ===")

    # Check PostgreSQL version
    version_query = "SELECT version();"
    case Postgrex.query(conn, version_query, [], timeout: @db_operation_timeout) do
      {:ok, %{rows: [[version]]}} ->
        # Limit output to avoid scrolling
        short_version = String.slice(version, 0, 60)
        short_version = if String.length(version) > 60, do: short_version <> "...", else: short_version
        IO.puts("PostgreSQL Version: #{short_version}")
      {:error, error} ->
        IO.puts("Error checking PostgreSQL version: #{inspect(error)}")
    end

    # Check current connections count
    conn_query = "SELECT count(*) FROM pg_stat_activity;"
    case Postgrex.query(conn, conn_query, [], timeout: @db_operation_timeout) do
      {:ok, %{rows: [[count]]}} ->
        IO.puts("Total active connections: #{count}")
      {:error, error} ->
        IO.puts("Error checking connection count: #{inspect(error)}")
    end

    # List all databases, but limit the output to avoid lots of text
    db_query = "SELECT datname FROM pg_database WHERE datistemplate = false LIMIT 10;"
    case Postgrex.query(conn, db_query, [], timeout: @db_operation_timeout) do
      {:ok, result} ->
        dbs = result.rows |> List.flatten() |> Enum.join(", ")
        IO.puts("Available databases (first 10): #{dbs}")
      {:error, error} ->
        IO.puts("Error listing databases: #{inspect(error)}")
    end

    IO.puts("=== End Diagnostic Information ===")
  end

  # Check and report any remaining connections to a database
  defp check_remaining_connections(conn, database) do
    query = """
    SELECT count(*)
    FROM pg_stat_activity
    WHERE datname = '#{database}'
    AND pid <> pg_backend_pid();
    """

    case Postgrex.query(conn, query, [], timeout: @db_operation_timeout) do
      {:ok, %{rows: [[count]]}} ->
        if count > 0 do
          IO.puts("WARNING: #{count} connections still active to #{database}")
          # Get details about these connections, but limit to 5 to avoid excessive output
          detail_query = """
          SELECT pid, application_name, usename, state
          FROM pg_stat_activity
          WHERE datname = '#{database}'
          AND pid <> pg_backend_pid()
          LIMIT 5;
          """
          case Postgrex.query(conn, detail_query, [], timeout: @db_operation_timeout) do
            {:ok, result} ->
              result.rows |> Enum.each(fn row ->
                IO.puts("  PID: #{Enum.at(row, 0)}, App: #{Enum.at(row, 1)}, User: #{Enum.at(row, 2)}, State: #{Enum.at(row, 3)}")
              end)
            _ -> nil
          end
        else
          IO.puts("No remaining connections to #{database}")
        end
      {:error, error} ->
        IO.puts("Error checking remaining connections to #{database}: #{inspect(error)}")
    end
  end

  @doc """
  Executes a function with retries on failure.
  """
  def with_retry(func, retries \\ @max_retries) do
    try do
      func.()
    rescue
      e ->
        if retries > 0 do
          IO.puts("Operation failed, retrying (#{retries} attempts left)... Error: #{inspect(e)}")
          Process.sleep(@retry_delay)
          with_retry(func, retries - 1)
        else
          IO.puts("Operation failed after all retry attempts: #{inspect(e)}")
          reraise e, __STACKTRACE__
        end
    end
  end

  @doc """
  Terminates all connections to non-postgres databases.
  """
  def terminate_all_connections(conn) do
    # Terminate all connections to any database except postgres
    terminate_query = """
    DO $$
    DECLARE
      db_connections RECORD;
    BEGIN
      FOR db_connections IN
        SELECT pid, datname FROM pg_stat_activity
        WHERE datname != 'postgres'
        AND pid <> pg_backend_pid()
      LOOP
        PERFORM pg_terminate_backend(db_connections.pid);
      END LOOP;
    END $$;
    """

    case Postgrex.query(conn, terminate_query, [], timeout: @db_operation_timeout) do
      {:ok, _} ->
        IO.puts("Executed global connection termination (all non-postgres databases)")
      {:error, error} ->
        IO.puts("Warning: Failed to terminate all connections: #{inspect(error)}")
        # This error is not fatal, we continue
    end
  end

  @doc """
  Terminates all connections to the specified database.
  Uses multiple approaches to ensure all connections are terminated.
  """
  def kill_connections(conn, database) do
    # First approach: standard pg_terminate_backend
    kill_query = """
    SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE datname = '#{database}'
    AND pid <> pg_backend_pid();
    """

    # Second approach: Use DO block for more aggressive termination
    kill_query_2 = """
    DO $$
    DECLARE
      db_connections RECORD;
    BEGIN
      FOR db_connections IN
        SELECT pid FROM pg_stat_activity WHERE datname = '#{database}' AND pid <> pg_backend_pid()
      LOOP
        PERFORM pg_terminate_backend(db_connections.pid);
      END LOOP;
    END $$;
    """

    # Execute both queries to maximize chance of terminating all connections
    case Postgrex.query(conn, kill_query, [], timeout: @db_operation_timeout) do
      {:ok, result} ->
        IO.puts("Terminated #{result.num_rows} connections to #{database} (first approach)")
      {:error, error} ->
        IO.puts("Warning: First approach failed to terminate connections to #{database}: #{inspect(error)}")
    end

    case Postgrex.query(conn, kill_query_2, [], timeout: @db_operation_timeout) do
      {:ok, _} ->
        IO.puts("Executed forceful connection termination to #{database} (second approach)")
      {:error, error} ->
        IO.puts("Warning: Second approach failed to terminate connections to #{database}: #{inspect(error)}")
    end
  end

  @doc """
  Attempts to forcefully drop a database with multiple attempts.
  """
  def force_drop_database(conn, database) do
    # First check if database exists
    exists_query = "SELECT 1 FROM pg_database WHERE datname = '#{database}'"

    exists = case Postgrex.query(conn, exists_query, [], timeout: @db_operation_timeout) do
      {:ok, %{rows: [[1]]}} -> true
      _ -> false
    end

    if exists do
      IO.puts("Forcefully dropping database #{database}...")

      # Force disconnect any lingering connections again before drop
      kill_connections(conn, database)

      # Sleep briefly to allow connections to fully terminate
      Process.sleep(500)

      # Try with FORCE option first (PostgreSQL 13+)
      drop_query_force = "DROP DATABASE IF EXISTS \"#{database}\" WITH (FORCE);"
      drop_query_regular = "DROP DATABASE IF EXISTS \"#{database}\";"

      # Try with FORCE option first
      case Postgrex.query(conn, drop_query_force, [], timeout: @db_operation_timeout) do
        {:ok, _} ->
          IO.puts("Successfully dropped #{database} with FORCE option")
          true
        {:error, force_error} ->
          IO.puts("FORCE option failed, trying regular drop: #{inspect(force_error)}")

          # Try regular drop
          case Postgrex.query(conn, drop_query_regular, [], timeout: @db_operation_timeout) do
            {:ok, _} ->
              IO.puts("Successfully dropped #{database} with regular drop")
              true
            {:error, regular_error} ->
              IO.puts("Warning: Failed to drop #{database}: #{inspect(regular_error)}")
              raise "Failed to drop database #{database} after multiple approaches: #{inspect(regular_error)}"
          end
      end
    else
      IO.puts("Database #{database} doesn't exist, skipping drop")
      true
    end
  end

  @doc """
  Creates the specified database.
  """
  def create_database(conn, database) do
    IO.puts("Creating database #{database}...")

    create_query = "CREATE DATABASE \"#{database}\" ENCODING 'UTF8'"

    case Postgrex.query(conn, create_query, [], timeout: @db_operation_timeout) do
      {:ok, _} ->
        IO.puts("Successfully created #{database}")
      {:error, error} ->
        IO.puts("Warning: Failed to create #{database}: #{inspect(error)}")
        raise "Failed to create database #{database}: #{inspect(error)}"
    end
  end

  @doc """
  Creates the event store schema and tables in the specified database.
  """
  def create_event_store_schema(conn, database) do
    IO.puts("Creating event store schema in #{database}...")

    # Connect to the event store database with longer timeouts
    conn_info = [
      hostname: connection_info(conn, :hostname, "localhost"),
      port: connection_info(conn, :port, 5432),
      username: connection_info(conn, :username, "postgres"),
      password: connection_info(conn, :password, "csstarahid"),
      database: database,
      timeout: @db_operation_timeout,
      connect_timeout: @db_operation_timeout,
      ownership_timeout: @db_operation_timeout
    ]

    with {:ok, es_conn} <- Postgrex.start_link(conn_info) do
      # Create schema
      schema_query = "CREATE SCHEMA IF NOT EXISTS event_store"
      schema_result = Postgrex.query(es_conn, schema_query, [], timeout: @db_operation_timeout)

      # Create tables individually to avoid syntax errors with multiple statements
      streams_query = """
      CREATE TABLE IF NOT EXISTS event_store.streams (
        stream_id text NOT NULL,
        stream_version bigint NOT NULL,
        CONSTRAINT streams_pkey PRIMARY KEY (stream_id)
      )
      """

      events_query = """
      CREATE TABLE IF NOT EXISTS event_store.events (
        stream_id text NOT NULL,
        stream_version bigint NOT NULL,
        event_id uuid NOT NULL,
        event_type text NOT NULL,
        event_data jsonb NOT NULL,
        metadata jsonb,
        created_at timestamp without time zone NOT NULL DEFAULT now(),
        CONSTRAINT events_pkey PRIMARY KEY (event_id),
        CONSTRAINT events_stream_id_fkey FOREIGN KEY (stream_id)
          REFERENCES event_store.streams (stream_id)
          ON DELETE CASCADE
      )
      """

      subscriptions_query = """
      CREATE TABLE IF NOT EXISTS event_store.subscriptions (
        subscription_id uuid NOT NULL,
        stream_id text NOT NULL,
        subscription_name text,
        last_seen_event_id uuid,
        last_seen_stream_version bigint DEFAULT 0,
        created_at timestamp without time zone NOT NULL DEFAULT now(),
        CONSTRAINT subscriptions_pkey PRIMARY KEY (subscription_id),
        CONSTRAINT subscriptions_stream_id_fkey FOREIGN KEY (stream_id)
          REFERENCES event_store.streams (stream_id)
          ON DELETE CASCADE
      )
      """

      # Execute each query separately with appropriate timeouts
      streams_result = Postgrex.query(es_conn, streams_query, [], timeout: @db_operation_timeout)
      events_result = Postgrex.query(es_conn, events_query, [], timeout: @db_operation_timeout)
      subscriptions_result = Postgrex.query(es_conn, subscriptions_query, [], timeout: @db_operation_timeout)

      # Clean up the connection
      try do
        close_connection(es_conn)
      rescue
        _ -> IO.puts("Error disconnecting from event store database (expected)")
      end

      # Check results
      case {schema_result, streams_result, events_result, subscriptions_result} do
        {{:ok, _}, {:ok, _}, {:ok, _}, {:ok, _}} ->
          IO.puts("Successfully created event store schema and tables in #{database}")
        _ ->
          IO.puts("Warning: Failed to create event store schema or tables")
          IO.puts("Schema result: #{inspect(schema_result)}")
          IO.puts("Streams table result: #{inspect(streams_result)}")
          IO.puts("Events table result: #{inspect(events_result)}")
          IO.puts("Subscriptions table result: #{inspect(subscriptions_result)}")
          raise "Failed to create event store schema or tables"
      end
    else
      {:error, error} ->
        IO.puts("Warning: Failed to connect to #{database}: #{inspect(error)}")
        raise "Failed to connect to #{database}: #{inspect(error)}"
    end
  end

  # Helper function to safely get connection info
  defp connection_info(conn, key, default) do
    case conn do
      %{} ->
        try do
          Map.get(conn, key, default)
        rescue
          _ -> default
        end
      _ -> default
    end
  end
end
