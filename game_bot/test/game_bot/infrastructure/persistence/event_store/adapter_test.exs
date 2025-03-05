defmodule GameBot.Infrastructure.Persistence.EventStore.AdapterTest do
  use GameBot.Test.RepositoryCase, async: true

  alias GameBot.Infrastructure.Persistence.EventStore.Adapter
  alias GameBot.Infrastructure.Persistence.Error

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
  end

  describe "read_stream_forward/4" do
    test "deserializes events on read" do
      stream_id = unique_stream_id()
      event = build_test_event()

      {:ok, _} = Adapter.append_to_stream(stream_id, 0, [event])
      assert {:ok, [read_event]} = Adapter.read_stream_forward(stream_id)
      assert read_event.event_type == event.event_type
    end
  end

  describe "retry mechanism" do
    setup do
      start_supervised!(GameBot.Test.Mocks.EventStore)
      :ok
    end

    test "retries on connection errors" do
      stream_id = unique_stream_id()
      event = build_test_event()

      GameBot.Test.Mocks.EventStore.set_failure_count(2)

      assert {:ok, _} = Adapter.append_to_stream(stream_id, 0, [event])
    end

    test "respects timeout settings" do
      stream_id = unique_stream_id()
      event = build_test_event()

      assert {:error, %Error{type: :timeout}} =
        Adapter.append_to_stream(stream_id, 0, [event], timeout: 1)
    end
  end
end
