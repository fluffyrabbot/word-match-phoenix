defmodule GameBot.Infrastructure.EventStoreTest do
  use GameBot.EventStoreCase
  alias GameBot.Infrastructure.EventStore

  describe "event store operations" do
    test "can append and read events" do
      stream_id = unique_stream_id()
      event = create_test_event("test_event", %{data: "test"})

      assert {:ok, [%{stream_version: 1}]} = create_test_stream(stream_id, [event])

      assert {:ok, [read_event]} = EventStore.read_stream_forward(stream_id)
      assert read_event.event_type == "test_event"
      assert read_event.data == %{"data" => "test"}
      assert read_event.stream_version == 1
    end

    test "handles optimistic concurrency" do
      stream_id = unique_stream_id()
      event1 = create_test_event("event1", %{data: "1"})
      event2 = create_test_event("event2", %{data: "2"})

      # First append should succeed
      assert {:ok, [%{stream_version: 1}]} = EventStore.append_to_stream(stream_id, 0, [event1])

      # Second append with wrong version should fail
      assert {:error, _} = EventStore.append_to_stream(stream_id, 0, [event2])

      # Second append with correct version should succeed
      assert {:ok, [%{stream_version: 2}]} = EventStore.append_to_stream(stream_id, 1, [event2])
    end

    test "can create and update subscriptions" do
      stream_id = unique_stream_id()
      subscription_id = "test-subscription"
      event = create_test_event("test_event", %{data: "test"})

      # Create subscription
      :ok = EventStore.create_subscription(subscription_id, stream_id)

      # Append event
      {:ok, [%{event_id: event_id, stream_version: version}]} = create_test_stream(stream_id, [event])

      # Update subscription
      :ok = EventStore.update_subscription(subscription_id, stream_id, event_id, version)

      # Verify subscription was updated
      {:ok, subscription} = EventStore.get_subscription(subscription_id, stream_id)
      assert subscription.last_seen_event_id == event_id
      assert subscription.last_seen_stream_version == version
    end
  end
end
