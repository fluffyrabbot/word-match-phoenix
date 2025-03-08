# Database Connection Issues: Diagnosis and Fixes

## Problem Summary

The test environment was experiencing database connection issues, particularly with the EventStore tests. The issues included:

1. Timeouts when running tests (`client timed out because it queued and checked out the connection for longer than 15000ms`)
2. Connection exhaustion with multiple tests
3. Disconnections during test execution
4. Recursive anonymous function issues in test startup
5. Interrelated resource sharing problems across test runs

## Root Causes

After thorough analysis, we identified several root causes:

1. **Recursive Anonymous Function**: In `test_helper.exs`, an anonymous function was being used recursively which can lead to memory leaks and unstable behavior.
2. **Connection Management**: Insufficient cleanup of database connections between tests.
3. **Discord Bot Interference**: The Nostrum Discord bot was being started during tests, creating unnecessary connections.
4. **Timeouts**: Default timeouts were too long, causing connections to be held open.
5. **Resource Sharing**: Test cases were not properly isolated, leading to resource contention.
6. **Pool Configuration**: The connection pool settings were not optimized for the test environment.

## Implemented Fixes

### 1. Test Helper Improvements (`test_helper.exs`)

- Replaced recursive anonymous function with named function module `StartupHelpers`
- Added explicit configuration to disable Nostrum (Discord bot) during tests
- Configured mock API module for Nostrum integration
- Added explicit event store configuration to avoid warnings
- Implemented proper connection cleanup before tests start
- Added better error handling for database operations
- Started only essential applications for testing
- Added debugging output for better visibility into testing startup

```elixir
# Define a named function for repository startup with retries
defmodule StartupHelpers do
  def start_repo(repo, config, attempts) do
    try do
      IO.puts("Attempting to start #{inspect(repo)}")
      {:ok, _} = repo.start_link(config)
      IO.puts("Successfully started #{inspect(repo)}")
      :ok
    rescue
      e ->
        if attempts > 1 do
          IO.puts("Failed to start #{inspect(repo)}, retrying... (#{attempts-1} attempts left): #{inspect(e)}")
          Process.sleep(500)
          start_repo(repo, config, attempts - 1)
        else
          IO.puts("Failed to start #{inspect(repo)}: #{inspect(e)}")
          {:error, e}
        end
    end
  end
end
```

### 2. Simplified Test Implementation (`macro_integration_test.exs`)

- Made the test self-contained with explicit connection management
- Added helper functions to check out connections and clean up existing connections
- Set shorter timeout for database operations with `@db_timeout 5_000`
- Created unique stream IDs for each test run to prevent collisions
- Used explicit error handling for better diagnostics
- Made tests non-concurrent with `async: false`

```elixir
defp checkout_connection do
  # Check to see if the EventStore module is available
  if Process.whereis(EventStore) == nil do
    # Start the repository with a direct connection
    config = [
      username: "postgres",
      password: "csstarahid",
      hostname: "localhost",
      database: "game_bot_eventstore_test",
      port: 5432,
      pool: Ecto.Adapters.SQL.Sandbox,
      pool_size: 2,
      timeout: @db_timeout
    ]

    {:ok, _} = EventStore.start_link(config)
  end

  # Check it out for the test
  Ecto.Adapters.SQL.Sandbox.checkout(EventStore)
end

defp cleanup_existing_connections do
  # Close any existing Postgrex connections to prevent issues
  for pid <- Process.list() do
    info = Process.info(pid, [:dictionary])
    if info && get_in(info, [:dictionary, :"$initial_call"]) == {Postgrex.Protocol, :init, 1} do
      Process.exit(pid, :kill)
    end
  end

  # Small delay to allow processes to terminate
  Process.sleep(100)
end
```

### 3. Database Configuration Improvements (`config/test.exs`)

- Optimized database connection settings in the test environment
- Reduced timeout values to prevent holding connections
- Set conservative pool sizes appropriate for testing
- Added explicit configuration for event stores
- Configured separate test databases for app and event store

```elixir
# Configure the Postgres adapter for the EventStore
config :game_bot, GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres,
  username: "postgres",
  password: "csstarahid",
  hostname: "localhost",
  database: "game_bot_eventstore_test",
  port: 5432,
  types: EventStore.PostgresTypes,
  pool_size: 5,
  ownership_timeout: 15_000,
  queue_target: 200,
  queue_interval: 1000,
  timeout: 5000,
  connect_timeout: 5000
```

### 4. Enhanced Connection Helper (`test/support/connection_helper.ex`)

- Created more robust functions for connection cleanup
- Added support for multiple cleanup attempts
- Implemented process identification and cleanup logic
- Added safeguards with exception handling

```elixir
def close_db_connections do
  # Force close all connections first to prevent hanging
  close_postgrex_connections()

  # Attempt to reset the connection pool if it exists
  close_eventstore_connections()

  # Attempt to close any open connections for mock stores
  close_test_event_store()
  close_mock_event_store()

  # Sleep briefly to allow connections to be properly closed
  Process.sleep(100)

  :ok
end
```

### 5. Creating Targeted Test Cases

- Developed a simplified test (`simple_test.exs`) to isolate and verify functionality
- Created a custom mix task (`test_db.ex`) to verify database connectivity directly

## Verification

The fixes were verified by:

1. Successfully running the individual EventStore tests
2. Confirming database connectivity with the custom mix task
3. Verifying that the EventStore schema and tables exist and can be accessed
4. Testing basic database operations

## Lessons Learned

1. **Test Isolation**: Ensure each test properly isolates its resources.
2. **Connection Management**: Actively manage database connections in test environment.
3. **Named Functions Over Anonymous**: Use named functions for reliability and debugging.
4. **Timeout Management**: Use appropriate timeouts for test scenarios.
5. **Service Mocking**: Properly mock external services (like Nostrum) during tests.

## Future Considerations

The codebase still has numerous warnings that should be addressed for better code quality. A separate warning fix roadmap has been created to track these improvements. 