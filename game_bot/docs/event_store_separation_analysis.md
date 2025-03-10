# EventStore Behavior Separation Analysis

## Implementation Checklist

### Phase 1: Create Core Implementations
- [x] Create `GameBot.Test.EventStoreCore` module
  - [x] Move State struct definition
  - [x] Implement GenServer callbacks
  - [x] Add core operations API
  - [x] Add state management functions
- [x] Create `GameBot.Test.Mocks.EventStoreCore` module
  - [x] Move State struct definition
  - [x] Implement GenServer callbacks 
  - [x] Add core operations API
  - [x] Add state management functions

### Phase 2: Refactor Interface Modules
- [x] Refactor `GameBot.TestEventStore`
  - [x] Remove GenServer usage
  - [x] Implement delegation to Core
  - [x] Maintain EventStore behavior
  - [x] Fix function signatures to match EventStore behavior
  - [x] Add proper @impl annotations
  - [x] Add backward compatibility functions (start_link/0, read_stream_forward/1)
- [x] Refactor `GameBot.Test.Mocks.EventStore`
  - [x] Remove GenServer usage
  - [x] Implement delegation to Core
  - [x] Maintain EventStore behavior
  - [x] Add backward compatibility functions (start_link/0)

### Phase 3: Fix Supporting Infrastructure
- [x] Fix `GameBot.Test.DatabaseHelper`
  - [x] Add missing setup_sandbox/1 function with tag support
  - [x] Add cleanup_connections/0 for backward compatibility
  - [x] Update function calls with proper setup_sandbox parameter handling
- [ ] Fix event store test initialization issues
  - [x] Update EventStoreAccessTest to properly initialize mock services
  - [ ] Update IntegrationTest to properly initialize repositories
  - [ ] Fix test event definition issues for serialization
- [ ] Update test case modules
  - [ ] Update repository case
  - [ ] Update event store case
  - [ ] Handle mock initialization consistently

## Current Progress

We have completed the core implementation phase and have successfully refactored both TestEventStore and Mocks.EventStore to follow the delegation pattern. The separation of concerns between GenServer behavior and EventStore behavior is now properly implemented for both modules.

Recent improvements include:
1. **Backward Compatibility**:
   - Added `start_link/0` to both EventStore implementations 
   - Added `read_stream_forward/1` convenience function to TestEventStore
   - Added `cleanup_connections/0` alias in DatabaseHelper

2. **Test Infrastructure**: 
   - Fixed `setup_sandbox/1` function implementation in DatabaseHelper
   - Updated EventStoreAccessTest to properly handle process initialization
   - Fixed error handling in process startup/reset functions

The diagnostic tests now partially pass, and we've significantly reduced the number of error types in the remaining test failures.

## Implementation Details

### Core Module Design

We've implemented a clear separation of concerns by:

1. Creating dedicated `EventStoreCore` modules that:
   - Implement the GenServer behavior exclusively
   - Manage state through a well-defined State struct
   - Provide a clean API for the interface module
   - Handle all state mutations and persistence

2. Refactoring interface modules to:
   - Implement only the EventStore behavior
   - Delegate all state management to the Core module
   - Handle protocol-specific conversions
   - Provide proper error handling for all operations

### Function Signature Fixes

Several critical issues with function signatures have been fixed:

1. Removed default parameters from functions with multiple clauses
2. Fixed function signatures to match the EventStore behavior
3. Added proper @impl annotations for behavior functions
4. Created separate functions for operations with/without options

### Process Management

We've improved process management by:

1. Enhancing start/stop logic to handle already-running instances
2. Adding proper process registration/deregistration
3. Implementing clean error handling for process operations
4. Adding robust reset functionality
5. Making setup functions more tolerant of process state inconsistencies

## Remaining Issues

### 1. Test Environment Initialization

The most critical remaining issue is inconsistent test environment initialization:

- Many tests fail because repositories are not properly started
- The EventStore processes are not always initialized before use
- Integration tests encounter serialization errors with event formats
- Tests using Mox/mock modules cannot find their mock definitions

### 2. Code Quality Warnings

There are still several code quality warnings throughout the codebase:

- Unused variables (should be prefixed with underscore)
- Unused aliases (should be removed or used)
- Functions with multiple clauses that have incompatible defaults
- Missing `@impl` annotations in some behavior implementations

### 3. Test Module Inconsistencies

Some test modules have inconsistent expectations about:

- Return formats from list operations (expecting lists instead of {:ok, list})
- Event structure validation and serialization rules
- Process initialization sequencing and requirements
- Mock definitions and availability

## Next Steps (Prioritized)

1. **🔴 Fix Test Environment Initialization Issues**
   - Implement consistent repository initialization across all test modules
   - Add event serialization validation to test event creation functions
   - Update test event formats to comply with serializer requirements
   - Ensure TestEventStore and EventStoreCore are properly initialized before tests

2. **🔴 Add Missing Mock Implementations**
   - Create missing `MockEventStoreAccess` and `MockSubscriptionManager` modules
   - Ensure mock definitions are accessible to all tests
   - Standardize mock setup and teardown
   - Consider using Mox more consistently across the codebase

3. **⏩ Update Test Case Modules**
   - Update repository case to properly initialize the test environment
   - Update event store case to handle different EventStore implementations
   - Standardize setup and teardown procedures across test cases
   - Add better error reporting for test environment issues

4. **⏩ Address Code Quality Issues**
   - Fix unused variables by prefixing with underscore
   - Remove or properly use unused aliases
   - Fix function clause conflicts
   - Add missing `@impl` annotations

5. **⏩ Improve Error Handling and Reporting**
   - Add more detailed error messages to failures
   - Improve error propagation through delegate functions
   - Add error recovery options where appropriate
   - Standardize error return formats

## Lessons Learned

1. **Behavior Separation**
   - Implementing multiple behaviors in a single module, especially when they have overlapping callback names, is problematic and should be avoided
   - The delegation pattern is an effective way to separate concerns while maintaining functionality

2. **Function Signatures**
   - Functions with multiple clauses must have consistent parameter lists
   - Default parameters should be used carefully in behavior implementations
   - Consistent naming and parameter ordering is essential for maintainability

3. **Process Management**
   - Proper process registration and deregistration is essential for reliable operation
   - Error handling must be robust for all process operations
   - Reset functionality must handle all state components

4. **Backward Compatibility**
   - Adding simplified function forms for backward compatibility helps migration
   - Checking for existing processes before initialization prevents crashes
   - Aliasing deprecated function names maintains compatibility

## Conclusion

The EventStore separation project has made significant progress, with both the main interface modules now refactored to use the delegation pattern. The remaining issues are primarily related to test environment initialization, mock implementation, and integration with existing test modules.

By addressing the prioritized issues listed above, we can complete the EventStore separation project and provide a much more robust and maintainable testing infrastructure for the GameBot application. The most critical next steps are fixing the test environment initialization issues and adding the missing mock implementations, as these are causing the majority of the remaining test failures. 