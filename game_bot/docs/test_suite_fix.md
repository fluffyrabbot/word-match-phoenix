# Test Suite Stability Improvements

## Overview

This document outlines the improvements made to the test suite to resolve inconsistent test counts during sequential test runs. The original issue was that running `./run_tests.sh` multiple times in a row would yield different numbers of executed tests.

## Root Cause Analysis

After thorough investigation, we identified multiple interconnected issues:

1. **Database Connection Management**: 
   - Database connections from previous test runs weren't being fully cleaned up
   - New test runs were using unique timestamps but suffering from connection pool limits

2. **Repository Initialization**:
   - The `GameBot.Infrastructure.Persistence.Repo.Postgres` repository was defined separately but wasn't properly initialized in all cases
   - Error handling during repository initialization was insufficient

3. **Test Discovery and Execution**:
   - Tests that depend on database connections were failing early in the first run
   - As more connections became available in subsequent runs, more tests would pass
   - The test counter only counted tests that actually ran, not total tests

4. **EventStore Configuration**:
   - There were timing issues with EventStore initialization
   - Event store registrations weren't correctly synchronized

5. **Resource Cleanup**:
   - The cleanup process wasn't thoroughly clearing PostgreSQL connections
   - Old test databases weren't being dropped, causing resource leaks

## Solution Architecture

Our fix addresses each identified issue with a comprehensive solution:

### 1. Centralized Database Management

- **Implemented DatabaseHelper Module** (in `test/support/database_helper.ex`)
  - Centralizes all database operations in a single module
  - Manages repository initialization with proper error handling
  - Provides sandbox setup/teardown for tests
  - Includes retry mechanisms with exponential backoff
  - Verifies repository availability before test execution

### 2. Enhanced Connection Management

- **Implemented DatabaseConnectionManager** (in `test/support/database_connection_manager.ex`)
  - Dedicated module for database connection management
  - Provides graceful connection shutdown functions
  - Forceful connection termination as last resort
  - Terminates connections at PostgreSQL level when needed
  - Kills orphaned connection processes

### 3. Improved EventStore Testing

- **Fixed TestEventStore Implementation** (in `lib/game_bot/test_event_store.ex`)
  - Properly implements required EventStore behavior
  - Supports failure simulation for testing error cases
  - Includes configurable delay for testing asynchronous behavior
  - Manages streams and subscriptions in memory
  - Provides proper reset functionality

### 4. Enhanced Repository Case

- **Updated RepositoryCase Module** (in `test/support/repository_case.ex`)
  - Better repository initialization sequence
  - Improved error handling during checkout
  - Support for both mock and real repositories
  - Automatic cleanup of resources after tests
  - Better detection of test requirements

### 5. Robust Error Handling

- **Added Retry Mechanism**
  - Implementation of retry with exponential backoff
  - Logging of retry attempts for debugging
  - Proper error propagation
  - Timeout handling for long-running operations

## Technical Implementation Details

### Repository Initialization

The repository initialization now uses a proper sequence with retries:

```elixir
defp ensure_repositories_started do
  # Use a simple function to start each repository
  repos = [
    GameBot.Infrastructure.Persistence.Repo,
    GameBot.Infrastructure.Persistence.Repo.Postgres
  ]
  
  for repo <- repos do
    case start_repository(repo) do
      :ok -> :ok
      {:error, reason} -> raise "Failed to start repository #{inspect(repo)}: #{inspect(reason)}"
    end
  end
  
  :ok
end

defp start_repository(repo) do
  case repo.start_link([]) do
    {:ok, _pid} -> :ok
    {:error, {:already_started, _pid}} -> :ok
    error -> {:error, error}
  end
end
```

### Connection Cleanup

Improved connection termination using PostgreSQL-level operations:

```elixir
defp terminate_remaining_connections do
  query = """
  SELECT pg_terminate_backend(pid)
  FROM pg_stat_activity
  WHERE pid <> pg_backend_pid()
  AND (datname LIKE '%_test' OR datname LIKE '%_dev')
  """
  
  try do
    # Connect to postgres database (not our test database)
    {:ok, conn} = Postgrex.start_link([
      hostname: "localhost",
      username: "postgres", 
      password: "password", # From configuration
      database: "postgres",
      connect_timeout: 5000
    ])
    
    # Execute the termination query
    result = Postgrex.query!(conn, query, [])
    Logger.debug("Connection termination result: #{inspect(result)}")
    
    # Close our connection
    GenServer.stop(conn, :normal, 500)
  rescue
    e -> Logger.warning("Error terminating connections: #{inspect(e)}")
  end
end
```

### Mock Environment Detection

Added smarter detection of mock requirements to avoid database access when not needed:

```elixir
defp mock_test?(tags) do
  # First check if the individual test has the mock tag
  test_has_mock = tags[:mock] == true

  # Then check if the module has the mock tag
  module_has_mock = case tags[:registered] do
    %{} = registered ->
      registered[:mock] == true
    _ -> false
  end

  # Return true if either the test or the module has the mock tag
  test_has_mock || module_has_mock
end
```

### EventStore Implementation

Fixed the TestEventStore implementation to properly handle reset:

```elixir
def reset! do
  GenServer.call(__MODULE__, :reset_state)
end

def handle_call(:reset_state, _from, _state) do
  new_state = %State{
    streams: %{},
    failure_count: 0,
    delay: 0,
    subscriptions: %{}
  }
  {:reply, :ok, new_state}
end
```

## Remaining Work

While we've made significant progress, there are still items that need addressing:

1. **Complete EventStore Mock Implementation**:
   - Several required callbacks not implemented in `GameBot.Test.Mocks.EventStore`
   - Conflicting behavior implementations between GenServer and EventStore

2. **Standardize Configuration**:
   - Still some hardcoded values in various modules
   - Need to fully utilize the Config module for consistency

3. **Fix Type System Warnings**:
   - Address persistent type warnings in application code
   - Fix potential runtime errors due to mismatches

4. **Test Infrastructure Testing**:
   - Need better testing of the test infrastructure itself
   - Ensure reset functionality works reliably

## Benefits Achieved

1. **Improved Reliability**: Tests now run more consistently across multiple executions
2. **Better Resource Management**: Enhanced cleanup of database connections prevents resource exhaustion
3. **More Robust Error Handling**: Proper retry mechanisms and error propagation
4. **Enhanced Diagnostics**: Better logging and error reporting for troubleshooting

## Limitations and Known Issues

1. **Parallel Testing**: The solution currently performs better with serial tests (`async: false`) due to connection management complexity
2. **EventStore Mocks**: Still need to complete the mock implementations of all required behavior callbacks
3. **Reset Functionality**: Some edge cases with reset still need addressing for perfect reliability

## Next Steps

Please refer to the `testing_infrastructure_roadmap.md` document for a detailed plan on continuing improvements to the test infrastructure.

## Conclusion

The implemented improvements have addressed many core issues causing inconsistent test behavior. While not yet perfect, the solution provides a much more robust testing foundation with proper resource management, error handling, and cleanup procedures.

---

Document Last Updated: 2023-12-12 