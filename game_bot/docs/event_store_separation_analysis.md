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
- [ ] Refactor `GameBot.Test.Mocks.EventStore`
  - [ ] Remove GenServer usage
  - [ ] Implement delegation to Core
  - [ ] Maintain EventStore behavior

### Phase 3: Integration & Testing
- [x] Fix diagnostic test for EventStore
  - [x] Update to handle different return formats
  - [x] Add robust error handling
  - [x] Fix instance management
- [ ] Update repository case
- [ ] Update event store case

## Current Progress

We have completed the core implementation phase and most of the interface refactoring for the `GameBot.TestEventStore` module. The separation of concerns between GenServer behavior and EventStore behavior is now properly implemented for the main TestEventStore module.

The diagnostic tests now pass with the refactored TestEventStore implementation, confirming that the basic functionality is working as expected.

## Implementation Details

### Core Module Design

We've implemented a clear separation of concerns by:

1. Creating a dedicated `EventStoreCore` module that:
   - Implements the GenServer behavior exclusively
   - Manages state through a well-defined State struct
   - Provides a clean API for the interface module
   - Handles all state mutations and persistence

2. Refactoring `TestEventStore` to:
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

## Remaining Issues

### 1. Code Quality Warnings

There are still several code quality warnings throughout the codebase:

- Unused variables (should be prefixed with underscore)
- Unused aliases (should be removed or used)
- Functions with multiple clauses that have incompatible defaults
- Missing `@impl` annotations in some behavior implementations

### 2. EventStore Mock Implementation

The `GameBot.Test.Mocks.EventStore` module still needs to be refactored:

- It currently implements both GenServer and EventStore behaviors in the same module
- Several functions have conflicting implementations
- Some EventStore callbacks are missing or incomplete
- The delegation pattern needs to be applied to separate concerns

### 3. Integration Tests

We need to update the repository and event store case modules to ensure they work with the refactored implementation:

- Verify that the separation of concerns doesn't break existing tests
- Update case modules to use the new APIs correctly
- Add robust error handling in test helpers

## Next Steps

1. **Complete EventStore Mock Refactoring**
   - Apply the same separation of concerns pattern to `GameBot.Test.Mocks.EventStore`
   - Ensure all required callbacks are properly implemented
   - Fix remaining function signature issues

2. **Fix Code Quality Issues**
   - Address unused variables and aliases
   - Fix function clause conflicts
   - Add missing `@impl` annotations

3. **Update Test Infrastructure**
   - Update repository and event store case modules
   - Verify compatibility with existing tests
   - Add comprehensive testing for the new implementation

4. **Document Architecture**
   - Create documentation for the new architecture
   - Update existing documentation to reflect changes
   - Provide migration guide for tests

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

## Conclusion

The EventStore separation project has made significant progress, with the core implementation and main interface refactoring now complete. The diagnostic tests now pass with the refactored implementation, confirming that the basic functionality is working as expected.

However, there are still several important tasks remaining, particularly the refactoring of the `GameBot.Test.Mocks.EventStore` module and the integration with the repository and event store case modules. Additionally, there are several code quality issues that need to be addressed throughout the codebase.

With the completion of these remaining tasks, the EventStore separation project will provide a much more robust and maintainable testing infrastructure for the GameBot application. 