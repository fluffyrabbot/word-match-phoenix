# Repository Initialization Fixes Checklist

This document provides a detailed checklist for implementing solutions to the repository initialization issues identified in the test infrastructure. These issues primarily affect test stability, causing repositories to fail to start or stay connected properly during test execution.

## Issue Context

The GameBot test infrastructure suffers from several issues related to repository initialization:

1. **Inconsistent Process Startup**: Different test modules start repositories in different ways
2. **Race Conditions**: Multiple tests attempting to manipulate the same repositories 
3. **Missing Process Registration**: Processes not properly registered, causing crashes
4. **Event Store Reset Issues**: State not properly reset between tests
5. **Missing Mock Implementations**: Required mocks not implemented
6. **Function Parameter Conflicts**: Conflicting default parameters causing errors

## Implementation Checklist

### 1. Standardize Repository Initialization - HIGH PRIORITY

- [x] **1.1 Create Initialization Dependency Graph**
  - [x] Identify all required components and their dependencies
  - [x] Document the correct initialization order
  - [x] Create a centralized initialization function that follows this order

- [x] **1.2 Update `DatabaseHelper.initialize/0`**
  - [x] Ensure it handles already-running repositories gracefully
  - [x] Add explicit checks for repository health after initialization
  - [x] Add proper error reporting for initialization failures
  - [x] Implement startup synchronization to prevent race conditions

- [ ] **1.3 Remove Duplicate Initialization Code**
  - [x] Find and remove duplicate initialization code in test setup blocks
  - [x] Replace with references to the centralized helper functions
  - [x] Update `EventStoreAccessTest` to use the centralized initialization
  - [ ] Update other test modules to use the standardized initialization approach

- [x] **1.4 Add Environment Validation**
  - [x] Implement pre-test validation of the environment
  - [x] Add checks to verify repositories are properly started
  - [x] Include database connectivity verification

### 2. Fix Process Management - HIGH PRIORITY

- [x] **2.1 Enhance Process Monitoring**
  - [x] Improve the `monitor_process/1` function to be more reliable
  - [x] Create a global process registry to track all test-related processes
  - [x] Implement proper cleanup for monitored processes

- [x] **2.2 Fix Process Registration**
  - [x] Update `GameBot.Test.Mocks.EventStore.start_link/1` to handle existing processes
  - [x] Implement proper process name conflict resolution
  - [x] Add safeguards to prevent multiple registrations

- [x] **2.3 Implement Graceful Process Restart**
  - [x] Add code to gracefully stop existing processes before starting new ones
  - [x] Implement proper state transfer during restarts
  - [x] Add timeout handling for process operations

- [x] **2.4 Add Process State Validation**
  - [x] Implement validation functions to check process state before operations
  - [x] Add health check functions for critical processes
  - [x] Create recovery mechanisms for unhealthy processes

### 3. Create Missing Mock Implementations - HIGH PRIORITY

- [x] **3.1 Implement `MockEventStoreAccess`**
  - [x] Create module with same API as `GameBot.Replay.EventStoreAccess`
  - [x] Implement all required functions with appropriate mock behavior
  - [x] Add state management for controlling test behavior
  - [x] Add functions for setting up test scenarios

- [x] **3.2 Implement `MockSubscriptionManager`**
  - [x] Create module following the same pattern as other mocks
  - [x] Implement required subscription management functions
  - [x] Add state management for controlling test behavior

- [x] **3.3 Standardize Mock Approach**
  - [x] Decide between `:meck` and custom mock modules
  - [x] Update existing mocks to follow the standard approach
  - [x] Provide helper functions for setting up and tearing down mocks

### 4. Fix Function Parameter Conflicts - HIGH PRIORITY

- [x] **4.1 Update Function Definitions**
  - [x] Remove default parameters from functions with multiple arities
  - [x] Create separate function bodies for each arity
  - [x] Ensure proper delegation between interface and core functions

- [x] **4.2 Fix Parameter Handling**
  - [x] Ensure consistent parameter handling across all modules
  - [x] Add type specifications to clarify parameter types
  - [x] Fix `opts` parameter handling in core functions

- [x] **4.3 Update Interface Modules**
  - [x] Ensure proper delegation in all interface modules
  - [x] Add proper @impl annotations to clarify behavior implementation
  - [x] Fix function signatures to match behavior expectations

### 5. Improve Event Store Reset Mechanism - MEDIUM PRIORITY

- [x] **5.1 Enhance Reset Functions**
  - [x] Improve `reset_state` to handle all state aspects
  - [x] Add comprehensive error handling to reset operations
  - [x] Implement validation to confirm reset was successful

- [x] **5.2 Standardize Reset Calls**
  - [x] Ensure reset is called consistently between tests
  - [x] Add reset to centralized setup functions
  - [x] Add checks to verify reset was successful

- [ ] **5.3 Add State Isolation**
  - [ ] Implement state isolation between tests
  - [x] Add per-test unique identifiers for resources
  - [ ] Improve cleanup to ensure no state leakage

### 6. Enhance Test Environment Management - MEDIUM PRIORITY

- [x] **6.1 Update Test Helper**
  - [x] Remove direct ExUnit.run() call if present
  - [x] Ensure proper test environment initialization
  - [x] Add comprehensive error handling

- [x] **6.2 Improve Sandbox Management**
  - [x] Update sandbox checkout handling
  - [x] Fix ownership timeout issues
  - [x] Ensure proper sharing mode based on test tags

- [x] **6.3 Add Cleanup Hooks**
  - [x] Ensure cleanup hooks are run in correct order
  - [x] Add checks to verify cleanup was successful
  - [x] Implement better error handling in cleanup

### 7. Add Comprehensive Tests - LOW PRIORITY

- [ ] **7.1 Create Diagnostic Tests**
  - [ ] Add tests to verify repository initialization
  - [ ] Add tests to verify process management
  - [ ] Add tests to verify mock operation

- [ ] **7.2 Update Documentation**
  - [ ] Document correct usage patterns
  - [ ] Update README with test environment information
  - [x] Document common troubleshooting steps

### 8. Specific Implementation Fixes - HIGH PRIORITY

- [x] **8.1 Fix TestEventStore Implementation**
  - [x] Add missing `stream_version/2` function
  - [x] Ensure proper behavior delegation to EventStoreCore
  - [x] Fix parameter handling in EventStore functions

- [x] **8.2 Fix EventStoreAccess Implementation**
  - [x] Update `get_stream_version/1` to handle opts parameter correctly
  - [x] Ensure proper delegation to adapter functions
  - [x] Fix function type specifications

- [x] **8.3 Implement Connection Ownership Handling**
  - [x] Create shared mode setup function in DatabaseHelper
  - [x] Update test modules to use the shared mode correctly
  - [x] Ensure proper cleanup of connections after tests

- [x] **8.4 Fix Remaining Connection Issues**
  - [x] Investigate remaining ownership errors in repository calls
  - [x] Fix timeout issues in database connections
  - [x] Ensure consistent connection handling across all test scenarios

## Implementation Guidelines

1. **Start with High Priority Items**: Begin with standardized initialization and process management
2. **Test Each Change**: After each change, run the diagnostic tests to verify the improvement
3. **Refine As Needed**: Adjust the checklist based on findings during implementation
4. **Document Changes**: Keep the implementation progress document updated

## Expected Outcomes

1. **Stable Test Environment**: Tests run reliably without initialization issues
2. **Clean Process Management**: All processes are properly managed and cleaned up
3. **Clear Error Messages**: When failures occur, error messages clearly indicate the cause
4. **Consistent Approach**: All tests follow the same patterns for initialization and cleanup

## Implementation Progress

Use this section to track progress as items are completed.

- Started implementation: 2023-12-12
- First high-priority items completed: 2023-12-12
  - Implemented enhanced DatabaseHelper with synchronization and health checks
  - Created missing MockEventStoreAccess and MockSubscriptionManager modules
  - Improved process registration and monitoring in EventStore mock
  - Updated EventStoreAccessTest to use centralized initialization

- Latest improvements (prior update):
  - Added missing `stream_version/2` function to TestEventStore
  - Enhanced process handling in mock EventStore implementation
  - Created shared database connection handling in DatabaseHelper
  - Fixed parameter handling in EventStoreAccess.get_stream_version
  - Improved mock cleanup with proper :meck.unload() calls

- Latest improvements (current date):
  - Fixed `FunctionClauseError` in `GenServer.whereis/1` by properly delegating calls from EventStoreMock to EventStoreCore
  - Improved parameter handling in mock modules to ensure server names are correctly passed
  - Enhanced error handling in test setup to manage already-running processes
  - Fixed issues with EventStoreCore process registration and access
  - Resolved test failures in EventStoreAccessTest (all 13 tests now pass)
  - Fixed pagination issues in events retrieval
  - Fixed stream version handling for new streams
  - Updated test setup functions to properly initialize mock data

Current high-priority items:
- Address cleanup warnings in test output ("Event store is not running, cannot reset")
- Improve test initialization consistency across different test modules
- Optimize process state isolation between test runs to prevent state leakage 