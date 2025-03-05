defmodule GameBot.Infrastructure.Persistence.EventStore.PostgresTest do
  use GameBot.Test.RepositoryCase, async: true

  alias GameBot.Infrastructure.Persistence.EventStore.Postgres
  alias GameBot.Infrastructure.Persistence.Error

  describe "append_to_stream/4" do
    test "successfully appends events to stream" do
      stream_id = unique_stream_id()
      events = [build_test_event()]

      assert {:ok, stored_events} = Postgres.append_to_stream(stream_id, 0, events)
      assert length(stored_events) == 1
    end

    test "handles concurrent modifications" do
      stream_id = unique_stream_id()
      events = [build_test_event()]

      {:ok, _} = Postgres.append_to_stream(stream_id, 0, events)
      assert {:error, %Error{type: :concurrency}} =
        Postgres.append_to_stream(stream_id, 0, events)
    end
  end

  describe "read_stream_forward/4" do
    test "reads events from existing stream" do
      stream_id = unique_stream_id()
      events = [build_test_event()]

      {:ok, _} = Postgres.append_to_stream(stream_id, 0, events)
      assert {:ok, read_events} = Postgres.read_stream_forward(stream_id)
      assert length(read_events) == 1
    end

    test "handles non-existent stream" do
      assert {:error, %Error{type: :not_found}} =
        Postgres.read_stream_forward("non-existent-stream")
    end
  end

  describe "subscribe_to_stream/4" do
    test "successfully subscribes to stream" do
      stream_id = unique_stream_id()
      assert {:ok, subscription} = Postgres.subscribe_to_stream(stream_id, self())
      assert is_pid(subscription)
    end
  end

  describe "stream_version/1" do
    test "returns correct version for empty stream" do
      stream_id = unique_stream_id()
      assert {:ok, 0} = Postgres.stream_version(stream_id)
    end

    test "returns correct version after appending" do
      stream_id = unique_stream_id()
      events = [build_test_event()]

      {:ok, _} = Postgres.append_to_stream(stream_id, 0, events)
      assert {:ok, 1} = Postgres.stream_version(stream_id)
    end
  end
end
