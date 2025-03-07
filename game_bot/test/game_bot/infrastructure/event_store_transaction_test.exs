defmodule GameBot.Infrastructure.EventStoreTransactionTest do
  use ExUnit.Case

  alias GameBot.Infrastructure.EventStoreTransaction
  alias GameBot.Infrastructure.EventStore
  alias GameBot.Domain.Events.GameEvents.ExampleEvent
  alias GameBot.Domain.Events.Metadata
  alias GameBot.Domain.Events.EventRegistry

  # Setup block to ensure EventRegistry is started and clean up after tests
  setup do
    # Start the event registry
    EventRegistry.start_link()

    # Create a unique stream ID for each test
    stream_id = "test-stream-#{:erlang.unique_integer([:positive])}"

    # Return the stream ID for use in tests
    {:ok, %{stream_id: stream_id}}
  end

  # Helper to create test events
  defp create_test_event(stream_id, index) do
    metadata = Metadata.new("test-source-#{index}", %{actor_id: "test-user"})

    ExampleEvent.new(
      stream_id,                      # game_id
      "test-guild",                   # guild_id
      "test-player-#{index}",         # player_id
      "test-action-#{index}",         # action
      %{test_index: index},           # data
      metadata                        # metadata
    )
  end

  describe "append_events_in_transaction/4" do
    test "successfully appends multiple events in a transaction", %{stream_id: stream_id} do
      # Create some test events
      events = Enum.map(1..3, fn i -> create_test_event(stream_id, i) end)

      # Append them in a transaction
      assert {:ok, _} = EventStoreTransaction.append_events_in_transaction(stream_id, 0, events)

      # Verify they were all appended
      {:ok, stream_events} = EventStore.read_stream_forward(stream_id)
      assert length(stream_events) == 3
    end

    test "fails if stream version doesn't match", %{stream_id: stream_id} do
      # Create a test event
      event = create_test_event(stream_id, 1)

      # Append it to the stream
      EventStore.append_to_stream(stream_id, 0, [%{data: %{}}])

      # Now try to append with wrong expected version
      result = EventStoreTransaction.append_events_in_transaction(stream_id, 0, [event])
      assert {:error, error} = result
      assert error.type == :concurrency
    end

    test "validates inputs", %{stream_id: stream_id} do
      # Empty event list
      assert {:error, error} = EventStoreTransaction.append_events_in_transaction(stream_id, 0, [])
      assert error.type == :validation

      # Invalid stream ID
      assert {:error, error} = EventStoreTransaction.append_events_in_transaction("", 0, [create_test_event("test", 1)])
      assert error.type == :validation

      # Non-list events
      assert {:error, error} = EventStoreTransaction.append_events_in_transaction(stream_id, 0, "not a list")
      assert error.type == :validation
    end
  end

  describe "process_stream_in_transaction/3" do
    test "processes events and appends new ones in a transaction", %{stream_id: stream_id} do
      # Create and append some initial events
      initial_events = Enum.map(1..2, fn i -> create_test_event(stream_id, i) end)
      {:ok, _} = EventStoreTransaction.append_events_in_transaction(stream_id, 0, initial_events)

      # Process events and create new ones
      processor = fn events ->
        # Create a follow-up event based on the last event
        last_event = List.last(events)
        new_event = ExampleEvent.from_parent(
          last_event,
          "processor",
          "processed",
          %{processed: true, original_count: length(events)}
        )

        {[new_event], length(events)}
      end

      # Execute the transaction
      assert {:ok, {read_events, new_events}} =
        EventStoreTransaction.process_stream_in_transaction(stream_id, processor)

      # Verify the results
      assert length(read_events) == 2
      assert length(new_events) == 1

      # Verify stream now has 3 events
      {:ok, stream_events} = EventStore.read_stream_forward(stream_id)
      assert length(stream_events) == 3

      # Verify the new event's metadata has correct causation
      last_event = List.last(new_events)
      assert last_event.metadata.causation_id != nil
    end

    test "handles processor that doesn't generate new events", %{stream_id: stream_id} do
      # Create and append an initial event
      event = create_test_event(stream_id, 1)
      {:ok, _} = EventStoreTransaction.append_events_in_transaction(stream_id, 0, [event])

      # Process events but don't create new ones
      processor = fn events -> {[], length(events)} end

      # Execute the transaction
      assert {:ok, {read_events, new_events}} =
        EventStoreTransaction.process_stream_in_transaction(stream_id, processor)

      # Verify the results
      assert length(read_events) == 1
      assert Enum.empty?(new_events)

      # Verify stream still has only 1 event
      {:ok, stream_events} = EventStore.read_stream_forward(stream_id)
      assert length(stream_events) == 1
    end

    test "fails if processor raises an exception", %{stream_id: stream_id} do
      # Create and append an initial event
      event = create_test_event(stream_id, 1)
      {:ok, _} = EventStoreTransaction.append_events_in_transaction(stream_id, 0, [event])

      # Processor that raises an exception
      processor = fn _ -> raise "Simulated error" end

      # Execute the transaction - should catch the exception
      assert_raise RuntimeError, "Simulated error", fn ->
        EventStoreTransaction.process_stream_in_transaction(stream_id, processor)
      end

      # Verify stream still has only 1 event (no modifications)
      {:ok, stream_events} = EventStore.read_stream_forward(stream_id)
      assert length(stream_events) == 1
    end
  end
end
