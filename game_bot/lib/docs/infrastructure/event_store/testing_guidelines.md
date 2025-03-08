# EventStore Testing Guidelines

## Overview

This document outlines the testing guidelines for the EventStore implementations in GameBot. It covers proper adapter integration, test setup, and best practices for ensuring reliable event storage and retrieval.

## Core Principles

1. **Proper Adapter Integration**
   - Follow Base adapter guidelines
   - Use correct behaviour implementations
   - Maintain clear separation of concerns

2. **Test Isolation**
   - Each test should start with a clean state
   - Use proper database cleanup
   - Avoid test interdependencies

3. **Comprehensive Coverage**
   - Test all EventStore operations
   - Verify error handling
   - Include performance tests
   - Validate concurrent operations

## Test Environment Setup

### 1. Configuration

```elixir
# config/test.exs
config :game_bot, GameBot.Infrastructure.EventStore,
  username: System.get_env("EVENT_STORE_USER", "postgres"),
  password: System.get_env("EVENT_STORE_PASS", "postgres"),
  database: System.get_env("EVENT_STORE_DB", "game_bot_eventstore_test"),
  hostname: System.get_env("EVENT_STORE_HOST", "localhost"),
  pool_size: 2
```

### 2. Test Case Structure

```elixir
defmodule GameBot.Test.EventStoreCase do
  use ExUnit.CaseTemplate

  alias EventStore.Storage.Initializer
  alias GameBot.Infrastructure.EventStore
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres

  using do
    quote do
      alias GameBot.Infrastructure.EventStore
      alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
      alias GameBot.TestEventStore
      
      import GameBot.Test.EventStoreCase
    end
  end

  setup do
    config = Application.get_env(:game_bot, EventStore)
    {:ok, conn} = EventStore.Config.parse(config)
    :ok = Initializer.reset!(conn, [])
    :ok
  end
end
```

## Testing Categories

### 1. Adapter Integration Tests

```elixir
describe "EventStore adapter integration" do
  test "core adapter implementation" do
    verify_adapter_implementation(EventStore)
    verify_adapter_behaviour(EventStore)
  end

  test "PostgreSQL implementation" do
    verify_adapter_implementation(Postgres)
    verify_adapter_behaviour(Postgres)
  end
end
```

### 2. Stream Operation Tests

```elixir
describe "stream operations" do
  test "append and read events" do
    events = [create_test_event(:event_1), create_test_event(:event_2)]
    
    assert {:ok, _} = EventStore.append_to_stream("test-stream", 0, events)
    assert {:ok, read_events} = EventStore.read_stream_forward("test-stream")
    assert length(read_events) == 2
  end

  test "concurrent operations" do
    results = test_concurrent_operations(EventStore, fn i ->
      EventStore.append_to_stream("test-stream", i - 1, [create_test_event()])
    end)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
  end
end
```

### 3. Error Handling Tests

```elixir
describe "error handling" do
  test "handles invalid stream operations" do
    assert {:error, _} = EventStore.append_to_stream(nil, 0, [])
    assert {:error, _} = EventStore.append_to_stream("stream", -1, [])
    assert {:error, _} = EventStore.read_stream_forward("stream", -1)
  end

  test "handles concurrent modifications" do
    event = create_test_event()
    assert {:ok, _} = EventStore.append_to_stream("stream", 0, [event])
    assert {:error, %Error{type: :concurrency}} = 
      EventStore.append_to_stream("stream", 0, [event])
  end
end
```

## Test Helpers

### 1. Event Creation

```elixir
def create_test_event(type \\ :test_event, data \\ %{value: "test"}) do
  %{event_type: type, data: data}
end

def create_test_stream(stream_id, events) do
  EventStore.append_to_stream(stream_id, :any, events)
end

def unique_stream_id(prefix \\ "test-stream") do
  "#{prefix}-#{System.unique_integer([:positive])}"
end
```

### 2. Verification Helpers

```elixir
def verify_adapter_implementation(module) do
  required_callbacks = [
    {:append_to_stream, 4},
    {:read_stream_forward, 4},
    {:subscribe_to_stream, 4},
    {:stream_version, 2}
  ]

  for {fun, arity} <- required_callbacks do
    assert function_exported?(module, fun, arity),
           "#{inspect(module)} must implement #{fun}/#{arity}"
  end
end

def verify_adapter_behaviour(module) do
  assert function_exported?(module, :init, 1),
         "#{inspect(module)} must implement init/1"
end
```

## Best Practices

### 1. Test Organization

- Group related tests in describe blocks
- Use meaningful test names
- Keep tests focused and concise
- Follow proper setup/teardown patterns

### 2. Async Testing

- Most EventStore tests should be async: false
- Use proper cleanup between tests
- Be careful with shared resources

### 3. Error Testing

- Test all error conditions
- Verify error messages and types
- Include concurrent error scenarios
- Test timeout and retry logic

### 4. Performance Testing

- Include basic performance benchmarks
- Test with realistic data volumes
- Verify concurrent performance
- Monitor memory usage

## Common Pitfalls

1. **Adapter Integration**
   - Missing behaviour callbacks
   - Incorrect error handling
   - Improper state management

2. **Test Isolation**
   - Insufficient cleanup between tests
   - Shared state issues
   - Missing transaction boundaries

3. **Error Handling**
   - Incomplete error coverage
   - Incorrect error types
   - Missing timeout handling

4. **Performance**
   - Insufficient load testing
   - Missing concurrent scenarios
   - Inadequate timeout settings

## Implementation Notes

### Required Tests

1. **Core Functionality**
   - Stream operations (append, read)
   - Subscription handling
   - Event serialization
   - Transaction management

2. **Error Scenarios**
   - Invalid operations
   - Concurrent modifications
   - Connection failures
   - Timeout handling

3. **Performance**
   - Basic operations
   - Concurrent access
   - Large event sets
   - Long-running operations

### Test Environment

1. **Database Setup**
   - Clean database for each test run
   - Proper schema initialization
   - Correct permissions

2. **Configuration**
   - Test-specific settings
   - Proper timeouts
   - Appropriate pool sizes

## Next Steps

1. Add missing adapter integration tests
2. Implement performance benchmarks
3. Add property-based tests
4. Expand error scenario coverage
5. Document remaining edge cases 