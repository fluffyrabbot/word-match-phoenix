# Asynchronous Test Strategy

## Current Status and Future Vision

As of now, our test suite primarily uses non-asynchronous tests to ensure database stability and prevent connection ownership issues. This document outlines a strategy for a future transition to a fully asynchronous test suite when appropriate.

## Prerequisites for Async Testing

Before transitioning to async tests, ensure:

1. **Database Connection Pooling**: Properly sized connection pools for concurrent testing
2. **Sandbox Management**: Correct implementation of ownership tracking
3. **Test Isolation**: Each test must be fully isolated with no shared state
4. **Resource Management**: Appropriate tracking and cleaning of resources
5. **Transaction Boundaries**: Clear definition of transaction scopes

## Implementation Strategy

### Phase 1: Foundation (Current Approach)

Our current approach prioritizes stability using non-async tests:

```elixir
# Current pattern - stable but sequential
use GameBot.RepositoryCase, async: false

setup tags do
  :ok = GameBot.Test.DatabaseManager.setup_sandbox(tags)
  :ok
end
```

This approach is reliable but sacrifices execution speed for stability.

### Phase 2: Limited Async Testing

For tests with minimal database interaction:

```elixir
# Limited async pattern for lightweight tests
use GameBot.RepositoryCase, async: true

setup tags do
  :ok = GameBot.Test.DatabaseManager.setup_sandbox(tags)
  :ok
end
```

Apply this pattern selectively to tests that:
- Have minimal database interactions
- Don't create/drop tables or schemas
- Don't perform complex transactions

### Phase 3: Full Async Implementation

When ready for full async, implement:

```elixir
# Full async implementation
defmodule GameBot.Test.AsyncDatabaseManager do
  # Enhanced sandbox setup with connection ownership tracking
  def async_setup_sandbox(tags) do
    # Checkout connection with proper ownership
    conn = Sandbox.checkout(Repo, ownership_timeout: 60_000)
    
    # Track the connection with the current test process
    Sandbox.mode(Repo, {:shared, self()})
    
    # Allow selected child processes to access the connection
    Sandbox.allow(Repo, self(), Process.whereis(OtherProcess))
    
    {:ok, conn}
  end
  
  # Other connection management functions
end
```

## Connection Pooling for Async Tests

### Pool Size Calculation

For async tests, use this formula to determine optimal pool size:

```
pool_size = max_concurrent_tests * repos_per_test * buffer_factor
```

Where:
- `max_concurrent_tests`: Value of `max_cases` in test_helper.exs
- `repos_per_test`: Number of repos used in each test (usually 2: main DB and event store)
- `buffer_factor`: Safety margin (1.5 recommended)

Example: `10 * 2 * 1.5 = 30` connections

### Configuration Example

```elixir
# In config/test.exs
config :game_bot, GameBot.Infrastructure.Persistence.Repo,
  pool_size: optimal_pool_size,
  queue_target: 200,
  queue_interval: 1000,
  ownership_timeout: 60_000
```

## Database Ownership Management

### Ownership Modes

Three primary modes to consider:

1. **Manual Mode**: `Sandbox.mode(Repo, :manual)`
   - Explicit checkout/checkin required
   - Highest isolation, most verbose

2. **Shared Mode**: `Sandbox.mode(Repo, {:shared, self()})`
   - Connection shared between processes
   - Good for tests with background tasks

3. **Auto Mode**: `Sandbox.mode(Repo, :auto)`
   - Automatic checkout/checkin
   - Least isolation, most convenient

### Process Hierarchy Management

For tests with child processes:

```elixir
# Parent test process
setup tags do
  conn = GameBot.Test.AsyncDatabaseManager.async_setup_sandbox(tags)
  
  # Spawn child process
  child_pid = spawn_supervised(MyChildProcess)
  
  # Allow child to use the parent's connection
  Sandbox.allow(Repo, self(), child_pid)
  
  {:ok, %{conn: conn, child: child_pid}}
end
```

## Test Organization for Async Success

### Module Boundaries

Group tests by database interaction patterns:

1. **Read-Only Tests**: Can be fully async
2. **Write-Only Tests**: Can be async with proper sandboxing
3. **Schema-Altering Tests**: Should remain non-async

### Test File Organization

```elixir
defmodule GameBot.ReadOnlyTests do
  use GameBot.RepositoryCase, async: true
  # Read-only tests
end

defmodule GameBot.WriteTests do
  use GameBot.RepositoryCase, async: true
  # Write tests with proper isolation
end

defmodule GameBot.SchemaTests do
  use GameBot.RepositoryCase, async: false
  # Schema-altering tests
end
```

## Rollout Strategy

1. **Metric Gathering**: Establish baseline test performance metrics
2. **Categorization**: Group tests by database interaction patterns
3. **Incremental Conversion**: Convert categories in this order:
   - Read-only tests
   - Simple write tests
   - Complex write tests
   - Schema-altering tests (may remain non-async)
4. **Continuous Monitoring**: Track connection usage and test reliability
5. **Periodic Review**: Regularly evaluate async test performance

## Monitoring and Troubleshooting

### Key Metrics to Monitor

1. **Connection Usage**: Track high-water mark for pool use
2. **Test Duration**: Compare async vs. non-async execution time
3. **Flakiness Rate**: Track tests that occasionally fail
4. **Connection Errors**: Monitor for ownership errors

### Common Issues and Solutions

| Issue | Symptoms | Solution |
|-------|----------|----------|
| Connection Starvation | Tests timeout waiting for connection | Increase pool size or reduce max_cases |
| Ownership Errors | DBConnection.OwnershipError | Verify sandbox setup and allow calls |
| Dirty Rollbacks | Tests affecting other tests | Ensure proper test isolation in teardown |
| Timeouts | Tests hanging | Adjust ownership_timeout in config |

## Migration Checklist

- [ ] Update DatabaseManager with async support
- [ ] Adjust connection pool size
- [ ] Categorize tests by database interaction pattern
- [ ] Convert read-only tests to async
- [ ] Implement process tracking for cleanup
- [ ] Add connection usage metrics
- [ ] Monitor test execution time and reliability
- [ ] Periodically review and tune configuration

## Current Limitations

Until full async implementation is complete:
- Most database-intensive tests should use `async: false`
- Tests that create/drop tables must use `async: false`
- Tests with complex transactions should use `async: false`
- Monitor for DBConnection.OwnershipError to identify problematic tests

## Additional Resources

- [Ecto SQL Sandbox Documentation](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html)
- [Elixir Forum - Async Tests](https://elixirforum.com/t/how-to-use-async-true-in-tests-with-ecto/6583)
- [Testing Phoenix - Real-World Ecto](https://pragprog.com/titles/lhelph/testing-elixir/) 