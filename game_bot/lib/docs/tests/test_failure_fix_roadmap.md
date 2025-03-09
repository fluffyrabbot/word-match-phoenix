# Test Failure Fix Roadmap

## Current Status
- Total Tests: 105
- Passing: 105
- Failing: 0
- Pass Rate: 100%

## Critical Issues

### Command Handler (0 failures - FIXED)
- ✅ Added and fixed event factory functions:
  - ✅ `GameBot.Domain.Events.GameEvents.GameStarted.new/6`
  - ✅ `GameBot.Domain.Events.TeamEvents.TeamCreated.new/5`
  - ✅ `GameBot.Domain.Events.GameEvents.GuessProcessed.new/4`
  - ✅ Fixed correlation ID handling in command handler methods

### Event Registry (0 failures - FIXED)
- ✅ ETS table management in tests has been improved
- ✅ Table name caching and proper cleanup between tests implemented
- ✅ Set async: false to prevent race conditions 

### Team Projection (0 failures - FIXED)
- ✅ All tests passing after fixing serialization

### Event Store (0 failures - FIXED)
- ✅ All tests passing after fixing serialization

### Game Events (0 failures - FIXED)
- ✅ Fixed validation logic for `GameStarted` event
- ✅ Properly handling string/bitstring input for team_ids and player_ids
- ✅ Added validation functions for `GameCompleted` event

## Recently Fixed

- ✅ Added missing validation functions to `GameCompleted` module:
  - ✅ `validate_integer/2`
  - ✅ `validate_positive_integer/2`
  - ✅ `validate_non_negative_integer/2`
  - ✅ `validate_float/2`
- ✅ Fixed correlation ID handling in `handle_guess` to maintain correlation chain
- ✅ Implemented proper validation in `validate_teams` to check if `team_ids` and `player_ids` are lists before using Enum functions
- ✅ Added proper error handling for nil values in event validation
- ✅ Fixed ETS table management in EventRegistry tests:
  - Added proper cleanup between tests
  - Improved table name caching
  - Set async: false to prevent race conditions
  - Added proper verification of table existence before operations
- ✅ Fixed serialization and deserialization issues in the event registry

## Completed Steps

1. ✅ Implement the missing factory functions for event creation:
   - ✅ `GameBot.Domain.Events.GameEvents.GameStarted.new/6`
   - ✅ `GameBot.Domain.Events.TeamEvents.TeamCreated.new/5`
   - ✅ `GameBot.Domain.Events.GameEvents.GuessProcessed.new/4`
2. ✅ Created `GameCompletedValidator` module with missing validation functions
3. ✅ Fixed correlation ID handling in command handlers
4. ✅ Run full verification on the test suite - All tests passing!

## Remaining Code Quality Issues

### Compiler Warnings
- Unused variables (e.g., `field`, `user_id`, `pid`, etc.)
- Unused aliases and imports
- Conflicting behaviors in modules implementing multiple behaviors

### Optimization Opportunities
- Consolidate validation logic into common helpers
- Remove redundant code in event handling
- Fix default argument warnings in function definitions
- Address redefining module warnings
- Fix grouping of function clauses

## Test Categories

### Event Store (FIXED)
- ✅ All passing

### Event Registry (FIXED)
- ✅ All passing after fixing ETS table management

### Event Validation (FIXED)
- ✅ All passing with the improved validation function for GameStarted

### Command Processing (FIXED)
- ✅ All passing after implementing factory functions and fixing correlation ID handling

### Game Modes (FIXED)
- ✅ All passing

### Team Handling (FIXED)
- ✅ All passing

## Notes
- Event Registry deserialization issue with binary arguments has been fixed
- ETS table cleanup between tests is now working properly
- Correlation ID handling has been fixed to maintain proper event chains
- All tests now pass, focus can shift to addressing warnings and code quality issues

## Implementation Guidelines

### Testing Strategy

1. **Incremental Approach**:
   - ✓ Fix critical database connection issues (COMPLETED)
   - ✓ Fix missing EventStore API functions (COMPLETED)
   - ✓ Fix EventStore serialization issues (COMPLETED)
   - ✓ Fix TestAdapter for Base tests (COMPLETED)
   - ✓ Fix event translator migration paths (COMPLETED)
   - ✓ Fix word validation in test environment (COMPLETED)
   - ✓ Fix error format consistency issues (COMPLETED)
   - ✓ Fix sandbox mode configuration (COMPLETED)
   - ✓ Fix Game Events serialization (COMPLETED)
   - ✓ Fix Game Events validation with improper team structure (COMPLETED)
   - ✓ Fix Event Registry deserialization (COMPLETED)
   - ✓ Add proper test isolation for Event Registry (COMPLETED)
   - ✓ Add event factory functions for command handlers (COMPLETED)

2. **Testing Helpers**:
   - ✓ Create isolated test files for complex components
   - ✓ Add better debugging for test failures
   - ✓ Use appropriate tags to run specific test groups

3. **Mocking Strategy**:
   - ✓ Use mocks for EventStore in validation tests
   - ✓ Implement proper test doubles for complex dependencies
   - ✓ Create specific test environments for each layer

## Tracking Progress

### Test Suite Health Metrics

- [x] Repository manager tests passing: 4/4
- [x] EventStore adapter tests passing in isolation: 4/4
- [x] EventStore macro integration tests: 4/4
- [x] EventStore BaseTest: 11/11
- [x] Game mode validation tests passing: 45/45
- [x] Event serialization tests passing: 12/12
- [x] ExampleEvent tests passing: 5/5
- [x] Game events tests passing: 19/19
- [x] Event registry tests passing: 6/6
- [x] Command handler tests passing: 4/4
- [x] Overall test pass rate: 105/105 (100%)