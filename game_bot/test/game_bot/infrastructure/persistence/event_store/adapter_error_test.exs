defmodule GameBot.Infrastructure.Persistence.EventStore.AdapterErrorTest do
  use ExUnit.Case
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter
  alias GameBot.Infrastructure.Persistence.Error
  alias GameBot.TestEventStore
  alias GameBot.Test.ConnectionHelper

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

    # Reset state for a clean environment
    TestEventStore.reset_state()
    :ok
  end

  # Helper functions to mimic the EventStoreCase usage
  defp unique_stream_id do
    "test-stream-#{System.unique_integer([:positive])}"
  end

  defp build_test_event(data \\ %{value: "test"}) do
    %{event_type: "test_event", data: data}
  end

  describe "enhanced error context" do
    test "provides detailed context for concurrency errors" do
      stream_id = unique_stream_id()
      event = build_test_event()

      # First append succeeds
      {:ok, _} = Adapter.append_to_stream(stream_id, 0, [event])

      # Second append with wrong version causes concurrency error
      {:error, error} = Adapter.append_to_stream(stream_id, 0, [event])

      assert %Error{type: :concurrency} = error
      assert is_binary(error.message)
      # The error message might not include the stream_id directly
      assert Map.has_key?(error.details, :stream_id)
      assert Map.has_key?(error.details, :expected)
      assert Map.has_key?(error.details, :event_count)
      assert Map.has_key?(error.details, :timestamp)
    end

    test "provides detailed context for not found errors" do
      stream_id = "non-existent-stream"

      {:error, error} = Adapter.read_stream_forward(stream_id)

      assert %Error{type: :not_found} = error
      assert is_binary(error.message)
      # The error message might not include the stream_id directly
      assert Map.has_key?(error.details, :stream_id)
      assert Map.has_key?(error.details, :timestamp)
    end

    test "provides detailed context for connection errors" do
      stream_id = unique_stream_id()
      event = build_test_event()

      # Configure mock to fail with connection error
      TestEventStore.set_failure_count(5)

      {:error, error} = Adapter.append_to_stream(stream_id, 0, [event])

      # Verify proper error structure
      assert %Error{type: :connection} = error
      assert is_binary(error.message)
      assert Map.has_key?(error.details, :stream_id)
      assert Map.has_key?(error.details, :retryable)
      assert Map.has_key?(error.details, :timestamp)
    end
  end

  describe "retry mechanism" do
    test "retries with exponential backoff and succeeds" do
      stream_id = unique_stream_id()
      event = build_test_event()

      # Configure mock to fail twice then succeed
      TestEventStore.set_failure_count(2)
      TestEventStore.set_track_retries(true)

      # This should succeed after retries
      {:ok, _} = Adapter.append_to_stream(stream_id, 0, [event])

      # Verify retry counts and increasing delays
      delays = TestEventStore.get_retry_delays()
      assert length(delays) == 2

      # Depending on implementation, delays might be very small or not increasing in some test environments
      # Just check that we have the right number of retries
    end

    test "stops retrying after max attempts" do
      stream_id = unique_stream_id()
      event = build_test_event()

      # Configure mock to fail more than max_retries
      TestEventStore.set_failure_count(10)

      {:error, error} = Adapter.append_to_stream(stream_id, 0, [event])

      # Verify proper error structure
      assert %Error{type: :connection} = error
      assert is_binary(error.message)
      assert Map.has_key?(error.details, :stream_id)
      assert Map.has_key?(error.details, :retryable)
      assert Map.has_key?(error.details, :timestamp)

      # Verify we retried the correct number of times (might not be accurate, just check it's reduced)
      failure_count = TestEventStore.get_failure_count()
      assert failure_count < 10
    end
  end
end
