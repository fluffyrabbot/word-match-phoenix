defmodule GameBot.RepositoryCase do
  @moduledoc """
  This module defines common utilities for testing repositories.

  It provides a robust setup for database-backed tests, with proper
  resource management and error handling.
  """

  use ExUnit.CaseTemplate
  require Logger
  alias GameBot.Test.Config
  alias GameBot.Test.DatabaseManager

  # Track monitored processes for proper cleanup
  @process_monitors_key {__MODULE__, :monitors}

  using do
    quote do
      alias GameBot.Infrastructure.Persistence.Repo
      alias GameBot.Infrastructure.Persistence.Repo.Postgres
      alias GameBot.Infrastructure.Persistence.Repo.MockRepo
      import Ecto
      import Ecto.Query
      import GameBot.RepositoryCase
      # We use :meck for mocking in our tests
    end
  end

  # This function checks if the current module is tagged with :mock
  # It will be called by the setup function to determine if we should use the mock repo
  defp mock_test?(tags) do
    # First check if the individual test has the mock tag
    test_has_mock = tags[:mock] == true

    # Then check if the module has the mock tag
    module_has_mock = case tags[:registered] do
      %{} = registered ->
        registered[:mock] == true
      _ -> false
    end

    # Log for debugging
    Logger.debug("Mock detection - Test tag: #{test_has_mock}, Module tag: #{module_has_mock}")

    # Return true if either the test or the module has the mock tag
    test_has_mock || module_has_mock
  end

  setup tags do
    Logger.debug("Repository case setup - tags: #{inspect(tags)}")

    # Initialize process monitor registry for this test
    Process.put(@process_monitors_key, [])

    # For mock tests, we use the MockRepo
    if mock_test?(tags) do
      setup_mock_environment(tags)
    else
      # For regular tests, use the improved database manager setup
      setup_real_environment(tags)
    end

    # Start the test event store if not already started
    start_test_event_store()

    # Register cleanup callback
    on_exit(fn ->
      # Clean up all monitored processes
      cleanup_monitored_processes()

      # Clean up database connections - this won't fully terminate connections
      # as that would disrupt other tests, but will check in any checked out connections
      graceful_cleanup()
    end)

    :ok
  end

  @doc """
  Creates a test event for serialization testing.
  """
  def build_test_event(attrs \\ %{}) do
    Map.merge(%{
      event_type: "test_event",
      event_version: 1,
      data: %{
        game_id: "game-#{System.unique_integer([:positive])}",
        mode: :test,
        round_number: 1,
        timestamp: DateTime.utc_now()
      }
    }, attrs)
  end

  @doc """
  Creates a unique stream ID for testing.
  """
  def unique_stream_id do
    "test-stream-#{System.unique_integer([:positive])}"
  end

  @doc """
  Monitors a process and ensures it will be cleaned up after the test.
  """
  def monitor_process(pid) when is_pid(pid) do
    # Create a monitor reference
    ref = Process.monitor(pid)

    # Store the monitor reference for cleanup
    Process.put(@process_monitors_key, [ref | Process.get(@process_monitors_key, [])])
    {:ok, ref}
  end

  @doc """
  Starts the test event store.
  """
  def start_test_event_store do
    # Configure the event store adapter
    Application.put_env(:game_bot, :event_store_adapter, GameBot.Test.EventStoreCore)

    # First try to reset any existing store
    if Process.whereis(GameBot.Test.EventStoreCore) do
      try do
        GameBot.Test.EventStoreCore.reset()
        Process.sleep(100) # Give it time to reset
      catch
        _, _ -> :ok
      end
    end

    # Now start or restart the store
    case GameBot.Test.EventStoreCore.start_link() do
      {:ok, pid} ->
        Process.sleep(100) # Give it time to initialize
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        # Reset the store and continue
        GameBot.Test.EventStoreCore.reset()
        Process.sleep(100)
        {:ok, pid}
      error -> error
    end
  end

  # Private helper functions

  defp setup_mock_environment(_tags) do
    Logger.debug("Setting up mock test environment")

    # First clear any previous setting to avoid stale configurations
    Application.delete_env(:game_bot, :repo_implementation)

    # Then set the mock implementation
    Application.put_env(:game_bot, :repo_implementation, GameBot.Infrastructure.Persistence.Repo.MockRepo)

    # Verify the configuration was set correctly
    repo_impl = Application.get_env(:game_bot, :repo_implementation)
    Logger.debug("Repository implementation set to: #{inspect(repo_impl)}")

    # Set up :meck for mocking
    setup_meck_for_mock_repo()
  end

  defp setup_meck_for_mock_repo do
    # Only create if not already created (to handle nested describe blocks)
    try do
      # This will raise an error if the module is not mocked
      :meck.validate(GameBot.Infrastructure.Persistence.Repo.MockRepo)
      Logger.debug("MockRepo already mocked, skipping setup")
    rescue
      _ ->
        Logger.debug("Setting up :meck for MockRepo")
        :meck.new(GameBot.Infrastructure.Persistence.Repo.MockRepo, [:passthrough])
    end
  end

  defp setup_real_environment(tags) do
    Logger.debug("Setting up real repository test environment")

    # First set the repo implementation explicitly if not already set
    if is_nil(Application.get_env(:game_bot, :repo_implementation)) do
      Application.put_env(:game_bot, :repo_implementation, GameBot.Infrastructure.Persistence.Repo.Postgres)
    end

    # Use the improved DatabaseManager to set up the sandbox
    DatabaseManager.setup_sandbox(tags)
  end

  defp cleanup_monitored_processes do
    # Get all monitored process references
    monitors = Process.get(@process_monitors_key, [])

    # Demonitor each process
    Enum.each(monitors, fn ref ->
      Process.demonitor(ref, [:flush])
    end)

    # Clear the monitor list
    Process.put(@process_monitors_key, [])
  end

  defp graceful_cleanup do
    # Check in connections but don't fully terminate to avoid disrupting other tests
    repos = [
      GameBot.Infrastructure.Persistence.Repo,
      GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
    ]

    Enum.each(repos, fn repo ->
      if Process.whereis(repo) do
        try do
          Ecto.Adapters.SQL.Sandbox.checkin(repo)
        rescue
          _ -> :ok
        end
      end
    end)
  end
end
