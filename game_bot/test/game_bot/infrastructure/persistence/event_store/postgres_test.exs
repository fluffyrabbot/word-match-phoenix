defmodule GameBot.Infrastructure.Persistence.EventStore.PostgresTest do
  @moduledoc """
  Tests for the EventStore PostgreSQL adapter.
  This is an alias module to ensure compatibility with tests that
  expect a direct PostgresTest module.
  """

  use ExUnit.Case, async: true
  use GameBot.Test.EventStoreCase

  alias GameBot.Infrastructure.{Error, ErrorHelpers}
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres

  @moduletag :integration
  @moduletag timeout: 300000  # Increase test timeout to avoid false failures

  # Define TestEvent before it's used
  defmodule TestEvent do
    defstruct [:stream_id, :event_type, :data, :metadata]
  end

  setup do
    # Clean up test database before each test
    Postgres.query!("TRUNCATE event_store.streams, event_store.events, event_store.subscriptions CASCADE", [])
    :ok
  end

  # Create forwarding functions to make the tests work with the correct module
  def append_to_stream(stream_id, expected_version, events, opts \\ []) do
    Postgres.append_to_stream(stream_id, expected_version, events, opts)
  end

  def read_stream_forward(stream_id, start_version \\ 0, count \\ 1000, opts \\ []) do
    Postgres.read_stream_forward(stream_id, start_version, count, opts)
  end

  def stream_version(stream_id, opts \\ []) do
    Postgres.stream_version(stream_id, opts)
  end

  def subscribe_to_stream(stream_id, subscriber, subscription_options \\ [], opts \\ []) do
    Postgres.subscribe_to_stream(stream_id, subscriber, subscription_options, opts)
  end

  def unsubscribe_from_stream(stream_id, subscription, opts \\ []) do
    alias GameBot.Infrastructure.Persistence.EventStore.Adapter
    Adapter.unsubscribe_from_stream(stream_id, subscription, opts)
  end

  def delete_stream(stream_id, expected_version, opts \\ []) do
    Postgres.delete_stream(stream_id, expected_version, opts)
  end

  describe "append_to_stream/4" do
    test "successfully appends events to a new stream" do
      stream_id = unique_stream_id()
      events = [create_test_event(1)]
      assert {:ok, stored_events} = append_to_stream(stream_id, 0, events)
      assert stored_events == 1
    end

    test "successfully appends multiple events" do
      stream_id = unique_stream_id()
      events = [
        create_test_event(1),
        create_test_event(2)
      ]
      assert {:ok, stored_events} = append_to_stream(stream_id, 0, events)
      assert stored_events == 2
    end

    test "handles concurrent modifications" do
      stream_id = unique_stream_id()
      events = [create_test_event(1)]
      assert {:ok, _} = append_to_stream(stream_id, 0, events)
      assert {:error, %Error{type: :concurrency}} = append_to_stream(stream_id, 0, events)
    end
  end

  describe "read_stream_forward/4" do
    test "reads events from a stream" do
      stream_id = unique_stream_id()
      events = [
        create_test_event(1),
        create_test_event(2)
      ]
      {:ok, _} = append_to_stream(stream_id, 0, events)

      assert {:ok, read_events} = read_stream_forward(stream_id)
      assert length(read_events) == 2
      assert Enum.at(read_events, 0).data["id"] == "test-1"
      assert Enum.at(read_events, 1).data["id"] == "test-2"
    end

    test "reads events from a specific version" do
      stream_id = unique_stream_id()
      events = [
        create_test_event(1),
        create_test_event(2),
        create_test_event(3)
      ]
      {:ok, _} = append_to_stream(stream_id, 0, events)

      assert {:ok, read_events} = read_stream_forward(stream_id, 2)
      assert length(read_events) == 2
      assert Enum.at(read_events, 0).data["id"] == "test-2"
      assert Enum.at(read_events, 1).data["id"] == "test-3"
    end

    test "handles non-existent stream" do
      assert {:error, %Error{type: :not_found}} = read_stream_forward("non-existent")
    end
  end

  describe "subscribe_to_stream/4" do
    test "successfully subscribes to a stream" do
      stream_id = unique_stream_id()
      # First create a stream
      events = [create_test_event(1)]
      {:ok, _} = append_to_stream(stream_id, 0, events)

      # Then subscribe to it
      assert {:ok, subscription} = subscribe_to_stream(stream_id, self())
      assert is_reference(subscription)
    end
  end

  describe "stream_version/1" do
    test "returns correct version for empty stream" do
      stream_id = unique_stream_id()
      assert {:ok, 0} = stream_version(stream_id)
    end

    test "returns correct version after appending" do
      stream_id = unique_stream_id()
      events = [create_test_event(1)]
      {:ok, version} = append_to_stream(stream_id, 0, events)
      assert {:ok, ^version} = stream_version(stream_id)
    end
  end

  describe "delete_stream/3" do
    test "successfully deletes a stream" do
      stream_id = unique_stream_id()
      # First create a stream
      events = [create_test_event(1)]
      {:ok, version} = append_to_stream(stream_id, 0, events)

      # Then delete it
      assert :ok = delete_stream(stream_id, version)

      # Verify it's gone
      assert {:ok, 0} = stream_version(stream_id)
      assert {:error, %Error{type: :not_found}} = read_stream_forward(stream_id)
    end

    test "handles optimistic concurrency on delete" do
      stream_id = unique_stream_id()
      events = [create_test_event(1)]
      {:ok, _} = append_to_stream(stream_id, 0, events)

      assert {:error, %Error{type: :concurrency}} = delete_stream(stream_id, 999)
    end

    test "handles deleting non-existent stream" do
      stream_id = unique_stream_id("non-existent")
      assert {:ok, 0} = stream_version(stream_id)
      assert :ok = delete_stream(stream_id, 0)
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
