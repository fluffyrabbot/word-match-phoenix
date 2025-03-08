defmodule GameBot.Test.EventStoreCase do
  @moduledoc """
  Test case for EventStore macro integration testing.

  This module provides helpers and utilities for testing EventStore implementations,
  ensuring proper macro integration and behavior compliance.

  ## Features
  - Common test setup for EventStore implementations
  - Helpers for testing macro-generated functions
  - Validation of behavior compliance
  - Stream manipulation utilities

  ## Usage

  ```elixir
  defmodule MyTest do
    use GameBot.Test.EventStoreCase
    use ExUnit.Case, async: false  # EventStore tests should not be async

    test "my event store test" do
      # Your test code here
    end
  end
  ```

  ## Important Notes

  1. EventStore tests should NOT be async due to shared database state
  2. Always clean up resources (subscriptions, etc.) after tests
  3. Use the provided helpers for common operations
  4. Follow proper transaction boundaries
  """

  use ExUnit.CaseTemplate

  alias EventStore.Storage.Initializer
  alias GameBot.Infrastructure.EventStore
  alias GameBot.Infrastructure.Persistence.EventStore.Postgres

  using do
    quote do
      alias GameBot.Infrastructure.EventStore
      alias GameBot.Infrastructure.Persistence.EventStore.Postgres
      alias GameBot.TestEventStore
      alias GameBot.Test.Mocks.EventStore, as: MockEventStore

      import GameBot.Test.EventStoreCase

      # Common test data
      @test_stream_id "test-stream"
      @test_event %{event_type: :test_event, data: %{value: "test"}}
    end
  end

  @doc """
  Resets the event store to a clean state.
  This is the recommended way to reset the event store between tests.
  """
  def reset_event_store! do
    config = Application.get_env(:game_bot, EventStore)
    {:ok, conn} = EventStore.Config.parse(config)
    :ok = Initializer.reset!(conn, [])
  end

  @doc """
  Creates a test event with the given type and data.
  """
  def create_test_event(type \\ :test_event, data \\ %{value: "test"}) do
    %{event_type: type, data: data}
  end

  @doc """
  Creates a test stream with the given events.
  """
  def create_test_stream(stream_id, events) do
    EventStore.append_to_stream(stream_id, :any, events)
  end

  @doc """
  Generates a unique stream ID for testing.
  """
  def unique_stream_id(prefix \\ "test-stream") do
    "#{prefix}-#{System.unique_integer([:positive])}"
  end

  @doc """
  Verifies that a module properly implements the EventStore behavior.
  """
  def verify_event_store_implementation(module) do
    # Required callbacks from EventStore behavior
    required_callbacks = [
      {:init, 1},
      {:append_to_stream, 4},
      {:read_stream_forward, 4},
      {:read_stream_backward, 4},
      {:subscribe_to_stream, 3},
      {:subscribe_to_all_streams, 3},
      {:ack, 2},
      {:unsubscribe, 1}
    ]

    for {fun, arity} <- required_callbacks do
      assert function_exported?(module, fun, arity),
             "#{inspect(module)} must implement #{fun}/#{arity}"
    end
  end

  @doc """
  Verifies that a module properly uses the EventStore macro.
  """
  def verify_event_store_macro_usage(module) do
    # Check for macro-generated functions
    assert function_exported?(module, :config, 0),
           "#{inspect(module)} must use EventStore macro which generates config/0"

    # Verify @impl annotations
    module_info = module.module_info(:attributes)
    impl_functions = for {:impl, [{true, _}]} <- module_info, do: true
    assert length(impl_functions) > 0,
           "#{inspect(module)} must use @impl true for behavior callbacks"
  end

  @doc """
  Verifies that a module follows proper macro integration guidelines.
  """
  def verify_macro_integration_guidelines(module) do
    # Check module documentation
    assert Code.fetch_docs(module),
           "#{inspect(module)} must have proper documentation"

    # Verify no conflicting function implementations
    refute function_exported?(module, :ack, 1),
           "#{inspect(module)} should not implement ack/1 (conflicts with macro)"
    refute function_exported?(module, :config, 1),
           "#{inspect(module)} should not implement config/1 (conflicts with macro)"
  end

  @doc """
  Sets up a clean event store state for testing.
  """
  setup do
    # Start the event store if it's not already started
    start_supervised!(EventStore)

    # Reset to a clean state
    :ok = reset_event_store!()

    :ok
  end

  @doc """
  Verifies proper error handling in an event store implementation.
  """
  def verify_error_handling(module) do
    # Test invalid stream ID
    assert {:error, _} = module.append_to_stream(nil, 0, [create_test_event()])

    # Test invalid version
    assert {:error, _} = module.append_to_stream("test-stream", -1, [create_test_event()])

    # Test empty events list
    assert {:error, _} = module.append_to_stream("test-stream", 0, [])
  end

  @doc """
  Helper for testing concurrent operations.
  """
  def test_concurrent_operations(module, operation_fn, num_tasks \\ 5) do
    tasks = for i <- 1..num_tasks do
      Task.async(fn -> operation_fn.(i) end)
    end

    Task.await_many(tasks)
  end

  @doc """
  Helper for testing subscriptions.
  """
  def with_subscription(module, stream_id, subscriber, fun) do
    {:ok, subscription} = module.subscribe_to_stream(stream_id, subscriber)

    try do
      fun.(subscription)
    after
      :ok = module.unsubscribe_from_stream(stream_id, subscription)
    end
  end

  @doc """
  Helper for testing transactions.
  """
  def with_transaction(module, fun) do
    module.transaction(fn ->
      case fun.() do
        {:ok, result} -> result
        {:error, _} = err -> err
      end
    end)
  end
end
