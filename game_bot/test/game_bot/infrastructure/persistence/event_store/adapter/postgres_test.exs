defmodule GameBot.Infrastructure.Persistence.EventStore.Adapter.PostgresTest do
  use ExUnit.Case, async: true
  use GameBot.Test.EventStoreCase

  alias GameBot.Infrastructure.{Error, ErrorHelpers}
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
  alias GameBot.Infrastructure.Persistence.EventStore.ConnectionError

  @moduletag :integration

  # Define TestEvent before it's used
  defmodule TestEvent do
    defstruct [:stream_id, :event_type, :data, :metadata]
  end

  setup do
    # Clean up test database before each test
    Postgrex.query!(Postgres, "TRUNCATE event_store.streams, event_store.events, event_store.subscriptions CASCADE", [])
    :ok
  end

  describe "append_to_stream/4" do
    test "successfully appends events to a new stream" do
      events = [create_test_event_local("test-1")]
      assert {:ok, 1} = Postgres.append_to_stream("stream-1", :no_stream, events)
    end

    test "successfully appends multiple events" do
      events = [
        create_test_event_local("test-1"),
        create_test_event_local("test-2")
      ]
      assert {:ok, 2} = Postgres.append_to_stream("stream-1", :no_stream, events)
    end

    test "handles optimistic concurrency control" do
      events = [create_test_event_local("test-1")]
      assert {:ok, 1} = Postgres.append_to_stream("stream-1", :no_stream, events)
      assert {:ok, 2} = Postgres.append_to_stream("stream-1", 1, [create_test_event_local("test-2")])
      assert {:error, %Error{type: :concurrency}} = Postgres.append_to_stream("stream-1", 1, events)
    end

    test "allows :any version for appending" do
      events = [create_test_event_local("test-1")]
      assert {:ok, 1} = Postgres.append_to_stream("stream-1", :any, events)
      assert {:ok, 2} = Postgres.append_to_stream("stream-1", :any, events)
    end
  end

  describe "read_stream_forward/4" do
    test "reads events from a stream" do
      events = [
        create_test_event_local("test-1"),
        create_test_event_local("test-2")
      ]
      {:ok, _} = Postgres.append_to_stream("stream-1", :no_stream, events)

      assert {:ok, read_events} = Postgres.read_stream_forward("stream-1")
      assert length(read_events) == 2
      assert Enum.at(read_events, 0).data["id"] == "test-1"
      assert Enum.at(read_events, 1).data["id"] == "test-2"
    end

    test "reads events from a specific version" do
      events = [
        create_test_event_local("test-1"),
        create_test_event_local("test-2"),
        create_test_event_local("test-3")
      ]
      {:ok, _} = Postgres.append_to_stream("stream-1", :no_stream, events)

      assert {:ok, read_events} = Postgres.read_stream_forward("stream-1", 2)
      assert length(read_events) == 2
      assert Enum.at(read_events, 0).data["id"] == "test-2"
      assert Enum.at(read_events, 1).data["id"] == "test-3"
    end

    test "handles non-existent streams" do
      assert {:error, %Error{type: :not_found}} = Postgres.read_stream_forward("non-existent")
    end
  end

  describe "subscribe_to_stream/4" do
    test "successfully subscribes to a stream" do
      # First create a stream
      {:ok, _} = Postgres.append_to_stream("stream-1", :no_stream, [create_test_event_local("test-1")])

      # Then subscribe to it
      assert {:ok, subscription} = Postgres.subscribe_to_stream("stream-1", self())
      assert is_reference(subscription)
    end

    test "handles subscription to non-existent stream" do
      assert {:error, %Error{type: :not_found}} =
        Postgres.subscribe_to_stream("non-existent", self())
    end

    test "supports subscription options" do
      {:ok, _} = Postgres.append_to_stream("stream-1", :no_stream, [create_test_event_local("test-1")])
      options = [start_from: :origin]

      assert {:ok, subscription} = Postgres.subscribe_to_stream("stream-1", self(), options)
      assert is_reference(subscription)
    end
  end

  describe "stream_version/2" do
    test "returns 0 for non-existent stream" do
      assert {:ok, 0} = Postgres.stream_version("non-existent")
    end

    test "returns current version for existing stream" do
      events = [create_test_event_local("test-1")]
      {:ok, version} = Postgres.append_to_stream("stream-1", :no_stream, events)
      assert {:ok, ^version} = Postgres.stream_version("stream-1")
    end
  end

  describe "delete_stream/3" do
    test "successfully deletes a stream" do
      # First create a stream
      events = [create_test_event_local("test-1")]
      {:ok, version} = Postgres.append_to_stream("stream-1", :no_stream, events)

      # Then delete it
      assert :ok = Postgres.delete_stream("stream-1", version)

      # Verify it's gone
      assert {:ok, 0} = Postgres.stream_version("stream-1")
      assert {:error, %Error{type: :not_found}} = Postgres.read_stream_forward("stream-1")
    end

    test "handles optimistic concurrency on delete" do
      events = [create_test_event_local("test-1")]
      {:ok, _} = Postgres.append_to_stream("stream-1", :no_stream, events)

      assert {:error, %Error{type: :concurrency}} = Postgres.delete_stream("stream-1", 999)
    end

    test "handles deleting non-existent stream" do
      assert {:ok, 0} = Postgres.stream_version("non-existent")
      assert :ok = Postgres.delete_stream("non-existent", 0)
    end
  end

  # Helper Functions

  defp create_test_event_local(id) do
    %TestEvent{
      stream_id: "stream-1",
      event_type: "test_event",
      data: %{"id" => id},
      metadata: %{}
    }
  end
end
