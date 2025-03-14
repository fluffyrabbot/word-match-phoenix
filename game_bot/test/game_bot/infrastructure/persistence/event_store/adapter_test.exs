defmodule GameBot.Infrastructure.Persistence.EventStore.AdapterTest do
  use ExUnit.Case, async: false

  alias GameBot.Infrastructure.Persistence.EventStore.Adapter
  alias GameBot.Infrastructure.Persistence.RepositoryManager

  # Setup and teardown
  setup do
    # Ensure test event store is properly configured
    Application.put_env(:game_bot, :event_store_adapter, GameBot.Test.EventStoreCore)

    # Check out connection from the repository
    repository = GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(repository)

    # Generate a unique test stream ID that won't be confused with a GenServer name
    random_suffix = :rand.uniform(1000)
    stream_id = "test-stream-#{random_suffix}"

    # Start the test event store
    case GameBot.Test.EventStoreCore.start_link() do
      {:ok, pid} ->
        # Configure adapter to use our test event store core
        Application.put_env(:game_bot, :event_store_adapter, GameBot.Test.EventStoreCore)
        # Return the pid and stream id
        {:ok, %{event_store_pid: pid, stream_id: stream_id}}
      {:error, {:already_started, pid}} ->
        # Reset the store if it's already running
        GameBot.Test.EventStoreCore.reset()
        # Configure adapter to use our test event store core
        Application.put_env(:game_bot, :event_store_adapter, GameBot.Test.EventStoreCore)
        {:ok, %{event_store_pid: pid, stream_id: stream_id}}
      error ->
        error
    end
  end

  describe "adapter functions" do
    test "append_to_stream/4 delegates to configured adapter", %{stream_id: stream_id} do
      # Create a test event
      event = create_test_event("test-1")

      # Make sure we're using the stream ID correctly in the test
      event = Map.put(event, :stream_id, stream_id)

      # First test through the adapter facade
      assert {:ok, 1} = Adapter.append_to_stream(stream_id, :no_stream, [event])

      # Now verify the version through the adapter
      assert {:ok, 1} = Adapter.stream_version(stream_id)
    end

    test "read_stream_forward/4 delegates to configured adapter", %{stream_id: stream_id} do
      # Create and append test events
      events = [
        create_test_event("test-1"),
        create_test_event("test-2")
      ]

      # Make sure we're using the same stream ID for all events
      events = Enum.map(events, fn event -> Map.put(event, :stream_id, stream_id) end)

      # Append to stream using the adapter facade
      assert {:ok, 2} = Adapter.append_to_stream(stream_id, :no_stream, events)

      # Read from stream using the adapter facade
      assert {:ok, read_events, _, _} = Adapter.read_stream_forward(stream_id)
      assert length(read_events) == 2
    end

    test "stream_version/2 delegates to configured adapter", %{stream_id: stream_id} do
      # Create and append test event
      event = create_test_event("test-1")

      # Make sure we're using the stream ID correctly in the test
      event = Map.put(event, :stream_id, stream_id)

      # Check initial version using adapter facade
      assert {:ok, 0} = Adapter.stream_version(stream_id)

      # Append to stream using adapter facade
      assert {:ok, 1} = Adapter.append_to_stream(stream_id, :no_stream, [event])

      # Verify version updated through adapter facade
      assert {:ok, 1} = Adapter.stream_version(stream_id)
    end

    test "delete_stream/3 delegates to configured adapter", %{stream_id: stream_id} do
      # Create and append test event
      event = create_test_event("test-1")

      # Make sure we're using the stream ID correctly in the test
      event = Map.put(event, :stream_id, stream_id)

      # Append to stream
      assert {:ok, 1} = Adapter.append_to_stream(stream_id, :no_stream, [event])

      # Delete stream
      assert :ok = Adapter.delete_stream(stream_id, 1)

      # Verify stream was deleted
      assert {:ok, 0} = Adapter.stream_version(stream_id)
    end
  end

  # Helper functions

  defp create_test_event(id) do
    %{
      event_type: "test_event",
      data: %{id: id, value: "test data for #{id}"},
      metadata: %{correlation_id: "test-correlation-#{id}"}
    }
  end
end
