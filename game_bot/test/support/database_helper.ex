defmodule GameBot.Test.DatabaseHelper do
  @moduledoc """
  Centralized database management for tests.
  Handles all database operations, connection management, and sandbox configuration.

  This module provides a single source of truth for database operations in tests,
  eliminating race conditions and inconsistent cleanup issues.
  """

  use ExUnit.CaseTemplate
  require Logger

  alias GameBot.Infrastructure.Persistence.Repo
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres, as: EventStoreRepo

  # Standard timeout values for database operations
  @db_timeout 15_000
  @checkout_timeout 30_000
  @ownership_timeout 60_000
  @retry_interval 100
  @max_retries 5

  # List of all repositories that need to be managed
  @repos [Repo, EventStoreRepo]

  @doc """
  Initializes the test environment.
  This should be called once at the start of the test suite.
  """
  def initialize_test_environment do
    Logger.info("Initializing test environment")

    # Start required applications in order
    apps = [
      :logger,
      :crypto,
      :ssl,
      :postgrex,
      :ecto,
      :ecto_sql,
      :eventstore
    ]

    # Start each application and handle errors
    Enum.each(apps, fn app ->
      case Application.ensure_all_started(app) do
        {:ok, _} -> :ok
        {:error, {dep, reason}} ->
          Logger.error("Failed to start #{app}. Dependency #{dep} failed: #{inspect(reason)}")
          raise "Failed to start required application: #{app}"
      end
    end)

    # Log database names for debugging
    log_database_names()

    # Initialize repositories with retry logic
    with :ok <- terminate_existing_connections(),
         :ok <- ensure_repositories_started() do
      configure_sandbox_mode()
    else
      {:error, reason} ->
        Logger.error("Failed to initialize test environment: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Sets up the sandbox for a test based on the provided tags.
  This should be called in the setup block of test cases.
  """
  def setup_sandbox(tags) do
    if tags[:skip_db] do
      :ok
    else
      if tags[:mock] do
        setup_mock_sandbox(tags)
      else
        do_setup_sandbox(tags)
      end
    end
  end

  @doc """
  Cleans up database connections.
  This should be called in the on_exit callback of test cases.
  """
  def cleanup_connections do
    Logger.debug("Cleaning up database connections")

    # First, try to terminate all current connections
    terminate_existing_connections()

    # Then, restart repositories if needed
    restart_repositories_if_needed()

    :ok
  end

  # Private Functions

  defp setup_mock_sandbox(_tags) do
    Logger.debug("Setting up mock sandbox")

    # Configure the repository implementation to use the mock
    Application.put_env(:game_bot, :repository_implementation,
      GameBot.Infrastructure.Persistence.Repo.MockRepo)

    # Verify the configuration
    repo_impl = Application.get_env(:game_bot, :repository_implementation)
    Logger.debug("Repository implementation set to: #{inspect(repo_impl)}")

    :ok
  end

  defp do_setup_sandbox(tags) do
    # First ensure clean state
    cleanup_connections()

    # Configure the repository implementation to use PostgreSQL
    Application.put_env(:game_bot, :repository_implementation,
      GameBot.Infrastructure.Persistence.Repo.Postgres)

    # Verify the configuration
    repo_impl = Application.get_env(:game_bot, :repository_implementation)
    Logger.debug("Repository implementation set to: #{inspect(repo_impl)}")

    # Configure sandbox based on async setting
    sandbox_opts = [
      ownership_timeout: @ownership_timeout,
      shared: not tags[:async]
    ]

    # Ensure repositories are running
    ensure_repositories_started()

    # Checkout repositories with proper error handling and retry
    Enum.each(@repos, fn repo ->
      try_with_retries(@max_retries, @retry_interval, fn ->
        try do
          case Ecto.Adapters.SQL.Sandbox.checkout(repo, sandbox_opts) do
            :ok ->
              Logger.debug("Successfully checked out #{inspect(repo)}")
              # Allow shared mode for non-async tests
              unless tags[:async] do
                Ecto.Adapters.SQL.Sandbox.mode(repo, {:shared, self()})
              end
              :ok
            {:ok, _} ->
              Logger.debug("Successfully checked out #{inspect(repo)}")
              # Allow shared mode for non-async tests
              unless tags[:async] do
                Ecto.Adapters.SQL.Sandbox.mode(repo, {:shared, self()})
              end
              :ok
            {:error, error} ->
              Logger.error("Failed to checkout #{inspect(repo)}: #{inspect(error)}")
              raise "Failed to checkout repository: #{inspect(repo)}"
          end
        rescue
          e ->
            Logger.error("Error during sandbox setup for #{inspect(repo)}: #{inspect(e)}")
            # Force reconnect on error
            restart_repository(repo)
            # Re-raise to trigger retry
            reraise e, __STACKTRACE__
        end
      end)
    end)

    :ok
  end

  defp ensure_repositories_started do
    Logger.info("Starting repositories")

    repo_results = Enum.map(@repos, &start_repository/1)

    if Enum.all?(repo_results, &(&1 == :ok)) do
      :ok
    else
      errors = Enum.filter(repo_results, &(elem(&1, 0) == :error))
      {:error, "Failed to start repositories: #{inspect(errors)}"}
    end
  end

  defp restart_repositories_if_needed do
    Logger.debug("Checking and restarting repositories if needed")

    Enum.each(@repos, fn repo ->
      case Process.whereis(repo) do
        nil ->
          # Repository not running, restart it
          Logger.debug("Repository #{inspect(repo)} not found, starting it")
          start_repository(repo)
        pid when is_pid(pid) ->
          # Repository is running, check its state
          if Process.alive?(pid) do
            # Check if connections are working
            try do
              # Try a simple query to check connection
              repo.aggregate(repo, :count, :id)
              Logger.debug("Repository #{inspect(repo)} connections are working")
            rescue
              e ->
                Logger.warning("Repository #{inspect(repo)} connection check failed: #{inspect(e)}")
                restart_repository(repo)
            end
          else
            # Process is dead, restart it
            Logger.warning("Repository #{inspect(repo)} process is dead, restarting")
            start_repository(repo)
          end
      end
    end)
  end

  defp restart_repository(repo) do
    Logger.info("Restarting repository: #{inspect(repo)}")

    # First try to stop it cleanly
    try do
      if Process.whereis(repo) do
        repo.stop()
        Process.sleep(200)  # Give it time to shut down
      end
    rescue
      _ -> :ok  # Ignore errors when stopping
    end

    # Then start it again
    start_repository(repo)
  end

  defp start_repository(repo) do
    Logger.debug("Starting repository: #{inspect(repo)}")

    # Get full config with default values
    config = get_repo_config(repo)

    # Ensure the repository is registered in the Registry
    Process.put({:repo, repo}, repo)

    try_with_retries(@max_retries, @retry_interval, fn ->
      case repo.start_link(config) do
        {:ok, pid} ->
          Logger.debug("Successfully started #{inspect(repo)} with PID #{inspect(pid)}")
          Process.sleep(200) # Give the repo time to fully initialize
          :ok
        {:error, {:already_started, pid}} ->
          Logger.debug("Repository #{inspect(repo)} already started with PID #{inspect(pid)}")
          :ok
        {:error, error} ->
          Logger.error("Failed to start #{inspect(repo)}: #{inspect(error)}")
          {:error, {repo, error}}
      end
    end)
  end

  defp get_repo_config(repo) do
    Application.get_env(:game_bot, repo, [])
    |> Keyword.put(:pool, Ecto.Adapters.SQL.Sandbox)
    |> Keyword.put(:pool_size, 10)
    |> Keyword.put(:queue_target, 500)
    |> Keyword.put(:queue_interval, 1000)
    |> Keyword.put(:ownership_timeout, @ownership_timeout)
    |> Keyword.put(:connect_timeout, @db_timeout)
    |> Keyword.put(:timeout, @db_timeout)
  end

  defp configure_sandbox_mode do
    Logger.info("Configuring sandbox mode for repositories")

    Enum.each(@repos, fn repo ->
      :ok = Ecto.Adapters.SQL.Sandbox.mode(repo, :manual)
    end)

    :ok
  end

  defp terminate_existing_connections do
    Logger.debug("Terminating existing database connections")

    query = """
    SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE pid <> pg_backend_pid()
    AND datname IN ($1, $2)
    """

    try_with_retries(@max_retries, @retry_interval, fn ->
      try do
        {:ok, conn} = Postgrex.start_link(
          hostname: "localhost",
          username: "postgres",
          password: "csstarahid",
          database: "postgres",
          timeout: @db_timeout,
          connect_timeout: @db_timeout
        )

        result = Postgrex.query!(conn, query, [
          get_main_db_name(),
          get_event_db_name()
        ])

        GenServer.stop(conn)
        :ok
      rescue
        e ->
          Logger.error("Failed to terminate connections: #{inspect(e)}")
          {:error, :connection_termination_failed}
      end
    end)
  end

  defp get_main_db_name do
    Application.get_env(:game_bot, :test_databases)[:main_db]
  end

  defp get_event_db_name do
    Application.get_env(:game_bot, :test_databases)[:event_db]
  end

  defp log_database_names do
    Logger.info("""
    Working with databases:
    Main DB: #{get_main_db_name()}
    Event DB: #{get_event_db_name()}
    """)
  end

  # Generic retry function with exponential backoff
  defp try_with_retries(0, _delay, _fun), do: {:error, :max_retries_exceeded}
  defp try_with_retries(retries, delay, fun) do
    try do
      case fun.() do
        :ok -> :ok
        {:ok, value} -> {:ok, value}
        other -> other
      end
    rescue
      e ->
        Logger.warning("Operation failed (#{retries} retries left): #{inspect(e)}")
        Process.sleep(delay)
        try_with_retries(retries - 1, delay * 2, fun)  # Exponential backoff
    catch
      :exit, reason ->
        Logger.warning("Operation exited (#{retries} retries left): #{inspect(reason)}")
        Process.sleep(delay)
        try_with_retries(retries - 1, delay * 2, fun)  # Exponential backoff
    end
  end
end
