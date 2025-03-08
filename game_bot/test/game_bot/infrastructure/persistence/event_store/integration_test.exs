defmodule GameBot.Infrastructure.Persistence.EventStore.IntegrationTest do
  @moduledoc """
  Integration tests for EventStore implementations.
  Tests core functionality, error handling, and concurrency across all implementations.

  ## Test Organization
  - Stream operations (append, read, versioning)
  - Subscription handling
  - Error handling
  - Transaction boundaries
  - Performance characteristics

  ## Important Notes
  - Tests are NOT async due to shared database state
  - Each test uses a unique stream ID
  - Resources are properly cleaned up
  - Proper error handling is verified
  """

  use GameBot.Test.EventStoreCase
  use ExUnit.Case, async: false

  alias GameBot.Infrastructure.EventStore
  alias GameBot.Infrastructure.Persistence.EventStore.Postgres
  alias GameBot.TestEventStore
  alias GameBot.Test.Mocks.EventStore, as: MockEventStore

  @implementations [
    {EventStore, "Infrastructure EventStore"},
    {Postgres, "PostgreSQL implementation"},
    {TestEventStore, "test implementation"},
    {MockEventStore, "mock implementation"}
  ]

  describe "stream operations" do
    test "append and read events" do
      events = [
        create_test_event(:event_1, %{value: "test1"}),
        create_test_event(:event_2, %{value: "test2"})
      ]

      for {impl, name} <- @implementations do
        stream_id = unique_stream_id(name)

        # Test basic append and read
        assert {:ok, _} = impl.append_to_stream(stream_id, 0, events)
        assert {:ok, read_events} = impl.read_stream_forward(stream_id)
        assert length(read_events) == 2
        assert Enum.map(read_events, & &1.data) == Enum.map(events, & &1.data)

        # Test reading with limits
        assert {:ok, [first_event]} = impl.read_stream_forward(stream_id, 0, 1)
        assert first_event.data == hd(events).data
      end
    end

    test "stream versioning" do
      event1 = create_test_event(:event_1)
      event2 = create_test_event(:event_2)

      for {impl, name} <- @implementations do
        stream_id = unique_stream_id(name)

        # Test version handling
        assert {:ok, _} = impl.append_to_stream(stream_id, 0, [event1])
        assert {:error, _} = impl.append_to_stream(stream_id, 0, [event2])
        assert {:ok, _} = impl.append_to_stream(stream_id, 1, [event2])

        # Verify final state
        assert {:ok, events} = impl.read_stream_forward(stream_id)
        assert length(events) == 2
        assert Enum.map(events, & &1.data) == [event1.data, event2.data]
      end
    end

    test "concurrent operations" do
      for {impl, name} <- @implementations do
        stream_id = unique_stream_id("#{name}-concurrent")
        event = create_test_event()

        results = test_concurrent_operations(impl, fn i ->
          impl.append_to_stream(stream_id, i - 1, [event])
        end)

        # Verify concurrency control
        assert Enum.count(results, &match?({:ok, _}, &1)) == 1
        assert Enum.count(results, &match?({:error, _}, &1)) == 4

        # Verify final state
        assert {:ok, events} = impl.read_stream_forward(stream_id)
        assert length(events) == 1
      end
    end
  end

  describe "subscription handling" do
    test "subscribe to stream" do
      event = create_test_event()

      for {impl, name} <- @implementations do
        stream_id = unique_stream_id("#{name}-subscription")
        test_pid = self()

        with_subscription impl, stream_id, test_pid, fn _subscription ->
          # Append event after subscription
          assert {:ok, _} = impl.append_to_stream(stream_id, 0, [event])

          # Verify event received
          assert_receive {:events, received_events}, 1000
          assert length(received_events) == 1
          assert hd(received_events).data == event.data
        end
      end
    end

    test "multiple subscribers" do
      event = create_test_event()

      for {impl, name} <- @implementations do
        stream_id = unique_stream_id("#{name}-multi-sub")
        test_pid = self()

        # Create multiple subscriptions
        with_subscription impl, stream_id, test_pid, fn _sub1 ->
          with_subscription impl, stream_id, test_pid, fn _sub2 ->
            # Append event
            assert {:ok, _} = impl.append_to_stream(stream_id, 0, [event])

            # Both subscribers should receive the event
            assert_receive {:events, events1}, 1000
            assert_receive {:events, events2}, 1000
            assert events1 == events2
          end
        end
      end
    end
  end

  describe "error handling" do
    test "invalid stream operations" do
      for {impl, name} <- @implementations do
        stream_id = unique_stream_id("#{name}-error")

        # Test various error conditions
        verify_error_handling(impl)

        # Test specific error cases
        assert {:error, _} = impl.read_stream_forward(stream_id, -1)
        assert {:error, _} = impl.read_stream_forward(stream_id, 0, 0)
        assert {:error, _} = impl.read_stream_forward(stream_id, 0, -1)
      end
    end

    test "transaction boundaries" do
      for {impl, name} <- @implementations do
        stream_id = unique_stream_id("#{name}-transaction")
        event = create_test_event()

        # Test successful transaction
        result = with_transaction impl, fn ->
          impl.append_to_stream(stream_id, 0, [event])
        end

        assert match?({:ok, _}, result)

        # Verify event was written
        assert {:ok, [read_event]} = impl.read_stream_forward(stream_id)
        assert read_event.data == event.data

        # Test failed transaction
        failed_result = with_transaction impl, fn ->
          case impl.append_to_stream(stream_id, 0, [event]) do
            {:error, _} = err -> err
            _ -> {:error, :expected_failure}
          end
        end

        assert match?({:error, _}, failed_result)
      end
    end
  end

  describe "performance characteristics" do
    test "batch operations" do
      events = for i <- 1..10, do: create_test_event(:"event_#{i}", %{value: "test#{i}"})

      for {impl, name} <- @implementations do
        stream_id = unique_stream_id("#{name}-batch")

        # Measure append time
        {append_time, {:ok, _}} = :timer.tc(fn ->
          impl.append_to_stream(stream_id, 0, events)
        end)

        # Measure read time
        {read_time, {:ok, _}} = :timer.tc(fn ->
          impl.read_stream_forward(stream_id)
        end)

        # Log performance metrics
        require Logger
        Logger.debug(fn ->
          "#{name} batch performance (μs):\n" <>
          "  append: #{append_time}\n" <>
          "  read: #{read_time}\n" <>
          "  total: #{append_time + read_time}"
        end)

        # Basic performance assertions
        assert append_time < 1_000_000, "#{name} append took too long"
        assert read_time < 1_000_000, "#{name} read took too long"
      end
    end

    test "concurrent read performance" do
      events = for i <- 1..5, do: create_test_event(:"event_#{i}")

      for {impl, name} <- @implementations do
        stream_id = unique_stream_id("#{name}-concurrent-read")

        # Setup test data
        assert {:ok, _} = impl.append_to_stream(stream_id, 0, events)

        # Test concurrent reads
        {total_time, results} = :timer.tc(fn ->
          test_concurrent_operations(impl, fn _i ->
            impl.read_stream_forward(stream_id)
          end)
        end)

        # Verify results
        assert Enum.all?(results, &match?({:ok, _}, &1))
        assert length(Enum.at(results, 0) |> elem(1)) == 5

        # Log performance
        require Logger
        Logger.debug("#{name} concurrent read time: #{total_time}μs")
      end
    end
  end
end
