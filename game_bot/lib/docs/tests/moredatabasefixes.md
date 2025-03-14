# Database Test Failures: Analysis and Fixes Checklist

This document provides a comprehensive analysis of the persistent database test failures
and establishes a checklist of fixes to address these issues.

## Root Causes Analysis

### 1. Process Management Issues ✓

- [x] Repository processes are terminating prematurely during test execution
- [x] The error "could not lookup Ecto repo..." indicates repository processes are not available
- [x] Warning messages about exits when stopping repositories confirm this issue
- [x] `start_repo` function lacks robust error handling and retry mechanisms

### 2. Race Conditions During Repository Initialization ✓

- [x] Timing issues exist in test setup where database operations occur before repos are fully initialized
- [x] Unreliable `Process.sleep(100)` calls used as synchronization mechanism
- [x] Insufficient timeouts in `wait_for_process_initialization` (1000ms may not be enough)
- [x] Lack of proper synchronization mechanisms to confirm repository readiness

### 3. Connection Pool Mismanagement ✓

- [x] Issues with checkout/checkin operations in the Sandbox connection pool
- [x] Connection cleanup may be too aggressive between tests
- [x] Consistent errors across multiple test modules indicate systemic connection management issues
- [x] Insufficient handling of connection timeouts and drops

### 4. Supervisor Hierarchy Issues ⏳

- [ ] Repositories are being terminated unexpectedly by their supervisors
- [ ] Warning messages show shutdown signals from supervisors: `{:shutdown, {:sys, :terminate, ...}}`
- [ ] Repositories might be under the wrong supervisor or have incorrect restart strategies
- [x] Improper supervision tree structure for test environments

### 5. Sandbox Mode Configuration Issues ✓

- [x] Sandbox mode for transactions is not properly established
- [x] Transaction-related tests (e.g., concurrent deletions) are failing
- [x] Sandbox mode setup doesn't ensure all repos are correctly configured
- [x] Incomplete error handling in sandbox setup

### 6. Authentication and Configuration Issues ✓

- [x] Hardcoded password mismatch in diagnostic and repair functions
- [x] Inconsistent database credentials across different modules
- [x] Missing fully qualified module name references (e.g., Sandbox vs Ecto.Adapters.SQL.Sandbox)
- [x] Configuration parameters not consistently applied across repositories

## Implementation Checklist

### Process Management Improvements

- [x] Add robust retry mechanisms to `start_repo` function
  - [x] Implement exponential backoff
  - [x] Add appropriate logging for each retry attempt
  - [x] Set reasonable maximum retry limits
- [x] Enhance process monitoring for repositories
  - [x] Replace simple PID checks with proper state verification
  - [x] Implement bidirectional monitoring between dependent processes
- [x] Improve error handling in repository operations
  - [x] Capture and log detailed error information
  - [x] Implement appropriate recovery actions for different error types

### Race Condition Fixes

- [x] Replace `Process.sleep` calls with proper synchronization primitives
  - [x] Use process monitors and messaging instead of timing-based approaches
  - [x] Implement ready-check mechanisms for repository processes
- [x] Create explicit process startup sequence with validation
  - [x] Verify each step completes successfully before proceeding
  - [x] Add health checks between critical startup phases
- [x] Implement proper timeouts for database operations
  - [x] Use longer timeouts for initialization operations
  - [x] Scale timeouts based on operation complexity

### Connection Pool Management

- [x] Refactor connection checkout/checkin procedures
  - [x] Add proper error handling for connection failures
  - [x] Implement connection verification before use
- [x] Improve connection pool cleanup between tests
  - [x] Ensure connections are properly released after each test
  - [x] Add recovery mechanisms for leaked connections
- [x] Implement connection health monitoring
  - [x] Add periodic verification of pool connections
  - [x] Implement automatic recovery for stale connections

### Supervisor Hierarchy Fixes

- [ ] Review and restructure supervision tree
  - [ ] Ensure repositories have appropriate supervisors
  - [ ] Implement proper restart strategies for test environments
- [x] Add more robust process termination handling
  - [x] Implement graceful shutdown procedures
  - [x] Ensure child processes terminate properly

### Sandbox Mode Improvements

- [x] Enhance sandbox mode configuration
  - [x] Verify sandbox mode is properly established before tests
  - [x] Add validation checks for sandbox mode status
- [x] Improve transaction boundary handling
  - [x] Ensure transactions are properly isolated
  - [x] Add better cleanup for abandoned transactions
- [x] Implement repository status verification
  - [x] Check repository status before each test
  - [x] Add automatic recovery for unavailable repositories

### Configuration Consistency Fixes

- [x] Standardize database credentials across modules
  - [x] Replace hardcoded values with centralized configuration
  - [x] Ensure password consistency throughout the codebase
- [x] Use fully qualified module references
  - [x] Replace direct `Sandbox` references with `Ecto.Adapters.SQL.Sandbox`
  - [x] Fix other module reference issues affecting sandbox mode

## Testing and Validation

- [x] Create specific tests for database initialization
  - [x] Test repository startup/shutdown sequences
  - [x] Test connection pool behavior
- [x] Implement improved diagnostics 
  - [x] Add detailed logging for all database operations
  - [x] Create health check utilities for repositories
- [x] Add automated verification steps before test suite execution
  - [x] Verify database availability
  - [x] Check repository configuration

## Implementation Progress

### Completed
1. ✅ Enhanced `start_repo` function with robust retry and health checks
2. ✅ Improved `setup_sandbox` with comprehensive error handling and recovery
3. ✅ Created `DatabaseDiagnostics` module for troubleshooting
4. ✅ Added automated diagnostic and repair tools via mix task
5. ✅ Implemented process monitoring with proper synchronization
6. ✅ Added connection verification and recovery mechanisms
7. ✅ Enhanced repository health checking and recovery
8. ✅ Fixed inconsistent database credentials across modules
9. ✅ Updated references to use fully qualified module names
10. ✅ Standardized database configuration with centralized parameters
11. ✅ Created mix task for database diagnostics and repair

### Remaining
1. ⏳ Analyze and fix supervisor hierarchy issues
2. ⏳ Create dedicated tests for database startup/shutdown sequences
3. ⏳ Review and optimize existing code for edge cases

## Lessons Learned

1. **Consistent Configuration**: Maintaining consistent configuration across modules is critical, especially for credentials
2. **Fully Qualified Names**: Always use fully qualified module names for external dependencies to avoid confusion
3. **Health Checks**: Comprehensive health checking and recovery mechanisms are essential for database reliability
4. **Centralized Diagnostics**: Having centralized diagnostic tools greatly simplifies troubleshooting
5. **Proper Password Management**: Avoid hardcoding passwords directly in functions, use centralized configuration

## References

- Error message: "could not lookup Ecto repo GameBot.Infrastructure.Persistence.Repo.Postgres because it was not started or it does not exist"
- Warning message: "Exit when stopping GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres"
- Warning message: "Exit when stopping GameBot.Infrastructure.Persistence.Repo"
- Fixed tests: PostgresTest, TransactionTest 