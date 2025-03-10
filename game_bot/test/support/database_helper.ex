defmodule GameBot.Test.DatabaseHelper do
  @moduledoc """
  Helper module for initializing and cleaning up the test database environment.

  This module handles the initialization of database connections, setting up
  sandboxes, and cleaning up connections between tests. It provides a centralized
  way to manage database resources for testing.
  """

  require Logger
  alias GameBot.Test.Config

  @repos [
    GameBot.Infrastructure.Persistence.Repo,
    GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
  ]

  @doc """
  Initializes the test environment.

  This function:
  1. Starts the database repositories
  2. Sets up the sandbox mode for repositories
  3. Disables SQL logging for cleaner test output

  Returns:
  - `:ok` - If initialization is successful
  - `{:error, reason}` - If initialization fails
  """
  def initialize do
    Logger.info("Initializing test environment")

    # Log configuration for debugging
    try do
      Logger.info("Test Configuration:")
      Logger.info("  Repositories: #{inspect(@repos)}")
      Logger.info("  Max retries: #{Config.max_retries()}")
      Logger.info("  Timeout: #{Config.timeout()}")
    rescue
      e -> Logger.error("Error logging configuration: #{inspect(e)}")
    end

    # Start repositories
    start_result = start_repos()

    case start_result do
      :ok ->
        # Configure sandbox mode for test isolation
        setup_sandbox()
        Logger.info("Test environment initialized successfully")
        :ok

      {:error, reason} ->
        Logger.error("Failed to initialize test environment: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Cleans up the test environment.

  This function:
  1. Resets the test event store
  2. Stops the database repositories

  Returns:
  - `:ok` - If cleanup is successful
  - `{:error, reason}` - If cleanup fails
  """
  def cleanup do
    Logger.info("Cleaning up test environment")

    reset_event_store()

    # Stop repositories in reverse order
    Enum.reverse(@repos)
    |> Enum.each(fn repo ->
      case stop_repo(repo) do
        :ok ->
          Logger.debug("#{inspect(repo)} stopped successfully")

        {:error, reason} ->
          Logger.warning("Failed to stop #{inspect(repo)}: #{inspect(reason)}")
      end
    end)

    Logger.info("Test environment cleanup completed")
    :ok
  end

  @doc """
  Resets the sandbox for the test repositories.

  This is useful between tests to ensure test isolation.

  Returns:
  - `:ok` - If reset is successful
  - `{:error, reason}` - If reset fails
  """
  def reset_sandbox do
    Logger.debug("Resetting sandbox mode for repositories")

    Enum.each(@repos, fn repo ->
      if Process.whereis(repo) do
        Ecto.Adapters.SQL.Sandbox.checkin(repo)
        Ecto.Adapters.SQL.Sandbox.checkout(repo, ownership_timeout: Config.ownership_timeout())
      else
        Logger.warning("Repository #{inspect(repo)} is not running, cannot reset sandbox")
      end
    end)

    :ok
  end

  # Private Functions

  defp start_repos do
    Logger.debug("Starting repositories")

    # Start each repository
    Enum.reduce(@repos, :ok, fn repo, acc ->
      case acc do
        :ok ->
          case start_repo(repo) do
            :ok -> :ok
            error -> error
          end

        error -> error
      end
    end)
  end

  defp start_repo(repo) do
    Logger.debug("Starting repository: #{inspect(repo)}")

    # Try to start the repository with retries
    start_repo_with_retries(repo, Config.max_retries())
  end

  defp start_repo_with_retries(_repo, 0) do
    {:error, :max_retries_exceeded}
  end

  defp start_repo_with_retries(repo, retries) do
    try do
      # Check if repository is already started
      if Process.whereis(repo) do
        Logger.debug("#{inspect(repo)} is already running")
        :ok
      else
        # Start the repository
        case repo.start_link([pool_size: 1]) do
          {:ok, _pid} ->
            Logger.debug("#{inspect(repo)} started successfully")
            :ok

          {:error, {:already_started, _pid}} ->
            Logger.debug("#{inspect(repo)} was already started")
            :ok

          {:error, error} ->
            Logger.warning("Error starting #{inspect(repo)}: #{inspect(error)}, retries left: #{retries - 1}")
            :timer.sleep(Config.retry_interval())
            start_repo_with_retries(repo, retries - 1)
        end
      end
    rescue
      e ->
        Logger.error("Exception starting #{inspect(repo)}: #{inspect(e)}, retries left: #{retries - 1}")
        :timer.sleep(Config.retry_interval())
        start_repo_with_retries(repo, retries - 1)
    end
  end

  defp stop_repo(repo) do
    Logger.debug("Stopping repository: #{inspect(repo)}")

    try do
      if Process.whereis(repo) do
        # First, try graceful shutdown
        Process.whereis(repo)
        |> Process.exit(:normal)

        # Wait briefly to allow for graceful shutdown
        :timer.sleep(100)

        # If still alive, force shutdown
        if Process.whereis(repo) do
          Process.whereis(repo)
          |> Process.exit(:kill)
        end

        :ok
      else
        Logger.debug("#{inspect(repo)} is not running")
        :ok
      end
    rescue
      e ->
        Logger.error("Error stopping #{inspect(repo)}: #{inspect(e)}")
        {:error, e}
    end
  end

  defp setup_sandbox do
    Logger.debug("Setting up sandbox mode for repositories")

    Enum.each(@repos, fn repo ->
      if Process.whereis(repo) do
        # Configure sandbox mode
        :ok = Ecto.Adapters.SQL.Sandbox.checkout(repo, ownership_timeout: Config.ownership_timeout())

        # Allow async tests
        Ecto.Adapters.SQL.Sandbox.mode(repo, {:shared, self()})
      else
        Logger.warning("Repository #{inspect(repo)} is not running, cannot setup sandbox")
      end
    end)
  end

  defp reset_event_store do
    Logger.debug("Resetting event store")

    try do
      # Reset the event store if it's running
      if Process.whereis(GameBot.TestEventStore) do
        GameBot.TestEventStore.reset!()
        Logger.debug("Event store reset successfully")
      else
        Logger.warning("Event store is not running, cannot reset")
      end
      :ok
    rescue
      e ->
        Logger.error("Error resetting event store: #{inspect(e)}")
        {:error, e}
    end
  end
end
