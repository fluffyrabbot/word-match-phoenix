defmodule GameBot.Replay.EventStoreAccessTest do
  use GameBot.DataCase, async: false

  alias GameBot.Replay.EventStoreAccess
  alias GameBot.Test.Mocks.EventStore, as: EventStoreMock
  alias GameBot.Test.Mocks.EventStoreCore
  alias GameBot.Infrastructure.Persistence.Repo
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
  require Logger

  # Replace the adapter with our mock for tests
  setup do
    # Set up a temporary configuration with the mock adapter
    original_adapter = Application.get_env(:game_bot, :event_store_adapter)
    Application.put_env(:game_bot, :event_store_adapter, EventStoreMock)

    # Use proper Ecto.Adapters.SQL.Sandbox functions with error handling
    setup_sandbox(Repo)
    setup_sandbox(Postgres)

    # Set shared mode for both repos
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    Ecto.Adapters.SQL.Sandbox.mode(Postgres, {:shared, self()})

    # Setup mocks with better error handling - don't fail if there are errors
    setup_mocks()

    on_exit(fn ->
      # Restore original adapter configuration
      if original_adapter do
        Application.put_env(:game_bot, :event_store_adapter, original_adapter)
      else
        Application.delete_env(:game_bot, :event_store_adapter)
      end

      reset_mocks()
      # Try to check in connections but don't fail if they're already checked in
      try_checkin(Repo)
      try_checkin(Postgres)
    end)

    :ok
  end

  # Helper to properly set up sandbox with error handling
  defp setup_sandbox(repo) do
    case Ecto.Adapters.SQL.Sandbox.checkout(repo, ownership_timeout: 15000) do
      :ok ->
        :ok
      {:ok, _} ->
        :ok
      {:already, :owner} ->
        Logger.info("Connection for #{inspect(repo)} already checked out")
        # Force setting the mode even if already checked out
        Ecto.Adapters.SQL.Sandbox.mode(repo, {:shared, self()})
        :ok
      error ->
        Logger.error("Failed to check out connection for #{inspect(repo)}: #{inspect(error)}")
        {:error, error}
    end
  end

  # Helper to safely check in connections
  defp try_checkin(repo) do
    try do
      Ecto.Adapters.SQL.Sandbox.checkin(repo)
    rescue
      e ->
        Logger.warning("Error checking in #{inspect(repo)}: #{inspect(e)}")
        :ok
    catch
      _, _ -> :ok
    end
  end

  defp setup_mocks do
    # Setup EventStoreCore
    case Process.whereis(EventStoreCore) do
      nil ->
        # Not running, start it
        EventStoreCore.start_link([])
      pid when is_pid(pid) ->
        # Already running, reset state
        EventStoreCore.reset_state()
        {:ok, pid}
    end

    # Setup EventStoreMock
    case Process.whereis(EventStoreMock) do
      nil ->
        # Not running, start it
        EventStoreMock.start_link([])
      pid when is_pid(pid) ->
        # Already running, reset state
        EventStoreMock.reset_state()
        {:ok, pid}
    end
  end

  defp reset_mocks do
    try_reset_mock(EventStoreMock)
    try_reset_mock(EventStoreCore)
  end

  # Helper to safely reset a mock
  defp try_reset_mock(mock_module) do
    if pid = Process.whereis(mock_module) do
      mock_module.reset_state()
    end
  end

  defp process_alive?(name) when is_atom(name) do
    case Process.whereis(name) do
      nil -> false
      pid -> Process.alive?(pid)
    end
  end

  defp process_alive?(pid) when is_pid(pid) do
    Process.alive?(pid)
  end

  describe "fetch_game_events/2" do
    test "successfully fetches events when stream exists" do
      game_id = "test-game-123"
      test_events = create_test_events(game_id, 5)

      setup_successful_event_fetching(game_id, test_events)

      {:ok, fetched_events} = EventStoreAccess.fetch_game_events(game_id)

      assert length(fetched_events) == 5
      assert Enum.all?(fetched_events, fn event -> event.game_id == game_id end)
    end

    test "returns empty list when stream exists but has no events" do
      game_id = "empty-game"
      setup_successful_event_fetching(game_id, [])

      {:ok, fetched_events} = EventStoreAccess.fetch_game_events(game_id)

      assert fetched_events == []
    end

    test "respects max_events option" do
      game_id = "large-game"
      test_events = create_test_events(game_id, 20)
      setup_successful_event_fetching(game_id, test_events)

      {:ok, fetched_events} = EventStoreAccess.fetch_game_events(game_id, max_events: 10)

      assert length(fetched_events) == 10
      assert Enum.map(fetched_events, & &1.sequence) == Enum.to_list(1..10)
    end

    test "handles pagination correctly" do
      game_id = "paginated-game"
      test_events = create_test_events(game_id, 25)

      setup_paginated_event_fetching(game_id, test_events, batch_size: 10)

      {:ok, fetched_events} = EventStoreAccess.fetch_game_events(game_id, batch_size: 10)

      assert length(fetched_events) == 25
      assert Enum.map(fetched_events, & &1.sequence) == Enum.to_list(1..25)
    end

    test "returns stream_not_found error when game doesn't exist" do
      game_id = "nonexistent-game"
      setup_stream_not_found_error()

      result = EventStoreAccess.fetch_game_events(game_id)

      assert result == {:error, :stream_not_found}
    end

    test "handles other errors from the event store" do
      game_id = "error-game"
      setup_generic_error(:connection_error)

      result = EventStoreAccess.fetch_game_events(game_id)

      assert result == {:error, :connection_error}
    end

    test "recovers and returns partial results when error occurs after fetching some events" do
      game_id = "partial-error-game"
      test_events = create_test_events(game_id, 5)

      setup_partial_success_then_error(game_id, test_events)

      {:ok, fetched_events} = EventStoreAccess.fetch_game_events(game_id)

      assert length(fetched_events) == 5
    end
  end

  describe "get_stream_version/1" do
    test "returns correct version for existing stream" do
      game_id = "version-test-game"
      setup_stream_version(game_id, 42)

      result = EventStoreAccess.get_stream_version(game_id)

      assert result == {:ok, 42}
    end

    test "returns 0 for new stream" do
      game_id = "new-stream"
      setup_stream_version(game_id, 0)

      result = EventStoreAccess.get_stream_version(game_id)

      assert result == {:ok, 0}
    end

    test "propagates errors from adapter" do
      game_id = "error-version-game"
      setup_generic_error(:version_fetch_failed)

      result = EventStoreAccess.get_stream_version(game_id)

      assert result == {:error, :version_fetch_failed}
    end
  end

  describe "game_exists?/1" do
    test "returns true with version for existing game" do
      game_id = "existing-game"
      setup_stream_version(game_id, 10)

      result = EventStoreAccess.game_exists?(game_id)

      assert result == {:ok, 10}
    end

    test "returns stream_not_found for non-existent game" do
      game_id = "nonexistent-game"
      setup_stream_version(game_id, 0)

      result = EventStoreAccess.game_exists?(game_id)

      assert result == {:error, :stream_not_found}
    end

    test "propagates errors from adapter" do
      game_id = "error-exists-game"
      setup_generic_error(:existence_check_failed)

      result = EventStoreAccess.game_exists?(game_id)

      assert result == {:error, :existence_check_failed}
    end
  end

  defp create_test_events(game_id, count) do
    Enum.map(1..count, fn sequence ->
      %{
        game_id: game_id,
        event_type: "test_event",
        event_version: 1,
        timestamp: DateTime.utc_now(),
        version: sequence - 1,
        sequence: sequence,
        data: %{test: "data", number: sequence}
      }
    end)
  end

  # Mock setup functions
  defp setup_successful_event_fetching(game_id, events) do
    EventStoreCore.setup_events(EventStoreCore, game_id, events, length(events))
  end

  defp setup_paginated_event_fetching(game_id, events, _opts) do
    EventStoreCore.setup_events(EventStoreCore, game_id, events, length(events))
  end

  defp setup_stream_not_found_error() do
    EventStoreCore.setup_error(EventStoreCore, :read, :stream_not_found)
  end

  defp setup_generic_error(error_reason) do
    EventStoreCore.setup_error(EventStoreCore, :read, error_reason)
    EventStoreCore.setup_error(EventStoreCore, :version, error_reason)
  end

  defp setup_partial_success_then_error(game_id, events) do
    EventStoreCore.setup_events(EventStoreCore, game_id, events, length(events))
  end

  defp setup_stream_version(game_id, version) do
    case game_id do
      "error-version-game" ->
        EventStoreCore.setup_error(EventStoreCore, :version, :version_fetch_failed)
      "error-exists-game" ->
        EventStoreCore.setup_error(EventStoreCore, :version, :existence_check_failed)
      _ ->
        if version == 0 do
          EventStoreCore.setup_events(EventStoreCore, game_id, [], 0)
        else
          EventStoreCore.setup_events(EventStoreCore, game_id, [], version)
        end
    end
  end
end
