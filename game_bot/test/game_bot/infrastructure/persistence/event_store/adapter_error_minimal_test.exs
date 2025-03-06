defmodule GameBot.Infrastructure.Persistence.EventStore.AdapterErrorMinimalTest do
  use ExUnit.Case
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter
  alias GameBot.Infrastructure.Persistence.Error
  alias GameBot.TestEventStore

  # Force synchronous test (one at a time) to avoid connection issues
  @moduletag :capture_log
  @moduletag timeout: 10000 # Increase timeout

  setup do
    # Clean up any existing processes to avoid conflicts
    Process.whereis(TestEventStore) && GenServer.stop(TestEventStore)

    # Start clean instance for this test only
    {:ok, pid} = TestEventStore.start_link()

    # Clean up at end
    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    :ok
  end

  # Helper for generating test data
  defp unique_id, do: "test-#{:rand.uniform(9999999)}"

  defp build_event(data \\ %{value: "test data"}) do
    %{event_type: "test_event", data: data}
  end

  test "retry mechanism works on connection errors" do
    stream_id = unique_id()
    events = [build_event()]

    # Configure the mock to fail once then succeed
    TestEventStore.set_failure_count(1)

    # This should retry and succeed
    assert {:ok, result} = Adapter.append_to_stream(stream_id, 0, events)
    assert length(result) == 1
  end

  test "returns proper error after max retries" do
    stream_id = unique_id()
    events = [build_event()]

    # Configure the mock to fail more than max retries
    TestEventStore.set_failure_count(10)

    # Should fail but with a proper error structure
    {:error, error} = Adapter.append_to_stream(stream_id, 0, events)

    # The error could be either :connection or :system type
    assert error.type in [:connection, :system]

    # If it's a system error, check details
    if error.type == :system do
      assert error.details == :connection_error ||
             (is_map(error.details) && Map.get(error.details, :reason) == :connection_error)
    end
  end

  test "handles non-existent stream errors gracefully" do
    stream_id = unique_id()

    {:error, error} = Adapter.read_stream_forward(stream_id)

    assert %Error{type: :not_found} = error
    assert is_binary(error.message)
    assert error.details[:stream_id] == stream_id
  end
end
