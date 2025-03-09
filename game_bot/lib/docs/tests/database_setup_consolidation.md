# Database Setup Consolidation Plan

## Current Issues

### 1. Multiple Database Setup Points
- `GameBot.Test.Setup` in test_helper.exs
- `GameBot.EventStoreCase`
- `GameBot.DataCase`
- `GameBotWeb.ConnCase`
- `Mix.Tasks.GameBot.TestSetup`

Each module has its own database initialization logic, leading to:
- Race conditions
- Inconsistent cleanup
- Connection leaks
- Sandbox mode conflicts

### 2. Database Connection Issues
- Connections not being properly cleaned up between tests
- Inconsistent timeout values across modules
- Multiple modules trying to manage the same connections
- No clear ownership of connection lifecycle

### 3. Repository Management Problems
- Multiple places starting repositories
- Inconsistent repository configurations
- Race conditions in repository initialization
- No clear error handling strategy

### 4. Sandbox Configuration Conflicts
- Different modules setting sandbox mode
- Inconsistent timeout values
- Potential conflicts in ownership modes
- No standardized approach to async tests

## Implementation Plan

### Phase 1: Create Centralized Database Helper

1. Create new module `GameBot.Test.DatabaseHelper`:
   ```elixir
   defmodule GameBot.Test.DatabaseHelper do
     @moduledoc """
     Centralized database management for tests.
     Handles all database operations, connection management,
     and sandbox configuration.
     """
   end
   ```

2. Define core responsibilities:
   - Database creation/cleanup
   - Connection management
   - Repository initialization
   - Sandbox configuration
   - Error handling

### Phase 2: Standardize Configuration

1. Move all database configuration to a single location:
   - Timeouts
   - Pool settings
   - Sandbox options
   - Repository configurations

2. Define standard timeout values:
   ```elixir
   @db_timeout 15_000
   @checkout_timeout 30_000
   @ownership_timeout 60_000
   ```

### Phase 3: Implement Core Functions

1. Database Lifecycle Management:
   ```elixir
   def initialize_test_databases()
   def cleanup_test_databases()
   def ensure_repositories_started()
   ```

2. Connection Management:
   ```elixir
   def setup_sandbox(tags)
   def cleanup_connections()
   def checkout_repositories(repos, opts)
   ```

3. Error Handling:
   ```elixir
   def handle_connection_error(error)
   def handle_repository_error(error)
   ```

### Phase 4: Migration Strategy

1. Update existing test cases:
   - Replace direct database calls with DatabaseHelper
   - Remove duplicate initialization code
   - Standardize on single configuration source

2. Update test setup modules:
   ```elixir
   # In test_helper.exs
   GameBot.Test.DatabaseHelper.initialize_test_environment()

   # In DataCase
   use GameBot.Test.DatabaseHelper, async: true

   # In EventStoreCase
   use GameBot.Test.DatabaseHelper, 
     repos: [EventStore, Repo],
     async: true
   ```

### Phase 5: Cleanup & Verification

1. Remove deprecated code:
   - Old initialization functions
   - Duplicate configurations
   - Unused connection management

2. Add verification:
   - Connection leak detection
   - Repository state verification
   - Sandbox mode validation

## Implementation Order

1. Create DatabaseHelper module with core structure
2. Implement connection management functions
3. Add repository initialization logic
4. Create sandbox configuration functions
5. Update test helper and case modules
6. Remove deprecated code
7. Add verification and monitoring
8. Update documentation

## Success Criteria

1. All tests pass consistently
2. No connection leaks between tests
3. Proper cleanup after test runs
4. Consistent sandbox behavior
5. Clear error messages for database issues
6. Proper async test support
7. No duplicate initialization

## Monitoring & Verification

1. Add logging for database operations:
   ```elixir
   def log_database_operation(operation, result) do
     Logger.debug("Database operation: #{operation}, Result: #{inspect(result)}")
   end
   ```

2. Add connection monitoring:
   ```elixir
   def monitor_connections(repo) do
     # Monitor active connections
     # Track connection lifecycle
     # Report leaks
   end
   ```

3. Add repository state verification:
   ```elixir
   def verify_repository_state(repo) do
     # Check repository is running
     # Verify correct pool configuration
     # Validate sandbox mode
   end
   ```

## Rollback Plan

1. Keep old implementation in separate modules
2. Add feature flag for new implementation
3. Allow gradual migration of test cases
4. Maintain backward compatibility during transition

## Notes

- All timeouts should be configurable
- Error messages should be clear and actionable
- Logging should be comprehensive but not noisy
- Async tests should be properly supported
- Connection cleanup should be aggressive
- Repository state should be verifiable 