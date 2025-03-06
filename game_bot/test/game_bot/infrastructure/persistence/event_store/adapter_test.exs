defmodule GameBot.Infrastructure.Persistence.EventStore.AdapterTest do
  use ExUnit.Case
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter
  alias GameBot.Infrastructure.Persistence.Error
  alias GameBot.TestEventStore
  alias GameBot.Test.ConnectionHelper

  # Since we're using the test mock in test environment, we'll test against that

  setup do
    # Close any existing connections to prevent issues
    ConnectionHelper.close_db_connections()

    # Make sure there's no existing process
    Process.whereis(TestEventStore) && GenServer.stop(TestEventStore)

    # Start the test event store
    {:ok, pid} = TestEventStore.start_link()

    # Use pid reference instead of module name for safer cleanup
    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end

      # Clean up all DB connections after test
      ConnectionHelper.close_db_connections()
    end)

    :ok
  end

  # Helper functions to simulate EventStoreCase
  defp unique_stream_id do
    "test-stream-#{System.unique_integer([:positive])}"
  end

  describe "append_to_stream/4" do
    test "successfully appends events" do
      stream_id = unique_stream_id()
      events = [%{event_type: "test_event", data: %{value: "test data"}}]

      assert {:ok, appended_events} = Adapter.append_to_stream(stream_id, 0, events)
      assert length(appended_events) == 1
    end

    test "handles version conflicts" do
      stream_id = unique_stream_id()

      # First append should succeed
      {:ok, _} = Adapter.append_to_stream(stream_id, 0, [%{event_type: "first", data: %{}}])

      # Second append with wrong version should fail
      {:error, error} = Adapter.append_to_stream(stream_id, 0, [%{event_type: "second", data: %{}}])
      assert error.type == :concurrency
    end

    test "retries on connection errors" do
      stream_id = unique_stream_id()
      events = [%{event_type: "test_event", data: %{value: "test data"}}]

      # Set the mock to fail once
      TestEventStore.set_failure_count(1)

      # The operation should still succeed due to retries
      assert {:ok, _} = Adapter.append_to_stream(stream_id, 0, events)
    end
  end

  describe "read_stream_forward/4" do
    test "reads events from a stream" do
      stream_id = unique_stream_id()
      events = [
        %{event_type: "test_event_1", data: %{value: "test data 1"}},
        %{event_type: "test_event_2", data: %{value: "test data 2"}}
      ]

      # First append the events
      {:ok, _} = Adapter.append_to_stream(stream_id, 0, events)

      # Then read them back
      {:ok, read_events} = Adapter.read_stream_forward(stream_id)
      assert length(read_events) == 2
    end

    test "handles non-existent streams" do
      stream_id = unique_stream_id()

      {:error, error} = Adapter.read_stream_forward(stream_id)
      assert error.type == :not_found
    end
  end

  describe "stream_version/1" do
    test "returns 0 for non-existent streams" do
      stream_id = unique_stream_id()

      {:ok, version} = Adapter.stream_version(stream_id)
      assert version == 0
    end

    test "returns correct version for existing streams" do
      stream_id = unique_stream_id()
      events = [
        %{event_type: "test_event_1", data: %{value: "test data 1"}},
        %{event_type: "test_event_2", data: %{value: "test data 2"}}
      ]

      # Append the events
      {:ok, _} = Adapter.append_to_stream(stream_id, 0, events)

      # Check the version
      {:ok, version} = Adapter.stream_version(stream_id)
      assert version == 2
    end
  end

  describe "convenience functions" do
    test "append_events/3 appends with :any version" do
      stream_id = unique_stream_id()
      events = [%{event_type: "test_event", data: %{value: "test data"}}]

      assert {:ok, _} = Adapter.append_events(stream_id, events)

      # Second append should also succeed with :any
      assert {:ok, _} = Adapter.append_events(stream_id, events)
    end

    test "read_events/2 reads all events" do
      stream_id = unique_stream_id()
      events = [
        %{event_type: "test_event_1", data: %{value: "test data 1"}},
        %{event_type: "test_event_2", data: %{value: "test data 2"}}
      ]

      # Append the events
      {:ok, _} = Adapter.append_to_stream(stream_id, 0, events)

      # Read all events
      {:ok, read_events} = Adapter.read_events(stream_id)
      assert length(read_events) == 2
    end
  end
end
