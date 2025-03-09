defmodule GameBot.Test.Setup do
  @moduledoc """
  Central test setup module to ensure consistent database and repository initialization.
  """

  alias GameBot.Infrastructure.Persistence.Repo
  alias GameBot.Infrastructure.Persistence.Repo.Postgres
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres, as: EventStoreRepo
  alias GameBot.TestEventStore

  @max_retries 3
  @retry_delay 1000
  @db_operation_timeout 30_000

  @doc """
  One-time setup for the entire test run.
  This is called once at the beginning of the test run.
  """
  def initialize_test_environment do
    # Ensure we have all repositories properly defined
    all_repos = [
      Repo,
      EventStoreRepo,
      Postgres
    ]

    # Start applications required for tests in the correct order
    {:ok, _} = Application.ensure_all_started(:postgrex)
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Application.ensure_all_started(:eventstore)

    # Start the TestEventStore
    case TestEventStore.start_link() do
      {:ok, _pid} ->
        :ok
      {:error, {:already_started, _pid}} ->
        TestEventStore.reset!()
        :ok
      {:error, reason} ->
        IO.puts("Failed to start TestEventStore: #{inspect(reason)}")
        {:error, {:test_event_store_start_failed, reason}}
    end

    # Log database names - verify they're consistent
    main_db = Application.get_env(:game_bot, :test_databases)[:main_db]
    event_db = Application.get_env(:game_bot, :test_databases)[:event_db]
    IO.puts("\n=== TEST ENVIRONMENT ===")
    IO.puts("Databases: main=#{main_db}, event=#{event_db}")

    # Stop any existing repos and terminate connections
    cleanup_repositories(all_repos, main_db, event_db)

    # Ensure database schemas exist
    ensure_database_schemas_exist(main_db, event_db)

    # Start repositories in the correct order with proper initialization
    case start_repositories_in_order(all_repos) do
      :ok ->
        # Set sandbox mode only after all repos are confirmed running
        configure_sandbox_mode(all_repos)
        :ok
      {:error, reason} ->
        IO.puts("Failed to initialize test environment: #{inspect(reason)}")
        cleanup_repositories(all_repos, main_db, event_db)
        {:error, reason}
    end
  end

  defp cleanup_repositories(repos, main_db, event_db) do
    # First stop all repositories
    Enum.each(repos, &ensure_repo_stopped/1)

    # Then terminate all connections
    terminate_all_postgres_connections(main_db, event_db)

    # Wait a moment to ensure connections are fully closed
    Process.sleep(100)
  end

  defp start_repositories_in_order(repos) do
    # Start each repository in sequence, ensuring each is fully initialized
    # before moving to the next one
    Enum.reduce_while(repos, :ok, fn repo, _acc ->
      case start_repo_with_retry(repo) do
        :ok ->
          # Verify the repository is actually running and responding
          case verify_repository_health(repo) do
            :ok -> {:cont, :ok}
            {:error, reason} -> {:halt, {:error, {:unhealthy_repo, repo, reason}}}
          end
        {:error, reason} ->
          {:halt, {:error, {:start_failed, repo, reason}}}
      end
    end)
  end

  defp verify_repository_health(repo) do
    try do
      # Try a simple query to verify the repository is working
      repo.query!("SELECT 1", [], timeout: @db_operation_timeout)
      :ok
    rescue
      e -> {:error, e}
    end
  end

  defp configure_sandbox_mode(repos) do
    Enum.each(repos, fn repo ->
      if Process.whereis(repo) do
        :ok = Ecto.Adapters.SQL.Sandbox.mode(repo, :manual)
      end
    end)
  end

  defp ensure_database_schemas_exist(main_db, event_db) do
    # Create a connection to postgres database for administration
    {:ok, conn} = Postgrex.start_link(
      hostname: "localhost",
      username: "postgres",
      password: "csstarahid",
      database: "postgres",
      timeout: @db_operation_timeout,
      pool_timeout: @db_operation_timeout
    )

    # Create databases if they don't exist
    create_database_if_not_exists(conn, main_db)
    create_database_if_not_exists(conn, event_db)

    # Create event store schema and tables
    ensure_eventstore_tables_exist(event_db)

    # Close the connection
    GenServer.stop(conn)
  end

  defp create_database_if_not_exists(conn, db_name) do
    # Drop the database if it exists (fresh start)
    Postgrex.query!(conn, "DROP DATABASE IF EXISTS \"#{db_name}\"", [], timeout: @db_operation_timeout)

    # Create the database
    Postgrex.query!(conn, "CREATE DATABASE \"#{db_name}\"", [], timeout: @db_operation_timeout)
  end

  defp ensure_eventstore_tables_exist(event_db) do
    # Connect to the eventstore database
    {:ok, event_conn} = Postgrex.start_link(
      hostname: "localhost",
      username: "postgres",
      password: "csstarahid",
      database: event_db,
      timeout: @db_operation_timeout,
      pool_timeout: @db_operation_timeout
    )

    # Create event store schema
    Postgrex.query!(event_conn, "CREATE SCHEMA IF NOT EXISTS event_store", [], timeout: @db_operation_timeout)

    # Create event store tables
    create_event_store_schema(event_conn)

    GenServer.stop(event_conn)
  end

  defp create_event_store_schema(conn) do
    # Execute each CREATE TABLE statement separately
    statements = [
      """
      CREATE TABLE IF NOT EXISTS event_store.events (
        event_id BIGSERIAL PRIMARY KEY,
        stream_uuid TEXT NOT NULL,
        stream_version INT NOT NULL,
        event_type TEXT NOT NULL,
        correlation_id TEXT,
        causation_id TEXT,
        data JSONB NOT NULL,
        metadata JSONB,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
        CONSTRAINT events_stream_uuid_stream_version_uk UNIQUE (stream_uuid, stream_version)
      )
      """,
      """
      CREATE TABLE IF NOT EXISTS event_store.streams (
        stream_uuid TEXT NOT NULL PRIMARY KEY,
        stream_version INT NOT NULL,
        deleted_at TIMESTAMP WITH TIME ZONE
      )
      """,
      """
      CREATE TABLE IF NOT EXISTS event_store.subscriptions (
        subscription_name TEXT NOT NULL,
        last_seen_event_id BIGINT NOT NULL,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
        CONSTRAINT subscriptions_subscription_name_pk PRIMARY KEY (subscription_name)
      )
      """,
      """
      CREATE TABLE IF NOT EXISTS event_store.snapshots (
        source_uuid TEXT NOT NULL,
        source_version BIGINT NOT NULL,
        source_type TEXT NOT NULL,
        data JSONB NOT NULL,
        metadata JSONB,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
        CONSTRAINT snapshots_source_uuid_source_version_pk PRIMARY KEY (source_uuid, source_version)
      )
      """
    ]

    # Execute each statement individually
    Enum.each(statements, fn statement ->
      Postgrex.query!(conn, statement, [], timeout: @db_operation_timeout)
    end)
  end

  defp ensure_repo_stopped(repo) do
    case Process.whereis(repo) do
      nil -> :ok
      pid ->
        try do
          if Process.alive?(pid) do
            GenServer.stop(pid, :normal, 5000)
            Process.sleep(100)
          end
        rescue
          _ -> :ok
        end
    end
  end

  defp start_repo_with_retry(repo, retries \\ @max_retries)

  defp start_repo_with_retry(_repo, 0) do
    {:error, :max_retries_exceeded}
  end

  defp start_repo_with_retry(repo, retries) do
    case start_repo(repo) do
      :ok -> :ok
      {:error, _reason} ->
        Process.sleep(@retry_delay)
        start_repo_with_retry(repo, retries - 1)
    end
  end

  defp start_repo(repo) do
    config = Application.get_env(:game_bot, repo)

    if config == nil do
      {:error, :no_config}
    else
      # Add a unique name to each repo's config to prevent conflicts
      config = Keyword.put_new(config, :name, Module.concat(repo, Supervisor))

      try do
        case repo.start_link(config) do
          {:ok, _pid} ->
            Process.sleep(100) # Give repo time to initialize
            :ok
          {:error, {:already_started, _pid}} ->
            :ok
          {:error, error} ->
            {:error, error}
        end
      rescue
        e -> {:error, e}
      end
    end
  end

  defp terminate_all_postgres_connections(main_db, event_db) do
    # Connect to postgres database for administration
    {:ok, conn} = Postgrex.start_link(
      hostname: "localhost",
      username: "postgres",
      password: "csstarahid",
      database: "postgres",
      timeout: @db_operation_timeout,
      pool_timeout: @db_operation_timeout
    )

    # Terminate all connections to our test databases
    query = """
    SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE datname IN ($1, $2)
    AND pid <> pg_backend_pid()
    """

    case Postgrex.query(conn, query, [main_db, event_db], timeout: @db_operation_timeout) do
      {:ok, result} ->
        IO.puts("Terminated #{result.num_rows} database connections")
      {:error, error} ->
        IO.puts("Error terminating connections: #{inspect(error)}")
    end

    # Close the admin connection
    GenServer.stop(conn)
  end
end
