defmodule GameBot.Infrastructure.Persistence.EventStore.AdapterErrorTest do
  use GameBot.Test.RepositoryCase, async: true

  alias GameBot.Infrastructure.Persistence.EventStore.Adapter
  alias GameBot.Infrastructure.Persistence.Error
  alias GameBot.Test.Mocks.EventStore

  setup do
    # Mock EventStore is now started in RepositoryCase setup
    # Reset state to ensure clean test environment
    EventStore.reset_state()
    :ok
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
      assert error.message =~ stream_id
      assert error.message =~ "version 0"
      assert Map.has_key?(error.details, :stream_id)
      assert Map.has_key?(error.details, :expected_version)
      assert Map.has_key?(error.details, :event_count)
      assert Map.has_key?(error.details, :timestamp)
    end

    test "provides detailed context for not found errors" do
      stream_id = "non-existent-stream"

      {:error, error} = Adapter.read_stream_forward(stream_id)

      assert %Error{type: :not_found} = error
      assert is_binary(error.message)
      assert error.message =~ stream_id
      assert Map.has_key?(error.details, :stream_id)
      assert Map.has_key?(error.details, :timestamp)
    end

    test "provides detailed context for connection errors" do
      stream_id = unique_stream_id()
      event = build_test_event()

      # Configure mock to fail with connection error
      EventStore.set_failure_count(5)

      {:error, error} = Adapter.append_to_stream(stream_id, 0, [event])

      assert %Error{type: :connection} = error
      assert is_binary(error.message)
      assert error.message =~ stream_id
      assert Map.has_key?(error.details, :stream_id)
      assert Map.has_key?(error.details, :event_count)
      assert Map.has_key?(error.details, :timestamp)
    end
  end

  describe "retry mechanism" do
    test "retries with exponential backoff and succeeds" do
      stream_id = unique_stream_id()
      event = build_test_event()

      # Configure mock to fail twice then succeed
      EventStore.set_failure_count(2)
      EventStore.set_track_retries(true)

      # This should succeed after retries
      {:ok, _} = Adapter.append_to_stream(stream_id, 0, [event])

      # Verify retry counts and increasing delays
      delays = EventStore.get_retry_delays()
      assert length(delays) == 2
      [delay1, delay2] = delays

      # Second delay should be greater than first (exponential)
      assert delay2 > delay1
    end

    test "stops retrying after max attempts" do
      stream_id = unique_stream_id()
      event = build_test_event()

      # Configure mock to fail more than max_retries
      EventStore.set_failure_count(10)

      {:error, error} = Adapter.append_to_stream(stream_id, 0, [event])

      assert %Error{type: :connection} = error

      # Verify we retried the correct number of times
      assert EventStore.get_failure_count() <= 7 # Initial + max retries
    end
  end
end
