# Quick Wins and High Priority Fixes

## Test Failures Summary
The test suite is currently showing 93 failures out of 458 tests. Below is a prioritized list of issues to fix:

## High Priority Fixes

### 1. Event Store Serialization Issues
- [ ] Fix event serialization validation in `GameBot.Infrastructure.Persistence.EventStore.Serialization.JsonSerializer`
  - Error: "Event must be a struct or a map with required type keys"
  - Location: Integration test failure at `test/game_bot/infrastructure/persistence/event_store/integration_test.exs:273`

### 2. Missing Mock Modules
- [ ] Create or properly define `MockEventStoreAccess` module
  - Error: "could not load module MockEventStoreAccess due to reason :nofile"
  - Affects: All `GameBot.Replay.GameCompletionHandlerTest` tests

- [ ] Create or properly define `MockSubscriptionManager` module
  - Error: "could not load module MockSubscriptionManager due to reason :nofile"
  - Affects: Subscription tests

### 3. Transaction Error Handling
- [ ] Fix transaction error handling in integration tests
  - Error: Mismatch in error format between expected `{:error, %Ecto.Changeset{valid?: false}}` and actual error
  - Location: `test/game_bot/infrastructure/persistence/integration_test.exs:108`

### 4. Replay Storage Return Values
- [ ] Fix return value format in `GameBot.Replay.Storage` functions
  - Multiple tests expecting direct values but getting `{:ok, value}` tuples
  - Examples:
    - `test_store_replay/1` - KeyError on accessing replay_id
    - `test_list_replays/1` - ArgumentError on length check of `{:ok, []}`
    - `test_cleanup_old_replays/1` - Assertion failures on return values

### 5. ETS Table Issues
- [ ] Fix ETS table initialization for web tests
  - Error: "the table identifier does not refer to an existing ETS table"
  - Location: `test/game_bot_web/controllers/page_controller_test.exs:4`

### 6. Telemetry Handler Warnings
- [ ] Address telemetry handler warnings about local functions
  - Warning: "The function passed as a handler with ID is a local function"
  - Consider using named functions instead of anonymous functions or captures

## Medium Priority Fixes

### 7. Event Store Not Running Warnings
- [ ] Fix "Event store is not running, cannot reset" warnings
  - These appear during test cleanup

### 8. Repository Connection Warnings
- [ ] Address repository connection warnings
  - Error: "could not lookup Ecto repo because it was not started or it does not exist"

## Implementation Plan

### Phase 1: Fix Mock Modules (Highest Impact)
1. Create proper mock modules for `MockEventStoreAccess` and `MockSubscriptionManager`
2. Update test setup to properly initialize these mocks

### Phase 2: Fix Return Value Consistency
1. Standardize return values in the Replay Storage module
2. Update tests to match the expected return format

### Phase 3: Fix Serialization and Transaction Issues
1. Debug and fix the event serialization validation
2. Fix transaction error handling in integration tests

### Phase 4: Address Infrastructure Issues
1. Fix ETS table initialization for web tests
2. Address telemetry handler warnings
3. Fix event store reset warnings

## Notes
- Many failures appear to be related to inconsistent return value formats (some functions returning `{:ok, value}` while tests expect direct values)
- Mock module issues suggest missing or improperly configured test dependencies
- Several warnings about telemetry handlers using local functions could be addressed for better performance 