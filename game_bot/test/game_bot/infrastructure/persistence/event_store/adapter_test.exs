defmodule GameBot.Infrastructure.Persistence.EventStore.AdapterTest do
  use ExUnit.Case, async: false

  alias GameBot.Infrastructure.Persistence.EventStore.Adapter
  alias GameBot.Infrastructure.Persistence.RepositoryManager

  # Setup and teardown
  setup do
    # Ensure repositories are started
    RepositoryManager.ensure_all_started()

    # Ensure test event store is properly configured
    Application.put_env(:game_bot, :event_store_adapter, GameBot.Test.EventStoreCore)

    # Generate a unique stream ID for this test
    stream_id = "test-stream-#{System.unique_integer([:positive])}"

    # Start the test event store if not already started
    case GameBot.Test.EventStoreCore.start_link() do
      {:ok, pid} ->
        on_exit(fn ->
          try do
            GameBot.Test.EventStoreCore.reset()
            Process.exit(pid, :normal)
          catch
            _, _ -> :ok
          end
        end)
        {:ok, %{event_store_pid: pid, stream_id: stream_id}}
      {:error, {:already_started, pid}} ->
        # Reset the store if it's already running
        GameBot.Test.EventStoreCore.reset()
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

      # Append to stream
      assert {:ok, 1} = Adapter.append_to_stream(stream_id, :no_stream, [event])
    end

    test "read_stream_forward/4 delegates to configured adapter", %{stream_id: stream_id} do
      # Create and append test events
      events = [
        create_test_event("test-1"),
        create_test_event("test-2")
      ]

      # Make sure we're using the same stream ID for all events
      events = Enum.map(events, fn event -> Map.put(event, :stream_id, stream_id) end)

      # Append to stream
      assert {:ok, 2} = Adapter.append_to_stream(stream_id, :no_stream, events)

      # Read from stream
      assert {:ok, read_events} = Adapter.read_stream_forward(stream_id)
      assert length(read_events) == 2
    end

    test "stream_version/2 delegates to configured adapter", %{stream_id: stream_id} do
      # Create and append test event
      event = create_test_event("test-1")

      # Make sure we're using the stream ID correctly in the test
      event = Map.put(event, :stream_id, stream_id)

      # Check initial version
      assert {:ok, 0} = Adapter.stream_version(stream_id)

      # Append to stream
      assert {:ok, 1} = Adapter.append_to_stream(stream_id, :no_stream, [event])

      # Check updated version
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
