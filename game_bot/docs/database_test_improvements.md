# Database Test Infrastructure Improvements

## Current Issues
- [x] Multiple database creation points leading to proliferation of test databases
- [x] Timestamp-based naming causing new databases on every test run
- [x] Incomplete cleanup after test runs
- [x] Async test issues with database access
- [x] Inconsistent database management approaches

## Implementation Roadmap

### 1. Standardize Database Names
- [x] Define fixed database names in a central configuration
  ```elixir
  @main_test_db "game_bot_test"
  @event_test_db "game_bot_eventstore_test"
  ```
- [x] Remove timestamp-based naming from all modules
- [x] Update configuration files to use fixed names
- [x] Add documentation for standard database naming convention

### 2. Centralize Database Creation
- [x] Create a new `GameBot.Test.DatabaseManager` module
  - [x] Implement database creation functions
  - [x] Implement cleanup functions
  - [x] Add connection pooling support
  - [x] Add transaction management
- [x] Remove database creation code from:
  - [x] `setup_test_db.sh`
  - [x] `Mix.Tasks.GameBot.Test`
  - [x] `GameBot.Test.DatabaseSetup`
  - [x] Individual test cases
- [x] Update `test_helper.exs` to use the new manager
- [x] Add proper error handling and logging

### 3. Improve Cleanup Process
- [x] Implement robust cleanup in `DatabaseManager`:
  - [x] Process exit handlers
  - [x] Interrupt handlers
  - [x] Periodic cleanup of stale databases
- [x] Add cleanup verification
  - [x] Check for lingering connections
  - [x] Verify database deletion
  - [x] Log cleanup results
- [x] Implement cleanup retries with exponential backoff
- [x] Add emergency cleanup for test suite crashes

### 4. Database Pooling for Async Tests
- [x] Implement connection pooling:
  - [x] Configure pool size based on test parallelism
  - [x] Add connection checkout/checkin system
  - [x] Implement deadlock prevention
- [x] Add transaction isolation:
  - [x] Sandbox mode for each test
  - [x] Proper rollback after each test
- [x] Handle async test coordination:
  - [x] Test process registration
  - [x] Resource cleanup tracking
  - [x] Connection ownership management

### 5. Migration and Rollout
- [ ] Create database migration scripts
- [ ] Update test suite configuration
- [ ] Add documentation for new test patterns
- [ ] Create examples for common test scenarios
- [ ] Add monitoring and diagnostics

## Success Criteria
- [x] No duplicate test databases created
- [x] All databases properly cleaned up after tests
- [x] Async tests running without conflicts
- [ ] Reduced test suite execution time
- [x] Improved error messages and debugging
- [x] Complete documentation coverage

## Monitoring and Maintenance
- [ ] Add database usage metrics
- [x] Implement automatic cleanup of old test databases
- [ ] Add periodic health checks
- [x] Create maintenance documentation

## Notes
- Keep existing database names during transition
- Maintain backwards compatibility where possible
- Add proper logging throughout the process
- Consider CI/CD pipeline impacts 