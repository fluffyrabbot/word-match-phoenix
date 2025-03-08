defmodule GameBot.Infrastructure.Persistence.EventStore.SimpleTest do
  @moduledoc """
  A simplified test for EventStore functionality.
  """

  use ExUnit.Case, async: false
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres, as: EventStore

  setup do
    # Make sure we have a clean environment
    cleanup_existing_connections()

    # Verify EventStore is available
    assert Process.whereis(EventStore) != nil, "EventStore is not running"

    # Checkout a connection for the test
    Ecto.Adapters.SQL.Sandbox.checkout(EventStore)

    # Return test context
    :ok
  end

  test "basic operations with EventStore" do
    stream_id = "test-stream-#{:erlang.unique_integer([:positive])}"

    # Test event structure
    event = %{
      stream_id: stream_id,
      event_type: "test_event",
      data: %{test: "data"},
      metadata: %{test: "metadata"}
    }

    # Test basic operations
    assert_event_store_functions(EventStore)
    assert_append_and_read(EventStore, stream_id, event)
  end

  defp assert_event_store_functions(impl) do
    # Check that key functions are available
    assert function_exported?(impl, :append_to_stream, 4), "append_to_stream/4 is not exported"
    assert function_exported?(impl, :read_stream_forward, 4), "read_stream_forward/4 is not exported"
  end

  defp assert_append_and_read(impl, stream_id, event) do
    # Try append and verify success
    IO.puts("Testing append_to_stream with #{stream_id}")
    result = impl.append_to_stream(stream_id, :no_stream, [event], [])

    case result do
      {:ok, version} ->
        IO.puts("Successfully appended event, stream version: #{version}")
        assert is_integer(version) and version > 0

        # Test reading the event back
        IO.puts("Testing read_stream_forward with #{stream_id}")
        case impl.read_stream_forward(stream_id) do
          {:ok, events} ->
            IO.puts("Successfully read events, count: #{length(events)}")
            assert length(events) > 0
            read_event = hd(events)
            assert read_event.data == event.data, "Event data doesn't match"

          {:error, reason} ->
            flunk("Failed to read stream: #{inspect(reason)}")
        end

      {:error, reason} ->
        flunk("Failed to append to stream: #{inspect(reason)}")
    end
  end

  defp cleanup_existing_connections do
    # Kill any existing Postgrex connections
    for pid <- Process.list() do
      info = Process.info(pid, [:dictionary])
      if info && get_in(info, [:dictionary, :"$initial_call"]) == {Postgrex.Protocol, :init, 1} do
        Process.exit(pid, :kill)
      end
    end

    # Sleep briefly to allow processes to terminate
    Process.sleep(100)
  end
end
