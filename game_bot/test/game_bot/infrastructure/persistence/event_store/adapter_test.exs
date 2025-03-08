defmodule GameBot.Infrastructure.Persistence.EventStore.AdapterTest do
  use ExUnit.Case, async: false

  alias GameBot.Infrastructure.Persistence.EventStore.Adapter
  alias GameBot.Infrastructure.Persistence.RepositoryManager

  # Setup and teardown
  setup do
    # Ensure repositories are started
    RepositoryManager.ensure_all_started()

    # Get configured test event store module
    test_store = Application.get_env(:game_bot, :event_store_adapter, GameBot.TestEventStore)

    # Start TestEventStore if not already started
    case Process.whereis(test_store) do
      nil ->
        {:ok, _pid} = test_store.start_link()
      _pid ->
        :ok
    end

    # Create a unique test stream ID
    stream_id = "test-stream-#{System.unique_integer([:positive])}"

    # Ensure cleanup on test exit
    on_exit(fn ->
      try do
        test_store.reset_state()
      catch
        :exit, _ -> :ok
      end
    end)

    {:ok, stream_id: stream_id}
  end

  describe "adapter functions" do
    test "append_to_stream/4 delegates to configured adapter", %{stream_id: stream_id} do
      # Create a test event
      event = create_test_event("test-1")

      # Append to stream
      assert {:ok, 1} = Adapter.append_to_stream(stream_id, :no_stream, [event])
    end

    test "read_stream_forward/4 delegates to configured adapter", %{stream_id: stream_id} do
      # Create and append test events
      events = [
        create_test_event("test-1"),
        create_test_event("test-2")
      ]

      # Append to stream
      assert {:ok, 2} = Adapter.append_to_stream(stream_id, :no_stream, events)

      # Read from stream
      assert {:ok, read_events} = Adapter.read_stream_forward(stream_id)
      assert length(read_events) == 2
    end

    test "stream_version/2 delegates to configured adapter", %{stream_id: stream_id} do
      # Create and append test event
      event = create_test_event("test-1")

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
      stream_id: "test-#{id}",
      event_type: "test_event",
      data: %{id: id, value: "test data for #{id}"},
      metadata: %{correlation_id: "test-correlation-#{id}"}
    }
  end
end
