defmodule GameBot.Replay.EventStoreAccessTest do
  use ExUnit.Case, async: false

  alias GameBot.Replay.EventStoreAccess
  alias GameBot.Test.Mocks.EventStore, as: EventStoreMock

  setup do
    # Reset the mock state before each test
    EventStoreMock.reset_state()
    :ok
  end

  describe "fetch_game_events/2" do
    test "successfully fetches events when stream exists" do
      # Create test events
      game_id = "test-game-123"
      test_events = create_test_events(game_id, 5)

      # Setup mock to return our test events
      setup_successful_event_fetching(game_id, test_events)

      # Test the function
      {:ok, fetched_events} = EventStoreAccess.fetch_game_events(game_id)

      # Verify the results
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
      # Verify we got the first 10 events by checking the sequence
      assert Enum.map(fetched_events, & &1.sequence) == Enum.to_list(1..10)
    end

    test "handles pagination correctly" do
      game_id = "paginated-game"
      test_events = create_test_events(game_id, 25)

      # Configure mock to return events in batches
      setup_paginated_event_fetching(game_id, test_events, batch_size: 10)

      # Fetch with a small batch size
      {:ok, fetched_events} = EventStoreAccess.fetch_game_events(game_id, batch_size: 10)

      # Verify we got all events despite pagination
      assert length(fetched_events) == 25
      assert Enum.map(fetched_events, & &1.sequence) == Enum.to_list(1..25)
    end

    test "returns stream_not_found error when game doesn't exist" do
      game_id = "nonexistent-game"
      setup_stream_not_found_error(game_id)

      result = EventStoreAccess.fetch_game_events(game_id)

      assert result == {:error, :stream_not_found}
    end

    test "handles other errors from the event store" do
      game_id = "error-game"
      setup_generic_error(game_id, :connection_error)

      result = EventStoreAccess.fetch_game_events(game_id)

      assert result == {:error, :connection_error}
    end

    test "recovers and returns partial results when error occurs after fetching some events" do
      game_id = "partial-error-game"
      test_events = create_test_events(game_id, 5)

      # Setup mock to return events first, then error on next call
      setup_partial_success_then_error(game_id, test_events)

      {:ok, fetched_events} = EventStoreAccess.fetch_game_events(game_id)

      # Verify we got the events that were fetched before the error
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
      setup_generic_error(game_id, :version_fetch_failed)

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
      setup_generic_error(game_id, :existence_check_failed)

      result = EventStoreAccess.game_exists?(game_id)

      assert result == {:error, :existence_check_failed}
    end
  end

  # Helper functions for setting up mock behavior

  defp create_test_events(game_id, count) do
    Enum.map(1..count, fn sequence ->
      %{
        game_id: game_id,
        event_type: "test_event",
        event_version: 1,
        timestamp: DateTime.utc_now(),
        version: sequence,
        sequence: sequence,
        data: %{test: "data", number: sequence}
      }
    end)
  end

  defp setup_successful_event_fetching(game_id, events) do
    # Create a simple implementation that returns all events at once
    :ok = :meck.new(GameBot.Infrastructure.Persistence.EventStore.Adapter, [:passthrough])
    :ok = :meck.expect(
      GameBot.Infrastructure.Persistence.EventStore.Adapter,
      :read_stream_forward,
      fn ^game_id, _start_version, _count -> {:ok, events} end
    )

    on_exit(fn -> :meck.unload() end)
  end

  defp setup_paginated_event_fetching(game_id, events, opts) do
    batch_size = Keyword.get(opts, :batch_size, 10)

    # Create an implementation that returns events in batches
    :ok = :meck.new(GameBot.Infrastructure.Persistence.EventStore.Adapter, [:passthrough])
    :ok = :meck.expect(
      GameBot.Infrastructure.Persistence.EventStore.Adapter,
      :read_stream_forward,
      fn ^game_id, start_version, count ->
        # Calculate which events to return based on start_version
        real_start = start_version
        # Calculate end version (inclusive)
        real_end = min(start_version + count - 1, length(events))

        # Extract events for this batch
        batch = if real_start < length(events) do
          Enum.slice(events, real_start, real_end - real_start)
        else
          []
        end

        {:ok, batch}
      end
    )

    on_exit(fn -> :meck.unload() end)
  end

  defp setup_stream_not_found_error(game_id) do
    :ok = :meck.new(GameBot.Infrastructure.Persistence.EventStore.Adapter, [:passthrough])
    :ok = :meck.expect(
      GameBot.Infrastructure.Persistence.EventStore.Adapter,
      :read_stream_forward,
      fn ^game_id, _start_version, _count -> {:error, :stream_not_found} end
    )

    on_exit(fn -> :meck.unload() end)
  end

  defp setup_generic_error(game_id, error_reason) do
    :ok = :meck.new(GameBot.Infrastructure.Persistence.EventStore.Adapter, [:passthrough])
    :ok = :meck.expect(
      GameBot.Infrastructure.Persistence.EventStore.Adapter,
      :read_stream_forward,
      fn ^game_id, _start_version, _count -> {:error, error_reason} end
    )
    :ok = :meck.expect(
      GameBot.Infrastructure.Persistence.EventStore.Adapter,
      :stream_version,
      fn ^game_id -> {:error, error_reason} end
    )

    on_exit(fn -> :meck.unload() end)
  end

  defp setup_partial_success_then_error(game_id, events) do
    # First call will succeed, second will fail
    agent = start_supervised!({Agent, fn -> 0 end})

    :ok = :meck.new(GameBot.Infrastructure.Persistence.EventStore.Adapter, [:passthrough])
    :ok = :meck.expect(
      GameBot.Infrastructure.Persistence.EventStore.Adapter,
      :read_stream_forward,
      fn ^game_id, _start_version, _count ->
        call_count = Agent.get_and_update(agent, fn count -> {count, count + 1} end)

        case call_count do
          0 -> {:ok, events}
          _ -> {:error, :connection_error}
        end
      end
    )

    on_exit(fn -> :meck.unload() end)
  end

  defp setup_stream_version(game_id, version) do
    :ok = :meck.new(GameBot.Infrastructure.Persistence.EventStore.Adapter, [:passthrough])
    :ok = :meck.expect(
      GameBot.Infrastructure.Persistence.EventStore.Adapter,
      :stream_version,
      fn ^game_id -> {:ok, version} end
    )

    on_exit(fn -> :meck.unload() end)
  end
end
