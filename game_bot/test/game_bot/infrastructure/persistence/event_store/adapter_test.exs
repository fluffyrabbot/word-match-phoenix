defmodule GameBot.Infrastructure.Persistence.EventStore.AdapterTest do
  use GameBot.Test.RepositoryCase, async: true

  alias GameBot.Infrastructure.Persistence.EventStore.Adapter
  alias GameBot.Infrastructure.Persistence.Error
  alias GameBot.Test.Mocks.EventStore

  setup do
    start_supervised!(EventStore)
    EventStore.reset_state()
    :ok
  end

  describe "append_to_stream/4" do
    test "validates events before appending" do
      assert {:error, %Error{type: :validation}} =
        Adapter.append_to_stream("test-stream", 0, "invalid")
    end

    test "validates stream size" do
      stream_id = unique_stream_id()
      events = List.duplicate(build_test_event(), 10_001)

      assert {:error, %Error{type: :stream_too_large}} =
        Adapter.append_to_stream(stream_id, 0, events)
    end

    test "handles serialization errors" do
      stream_id = unique_stream_id()
      invalid_event = %{invalid: "structure"}

      assert {:error, %Error{type: :serialization}} =
        Adapter.append_to_stream(stream_id, 0, [invalid_event])
    end

    test "retries on connection errors and succeeds" do
      stream_id = unique_stream_id()
      event = build_test_event()
      EventStore.set_failure_count(2)

      assert {:ok, _} = Adapter.append_to_stream(stream_id, 0, [event])
      assert {:ok, [stored_event]} = Adapter.read_stream_forward(stream_id)
      assert stored_event.event_type == event.event_type
    end

    test "fails after max retries" do
      stream_id = unique_stream_id()
      event = build_test_event()
      EventStore.set_failure_count(5)  # More than max retries

      assert {:error, %Error{type: :connection}} =
        Adapter.append_to_stream(stream_id, 0, [event])
    end

    test "handles concurrent modifications" do
      stream_id = unique_stream_id()
      event = build_test_event()

      {:ok, _} = Adapter.append_to_stream(stream_id, 0, [event])
      assert {:error, %Error{type: :concurrency}} =
        Adapter.append_to_stream(stream_id, 0, [event])
    end
  end

  describe "read_stream_forward/4" do
    test "deserializes events on read" do
      stream_id = unique_stream_id()
      event = build_test_event()

      {:ok, _} = Adapter.append_to_stream(stream_id, 0, [event])
      assert {:ok, [read_event]} = Adapter.read_stream_forward(stream_id)
      assert read_event.event_type == event.event_type
    end

    test "handles non-existent streams" do
      assert {:error, %Error{type: :not_found}} =
        Adapter.read_stream_forward("non-existent")
    end

    test "respects start version and count" do
      stream_id = unique_stream_id()
      events = Enum.map(1..5, fn i -> build_test_event("event_#{i}") end)

      {:ok, _} = Adapter.append_to_stream(stream_id, 0, events)
      assert {:ok, read_events} = Adapter.read_stream_forward(stream_id, 2, 2)
      assert length(read_events) == 2
      assert Enum.at(read_events, 0).event_type == "event_3"
    end
  end

  describe "subscribe_to_stream/4" do
    test "successfully subscribes to stream" do
      stream_id = unique_stream_id()
      assert {:ok, subscription} = Adapter.subscribe_to_stream(stream_id, self())
      assert is_reference(subscription)
    end

    test "receives events after subscription" do
      stream_id = unique_stream_id()
      event = build_test_event()

      {:ok, _} = Adapter.subscribe_to_stream(stream_id, self())
      {:ok, _} = Adapter.append_to_stream(stream_id, 0, [event])

      assert_receive {:events, [received_event]}
      assert received_event.event_type == event.event_type
    end
  end

  describe "timeout handling" do
    test "respects timeout settings for append" do
      stream_id = unique_stream_id()
      event = build_test_event()
      EventStore.set_delay(50)

      assert {:error, %Error{type: :timeout}} =
        Adapter.append_to_stream(stream_id, 0, [event], timeout: 1)
    end

    test "respects timeout settings for read" do
      stream_id = unique_stream_id()
      EventStore.set_delay(50)

      assert {:error, %Error{type: :timeout}} =
        Adapter.read_stream_forward(stream_id, 0, 10, timeout: 1)
    end
  end
end
