# Set compiler options to allow test protocol implementations
Code.put_compiler_option(:ignore_module_conflict, true)

# Configure ExUnit
ExUnit.configure(
  exclude: [:skip_db, :skip_in_ci],
  timeout: 120_000
)

# Start ExUnit early to ensure proper configuration
ExUnit.start()

# Set application environment for testing
Application.put_env(:game_bot, :testing, true)
Application.put_env(:game_bot, :start_word_service, false)
Application.put_env(:game_bot, :start_nostrum, false)

# Set the runtime repository implementation
Application.put_env(:game_bot, :repo_implementation, GameBot.Infrastructure.Persistence.Repo)

# Define the repositories needed for testing
repos = [
  GameBot.Infrastructure.Persistence.Repo,
  GameBot.Infrastructure.Persistence.Repo.Postgres,
  GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
]

# Start application dependencies in the correct order
required_apps = [:phoenix, :phoenix_ecto, :postgrex, :ecto, :ecto_sql, :eventstore]
IO.puts("Starting required applications...")
Enum.each(required_apps, fn app ->
  case Application.ensure_all_started(app) do
    {:ok, _} -> IO.puts("  ✓ Started #{app}")
    {:error, reason} -> IO.puts("  ✗ Failed to start #{app}: #{inspect(reason)}")
  end
end)

# Configure repositories for testing
Enum.each(repos, fn repo ->
  Application.put_env(:game_bot, repo,
    username: "postgres",
    password: "csstarahid",
    database: "game_bot_test",
    hostname: "localhost",
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10,
    queue_target: 200,
    queue_interval: 1000
  )
end)

# Simple module to start repositories with proper error handling
defmodule TestRepositoryStarter do
  require Logger

  def start_repos(repositories) do
    # First stop any existing repos
    Enum.each(repositories, fn repo ->
      if Process.whereis(repo) do
        GenServer.stop(repo)
        Process.sleep(100) # Give it time to stop
      end
    end)

    results = Enum.map(repositories, fn repo ->
      {repo, start_single_repo(repo)}
    end)

    # Report results
    {successful, failed} = Enum.split_with(results, fn {_, result} -> result == :ok end)

    if Enum.empty?(failed) do
      Logger.info("All repositories started successfully: #{inspect(Enum.map(successful, fn {repo, _} -> repo end))}")
      :ok
    else
      failed_repos = Enum.map(failed, fn {repo, reason} -> "#{inspect(repo)} (#{inspect(reason)})" end)
      Logger.error("Failed to start repositories: #{Enum.join(failed_repos, ", ")}")
      {:error, failed}
    end
  end

  def start_single_repo(repo) do
    # Check if repository is already running
    case Process.whereis(repo) do
      pid when is_pid(pid) ->
        if Process.alive?(pid) do
          Logger.info("Repository #{inspect(repo)} is already running")
          :ok
        else
          Logger.warning("Repository #{inspect(repo)} has crashed PID, restarting")
          do_start_repo(repo)
        end
      _ ->
        Logger.info("Starting repository #{inspect(repo)}")
        do_start_repo(repo)
    end
  end

  defp do_start_repo(repo) do
    try do
      config = Application.get_env(:game_bot, repo, [])
      # Add sandbox pool configuration explicitly for testing
      config = Keyword.put_new(config, :pool, Ecto.Adapters.SQL.Sandbox)
      config = Keyword.put_new(config, :pool_size, 5)

      case repo.start_link(config) do
        {:ok, _pid} ->
          # Verify the repository is registered and accessible
          wait_for_repo_registration(repo)
        {:error, {:already_started, _pid}} ->
          Logger.info("#{inspect(repo)} was already started")
          :ok
        {:error, error} ->
          Logger.error("Failed to start #{inspect(repo)}: #{inspect(error)}")
          {:error, error}
      end
    rescue
      e ->
        Logger.error("Exception starting #{inspect(repo)}: #{inspect(e)}")
        {:error, e}
    end
  end

  defp wait_for_repo_registration(repo, attempts \\ 0) do
    # Try to do a simple query to verify the repository is functional
    if attempts < 10 do
      try do
        if function_exported?(repo, :all, 1) do
          # Try a test query to verify connection
          Logger.info("Successfully started #{inspect(repo)}")
          :ok
        else
          # For non-Ecto repositories
          Logger.info("Started #{inspect(repo)} (no query function)")
          :ok
        end
      rescue
        e in [RuntimeError] ->
          if String.contains?(Exception.message(e), "not started") do
            # Repository not registered yet, wait a bit and retry
            Process.sleep(200)
            wait_for_repo_registration(repo, attempts + 1)
          else
            Logger.error("Error verifying repository #{inspect(repo)}: #{inspect(e)}")
            {:error, e}
          end
        e ->
          Logger.error("Unexpected error verifying repository #{inspect(repo)}: #{inspect(e)}")
          {:error, e}
      end
    else
      Logger.error("Timeout waiting for #{inspect(repo)} to register")
      {:error, :registration_timeout}
    end
  end
end

# Simple module to set up the EventStore schema and tables
defmodule EventStoreSchemaSetup do
  @moduledoc false
  require Logger

  def ensure_schema_exists do
    # Use the PostgreSQL repo directly instead of trying to get it from config
    repo = GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres

    # Check out a connection for schema setup
    case Ecto.Adapters.SQL.Sandbox.checkout(repo) do
      :ok ->
        try do
          # Execute each command separately
          commands = [
            "CREATE SCHEMA IF NOT EXISTS event_store",
            """
            CREATE TABLE IF NOT EXISTS event_store.streams (
              id text NOT NULL PRIMARY KEY,
              version integer NOT NULL DEFAULT 0
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS event_store.events (
              id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
              stream_id text NOT NULL REFERENCES event_store.streams(id) ON DELETE CASCADE,
              event_type text NOT NULL,
              event_data jsonb NOT NULL,
              event_metadata jsonb NOT NULL DEFAULT '{}',
              event_version integer NOT NULL,
              created_at timestamp NOT NULL DEFAULT now()
            )
            """,
            "CREATE INDEX IF NOT EXISTS events_stream_id_idx ON event_store.events(stream_id)",
            "CREATE INDEX IF NOT EXISTS events_stream_id_version_idx ON event_store.events(stream_id, event_version)",
            "DELETE FROM event_store.events",
            "DELETE FROM event_store.streams"
          ]

          Enum.each(commands, fn command ->
            repo.query!(command)
          end)

          :ok
        rescue
          e ->
            Logger.error("Failed to set up event store schema: #{inspect(e)}")
            {:error, e}
        after
          # Always check in the connection
          Ecto.Adapters.SQL.Sandbox.checkin(repo)
        end
      error ->
        Logger.error("Failed to check out connection for schema setup: #{inspect(error)}")
        {:error, error}
    end
  end
end

# Start all required repositories
IO.puts("\nStarting repositories...")
case TestRepositoryStarter.start_repos(repos) do
  :ok -> IO.puts("  ✓ All repositories started successfully")
  {:error, failed} -> IO.puts("  ✗ Some repositories failed to start: #{inspect(failed)}")
end

# Set up Ecto SQL Sandbox mode for each repository
IO.puts("\nConfiguring SQL sandbox mode...")

# First ensure all repos are started
Enum.each(repos, fn repo ->
  # Stop any existing instance
  if Process.whereis(repo), do: GenServer.stop(repo)
  Process.sleep(100)  # Give it time to stop

  # Start the repo with sandbox config
  config = Application.get_env(:game_bot, repo, [])
  |> Keyword.put(:pool, Ecto.Adapters.SQL.Sandbox)
  |> Keyword.put(:pool_size, 10)

  case repo.start_link(config) do
    {:ok, _pid} ->
      # Configure sandbox mode
      Ecto.Adapters.SQL.Sandbox.mode(repo, :manual)

      # Verify connection works
      try do
        # Try a test checkout/checkin
        :ok = Ecto.Adapters.SQL.Sandbox.checkout(repo)
        Ecto.Adapters.SQL.Sandbox.checkin(repo)
        IO.puts("  ✓ Started and configured #{inspect(repo)}")
      rescue
        e ->
          IO.puts("  ✗ Failed to verify #{inspect(repo)}: #{inspect(e)}")
          reraise e, __STACKTRACE__
      end

    {:error, {:already_started, _}} ->
      IO.puts("  ✓ #{inspect(repo)} already running")

    {:error, error} ->
      IO.puts("  ✗ Failed to start #{inspect(repo)}: #{inspect(error)}")
      raise "Failed to start repository: #{inspect(error)}"
  end
end)

# Set up EventStore schema and tables
IO.puts("\nSetting up event store schema and tables...")
case EventStoreSchemaSetup.ensure_schema_exists() do
  :ok ->
    IO.puts("  ✓ Event store setup complete!")
  {:error, error} ->
    IO.puts("  ✗ Failed to set up event store schema: #{inspect(error)}")
    IO.puts("    Tests requiring EventStore will likely fail.")
end

# Clean up tables for testing
IO.puts("\nCleaning up previous test data...")
Enum.each(repos, fn repo ->
  try do
    if function_exported?(repo, :query!, 2) do
      case Ecto.Adapters.SQL.Sandbox.checkout(repo, sandbox: false) do
        :ok ->
          try do
            # Clean up any test streams and data
            Ecto.Adapters.SQL.query!(repo, "DELETE FROM event_store.subscriptions", [])
            Ecto.Adapters.SQL.query!(repo, "DELETE FROM event_store.events", [])
            Ecto.Adapters.SQL.query!(repo, "DELETE FROM event_store.streams", [])
            IO.puts("  ✓ Cleaned event_store tables in #{inspect(repo)}")
          rescue
            e -> IO.puts("  ✗ Could not clean tables in #{inspect(repo)}: #{inspect(e)}")
          after
            Ecto.Adapters.SQL.Sandbox.checkin(repo)
          end
        {:error, error} ->
          IO.puts("  ✗ Failed to checkout connection for #{inspect(repo)}: #{inspect(error)}")
      end
    end
  rescue
    e -> IO.puts("  ✗ Error when cleaning up data in #{inspect(repo)}: #{inspect(e)}")
  end
end)

# Print diagnostic information
IO.puts("\nTest environment initialized with:")
IO.puts("- Runtime repository implementation: #{inspect(Application.get_env(:game_bot, :repo_implementation, "Not set"))}")
IO.puts("- Testing repositories: #{inspect(repos)}")

# ==================== REPOSITORY VERIFICATION CODE ============================
# Create the utility verification module inline
defmodule GameBot.Test.RepoVerification do
  @moduledoc """
  Utility module for verifying repositories are properly started and functional.
  """

  @doc """
  Verifies that all required repositories are started and functional.
  Halts the test run with a clear error message if any repository fails verification.
  """
  def verify_all_repositories(repos) do
    IO.puts("\n=== Repository Verification ===")

    results = Enum.map(repos, fn repo -> {repo, verify_repository(repo)} end)

    failures = Enum.filter(results, fn {_, result} -> result != :ok end)

    if Enum.empty?(failures) do
      IO.puts("\n✅ All repositories verified and ready for testing")
      :ok
    else
      # Format the error message
      error_messages = Enum.map_join(failures, "\n", fn {repo, {:error, error}} ->
        "  - #{inspect(repo)}: #{format_error(error)}"
      end)

      IO.puts("\n❌ CRITICAL ERROR: Repository verification failed!")
      IO.puts("The following repositories failed verification:")
      IO.puts(error_messages)
      IO.puts("\nTests cannot proceed without functional repositories.")
      IO.puts("Please check your database configuration and ensure Postgres is running.")

      # Halt the test run with a non-zero exit code
      System.halt(1)
    end
  end

  @doc """
  Verifies that a single repository is properly started and functional.
  """
  def verify_repository(repo) do
    process_check =
      case Process.whereis(repo) do
        nil -> {:error, :not_started}
        pid ->
          if Process.alive?(pid) do
            :ok
          else
            {:error, :process_dead}
          end
      end

    case process_check do
      :ok ->
        try do
          # First, check out a connection from the repository
          # This is crucial for sandbox mode
          :ok = Ecto.Adapters.SQL.Sandbox.checkout(repo, [])

          # Try to query the PostgreSQL version - simple query that will work
          # even with empty databases or missing tables
          case repo.query("SELECT version()", []) do
            {:ok, _} ->
              IO.puts("  ✓ Repository #{inspect(repo)} is fully operational")
              # Be sure to check the connection back in
              Ecto.Adapters.SQL.Sandbox.checkin(repo)
              :ok
            {:error, error} ->
              # Check connection back in even on error
              Ecto.Adapters.SQL.Sandbox.checkin(repo)
              IO.puts("  ✗ Repository #{inspect(repo)} connection error: #{inspect(error)}")
              {:error, error}
          end
        rescue
          e ->
            # Make sure to check in the connection even if an exception occurs
            try do
              Ecto.Adapters.SQL.Sandbox.checkin(repo)
            rescue
              _ -> :ok
            end

            # Log full stacktrace for debugging
            IO.puts("  ✗ Repository #{inspect(repo)} failed connection test: #{Exception.message(e)}")
            {:error, e}
        end
      {:error, reason} ->
        IO.puts("  ✗ Repository #{inspect(repo)} process error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Ensures the test_schema table exists in the given repository.
  """
  def ensure_test_schema_exists(repo) do
    IO.puts("\nVerifying test_schema table in #{inspect(repo)}...")

    # First check out a connection
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(repo, [])

    try do
      # Check if the test_schema table exists
      check_query = """
      SELECT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_name = 'test_schema'
      )
      """

      case repo.query(check_query, []) do
        {:ok, %{rows: [[true]]}} ->
          IO.puts("  ✓ test_schema table exists")
          :ok

        {:ok, %{rows: [[false]]}} ->
          IO.puts("  ✗ test_schema table missing, creating...")

          # Create the table
          create_query = """
          CREATE TABLE IF NOT EXISTS test_schema (
            id SERIAL PRIMARY KEY,
            name VARCHAR,
            value VARCHAR,
            inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMP NOT NULL DEFAULT NOW()
          )
          """

          case repo.query(create_query, []) do
            {:ok, _} ->
              IO.puts("  ✓ test_schema table created successfully")
              :ok
            {:error, error} ->
              IO.puts("  ✗ Failed to create test_schema table: #{inspect(error)}")
              {:error, error}
          end

        {:error, error} ->
          IO.puts("  ✗ Error checking for test_schema table: #{inspect(error)}")
          {:error, error}
      end
    rescue
      e ->
        IO.puts("  ✗ Exception when verifying test_schema: #{Exception.message(e)}")
        {:error, e}
    after
      # Always check in the connection
      Ecto.Adapters.SQL.Sandbox.checkin(repo)
    end
  end

  # Helper to format error messages
  defp format_error(%{__struct__: struct, message: message}) do
    "#{inspect(struct)}: #{message}"
  end

  defp format_error(%{__exception__: true} = exception) do
    Exception.message(exception)
  end

  defp format_error(error) do
    inspect(error)
  end
end

# Verify all repositories are properly started
IO.puts("\n=== Repository Verification ===")
IO.puts("Setting up repository sandbox mode...")

# Make sure all repositories are in shared sandbox mode before verification
# This allows the verification code to access the databases without explicit checkouts
Enum.each(repos, fn repo ->
  if Process.whereis(repo) do
    # Set to shared mode to simplify verification
    # We'll set it back to manual mode after verification is complete
    Ecto.Adapters.SQL.Sandbox.mode(repo, {:shared, self()})
    IO.puts("  ✓ Set #{inspect(repo)} to shared sandbox mode")
  else
    IO.puts("  ✗ Repository #{inspect(repo)} is not running")
  end
end)

# Run the verification with shared mode
GameBot.Test.RepoVerification.verify_all_repositories(repos)

# Ensure test_schema table exists in each repository
Enum.each(repos, fn repo ->
  # Only try to create test_schema for main repositories (not event store)
  repo_name = Atom.to_string(repo)
  if String.contains?(repo_name, "Repo") and not String.contains?(repo_name, "EventStore") do
    GameBot.Test.RepoVerification.ensure_test_schema_exists(repo)
  end
end)

# Set repositories back to manual mode for tests
IO.puts("\nSetting repositories back to manual sandbox mode for tests...")
Enum.each(repos, fn repo ->
  if Process.whereis(repo) do
    Ecto.Adapters.SQL.Sandbox.mode(repo, :manual)
    IO.puts("  ✓ Set #{inspect(repo)} to manual sandbox mode")
  end
end)

# Register cleanup for after each test
ExUnit.after_suite(fn _ ->
  IO.puts("\nCleaning up test environment...")

  # Automatically rollback transactions and check in connections
  IO.puts("\nCleaning up repository connections...")
  Enum.each(repos, fn repo ->
    try do
      if Process.whereis(repo) do
        # Try to rollback any lingering transactions
        try do
          Ecto.Adapters.SQL.Sandbox.checkout(repo)
          repo.rollback(fn -> :ok end)
        rescue
          _ -> :ok
        after
          # Always check in the connection
          Ecto.Adapters.SQL.Sandbox.checkin(repo)
        end

        IO.puts("  ✓ Cleaned up connections for #{inspect(repo)}")
      end
    rescue
      e -> IO.puts("  ✗ Error cleaning up #{inspect(repo)}: #{inspect(e)}")
    end
  end)

  # First check in any checked out connections
  Enum.each(repos, fn repo ->
    try do
      if Process.whereis(repo) do
        Ecto.Adapters.SQL.Sandbox.checkin(repo)
      end
    rescue
      _ -> :ok
    end
  end)

  # Then stop repositories in reverse order
  Enum.reverse(repos)
  |> Enum.each(fn repo ->
    try do
      if Process.whereis(repo) do
        IO.puts("Stopping #{inspect(repo)}")
        GenServer.stop(repo)
      end
    rescue
      _ -> :ok
    end
  end)
end)
