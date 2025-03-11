# Test Suite Fix Priorities

This document outlines the prioritized approach to fixing the test suite failures, based on the analysis in QUICK_WINS.md.

## Prioritization Strategy

Fixes are prioritized according to these criteria:
1. **Ease of implementation** - How quickly can this be implemented?
2. **Risk level** - How likely is this change to affect other parts of the system?
3. **Impact** - How many test failures will this fix resolve?

## Current Progress

- ✅ Fixed event serialization validation
- ✅ Created missing MockSubscriptionManager module
- ✅ Implemented alternative approach for GameCompletionHandler tests
- ✅ Fixed ETS table initialization for web tests
- ✅ Addressed telemetry handler warnings
- ✅ Fixed PostgreSQL adapter tests for event store
- ✅ CommandHandlerTest is now passing
- ✅ Fixed unused state parameter in TeamAggregate.execute for CreateTeamInvitation
- ✅ Added documentation for intentional state parameter ignoring in TeamAggregate.apply
- ✅ Fixed unused variable in migrate.ex rescue clause
- ✅ Fixed unused variables in UserProjection module
- ✅ Fixed unused variables in WordService module
- ✅ Fixed unused variable in CommandHandler module
- ✅ Fixed unused variables in ReplayCommands module
- ✅ Removed unused aliases in EventStore module
- ✅ Removed unused aliases in EventSerializerMapImpl module
- ✅ Removed unused aliases in BaseEvent module
- ✅ Fixed unused variables in StatsCommands module
- ✅ Fixed unused variable in GameModes.Events module
- ✅ Fixed unused variable in GameSessions.Cleanup module
- ✅ Removed unused aliases in TeamCommands module
- ✅ Fixed struct reference in TeamCommands.handle_team_create
- ✅ Fixed UserPreferencesChanged handler in UserProjection
- ✅ Fixed FetchPlayerStats struct usage in StatsCommands
- ✅ Removed unused Command alias in StatsCommands
- ✅ Fixed unused args variable in parse_player_stats_args function

## Remaining Issues - Prioritized

### 1. Low Effort, Low Risk Fixes

#### 1.1 Compiler Warnings
- **Description**: Fix remaining compiler warnings
- **Effort**: Very low - mostly mechanical changes
- **Risk**: Minimal - won't affect functionality
- **Approach**: 
  - Fix @impl annotations in TestEventStore and EventStore modules
  - Fix function clause ordering in UserProjection
  - Fix incompatible types in GameCommands
  - Fix range expression in CommandHandler
  - Fix undefined functions in PostgresTypes
  - Fix unused aliases in bot's TeamCommands module

#### 1.2 Replay Storage Test Fixes
- **Description**: Modify tests to accommodate the current {:ok, value} return format
- **Effort**: Low - change test assertions, not production code
- **Risk**: None - only affects tests
- **Examples**:
  ```elixir
  # Before
  test "store_replay/1 stores a replay and returns its ID" do
    replay = build_replay()
    stored_replay = Storage.store_replay(replay)
    assert stored_replay.replay_id == replay.replay_id
  end
  
  # After
  test "store_replay/1 stores a replay and returns {:ok, replay}" do
    replay = build_replay()
    {:ok, stored_replay} = Storage.store_replay(replay)
    assert stored_replay.replay_id == replay.replay_id
  end
  ```

### 2. Medium Effort, Low Risk Fixes

#### 2.1 Transaction Error Handling Tests
- **Description**: Fix test expectations for error handling in transaction tests
- **Effort**: Medium - requires understanding the current error format
- **Risk**: Low - isolated to test code
- **Location**: `test/game_bot/infrastructure/persistence/integration_test.exs:108`
- **Approach**:
  - Update test expectations to match actual error format
  - Use pattern matching to extract the relevant parts of error structs

#### 2.2 Event Store Not Running Warnings
- **Description**: Improve cleanup process to handle "Event store is not running" warnings
- **Effort**: Medium - requires understanding cleanup flow
- **Risk**: Low - mostly affects test cleanup
- **Approach**:
  - Add conditional checks before attempting to reset event store
  - Improve cleanup logic to gracefully handle missing event store

### 3. Higher Effort or Higher Risk Fixes

#### 3.1 Return Value Standardization
- **Description**: Standardize return values across the codebase
- **Effort**: Medium-High - requires consistent approach across modules
- **Risk**: Medium - changing API could affect consumers
- **Affected modules**:
  - `GameBot.Replay.Storage` functions
- **Decision needed**:
  - Option 1: Keep {:ok, value} format consistently and update all tests
  - Option 2: Change functions to return unwrapped values consistently

#### 3.2 Repository Initialization
- **Description**: Fix repository startup in test environment
- **Effort**: High - requires deep understanding of repo initialization
- **Risk**: Medium - affects test infrastructure broadly
- **Error**: "could not lookup Ecto repo because it was not started or it does not exist"
- **Approach**:
  - Add explicit repository start in test setup
  - Ensure repos are configured properly for test environment

#### 3.3 Event Store Schema Issues
- **Description**: Fix "relation event_store.streams does not exist" errors
- **Effort**: High - involves complex initialization logic
- **Risk**: Medium-High - could affect test environment setup broadly
- **Approach**:
  - Better initialization of schema before tests
  - Proper handling in test modules

## Implementation Plan

### Phase 1: Quick Wins (Current)
1. Fix compiler warnings systematically:
   ```bash
   mix compile --warnings-as-errors --force
   ```
2. Update Replay Storage tests to handle {:ok, value} return format
3. Fix transaction error handling test expectations

### Phase 2: Core Infrastructure (Next)
1. Decide on a consistent return value convention
2. Implement return value standardization based on decision
3. Fix event store initialization and cleanup process

### Phase 3: Database Integration (Final)
1. Resolve repository initialization issues
2. Fix event store schema setup for tests
3. Ensure proper cleanup between tests

## Testing Strategy During Fixes

During the fix process, we recommend:

1. **Run specific passing tests** to continue with feature development:
   ```bash
   mix test test/game_bot/bot/command_handler_test.exs
   ```

2. **Exclude problematic tests** with tags:
   ```bash
   mix test --exclude integration
   mix test --exclude db_dependent
   ```

3. **Use focused test runs** to verify specific fixes:
   ```bash
   mix test test/path/to/fixed_test.exs
   ```

4. **Track progress** by monitoring the number of failing tests:
   ```bash
   mix test --exclude integration | grep "x failures"
   ```

## Unused Parameter Evaluation Checklist

When fixing unused parameters (especially state parameters), use this checklist to determine if they need actual implementation:

- [ ] **State Dependency Check**: Does the function's logic depend on the current state?
  - [ ] If yes, implement proper state usage
  - [ ] If no, document why state is intentionally ignored

- [ ] **Command Validation**: For execute functions, does the command need validation against current state?
  - [ ] Check for conflicts with existing data
  - [ ] Verify preconditions based on state
  - [ ] Ensure business rules are enforced

- [ ] **Event Application**: For apply functions, should the event modify existing state?
  - [ ] Determine if event replaces state entirely (like TeamCreated)
  - [ ] Determine if event modifies specific state fields

- [ ] **Pattern Consistency**: Does the implementation match similar functions in the module?
  - [ ] Compare with other execute/apply functions
  - [ ] Ensure consistent error handling

- [ ] **Test Coverage**: Are there tests that verify the function's behavior?
  - [ ] Add tests for new state-dependent logic
  - [ ] Verify error cases are properly tested

### Completed Evaluations

- ✅ **TeamAggregate.execute for CreateTeamInvitation**
  - ✅ Added check_existing_invitation to validate against current state
  - ✅ Implemented proper error handling for invitation conflicts
  - ✅ Added guild_id to created event for consistency

- ✅ **TeamAggregate.apply for TeamCreated**
  - ✅ Documented intentional state replacement (not modification)
  - ✅ Confirmed pattern is consistent with event sourcing principles

- ✅ **migrate.ex rescue clause**
  - ✅ Added underscore prefix to unused variable
  - ✅ No implementation needed as this is just error handling 