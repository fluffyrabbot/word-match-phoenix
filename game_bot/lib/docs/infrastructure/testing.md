# Infrastructure Testing Guide

## Overview

The infrastructure layer testing is organized into several levels:

1. Unit Tests - Testing individual components
2. Integration Tests - Testing component interactions
3. Property Tests - Testing invariants and edge cases

## Test Organization

```
test/
├── support/
│   ├── repository_case.ex     # Common test helpers
│   └── mocks/
│       └── event_store.ex     # Mock implementations
└── game_bot/
    └── infrastructure/
        └── persistence/
            ├── event_store/   # Event store tests
            └── repo/         # Repository tests
```

## Mock Implementations

### Event Store Mock

The `GameBot.Test.Mocks.EventStore` provides a controlled testing environment:

```elixir
# Configure failure scenarios
EventStore.set_failure_count(2)  # Fail next 2 operations
EventStore.set_delay(50)         # Add 50ms delay to operations

# Reset state between tests
EventStore.reset_state()
```

Features:
- Simulated failures
- Controlled delays
- In-memory storage
- Subscription handling
- Concurrent operation testing

## Unit Testing

### Event Store Components

1. **Serializer Tests**
   ```elixir
   describe "serialize/1" do
     test "successfully serializes valid event"
     test "returns error for invalid structure"
     property "serialization is reversible"
   end
   ```

2. **Postgres Implementation Tests**
   ```elixir
   describe "append_to_stream/4" do
     test "successfully appends events"
     test "handles concurrent modifications"
   end
   ```

3. **Adapter Tests**
   ```elixir
   describe "retry mechanism" do
     test "retries on connection errors"
     test "respects timeout settings"
   end
   ```

### Repository Tests

1. **Transaction Tests**
   ```elixir
   describe "transaction/1" do
     test "successfully executes transaction"
     test "rolls back on error"
   end
   ```

2. **CRUD Operation Tests**
   ```elixir
   describe "insert/2" do
     test "successfully inserts valid record"
     test "handles validation errors"
   end
   ```

## Integration Testing

### Event Store Integration

Tests interactions between components:
- Serializer → Postgres → Adapter
- Error propagation
- Retry mechanisms
- Transaction boundaries

### Repository Integration

Tests interactions with:
- Event Store
- Concurrent operations
- Transaction isolation

## Test Helpers

### RepositoryCase

```elixir
use GameBot.Test.RepositoryCase, async: true

# Provides:
build_test_event()      # Create test events
unique_stream_id()      # Generate unique IDs
```

## Best Practices

1. **Test Setup**
   - Use `setup` blocks for common initialization
   - Clean up test data after each test
   - Reset mock state between tests

2. **Async Testing**
   - Mark tests as `async: true` when possible
   - Use unique IDs to prevent conflicts
   - Be careful with shared resources

3. **Error Testing**
   - Test all error conditions
   - Verify error types and details
   - Test error recovery mechanisms

4. **Property Testing**
   - Use for serialization/deserialization
   - Test with generated data
   - Verify invariants hold 

## Enhanced Error Handling Tests

Our error handling tests verify:

```elixir
# Test enhanced error context
test "provides detailed context for concurrency errors" do
  stream_id = unique_stream_id()
  # Set up concurrency error scenario
  # Verify error contains stream_id, expected_version, etc.
end

# Test retry mechanism
test "retries with exponential backoff on connection errors" do
  stream_id = unique_stream_id()
  # Configure mock to fail multiple times then succeed
  # Verify operation succeeds after retries
  # Verify delay increases exponentially
end
```

## Transaction Boundary Tests

Our transaction tests verify:

```elixir
# Test transaction isolation
test "rolls back all operations when any operation fails" do
  # Perform multiple operations where one fails
  # Verify all changes are rolled back
end

# Test transaction timeout
test "respects transaction timeout" do
  # Set up long-running transaction
  # Verify it fails with timeout error
end
``` 