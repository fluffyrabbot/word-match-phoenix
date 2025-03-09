# Compiler Warnings Fix Roadmap

## Overview

This document provides a prioritized plan for addressing compiler warnings identified in the GameBot codebase. All tests are now passing, but there are numerous compiler warnings that should be addressed to improve code quality, maintainability, and prevent potential runtime issues.

## Warning Categories

1. **Critical Warnings**
   - Conflicting behaviors in modules
   - Module redefinitions
   - Undefined module attributes

2. **Important Warnings**
   - Incorrect `@impl` annotations
   - Function clauses not grouped together
   - Default arguments never used

3. **Maintainability Warnings**
   - Unused variables
   - Unused aliases and imports
   - Unused functions
   - Module attributes not being used
   - Documentation for private functions

## Prioritized Action Plan

### Phase 1: Critical Warnings (High Priority)

#### 1.1 Fix Conflicting Behaviors

- [x] **TestEventStore Module**
  - Issue: Conflicting behaviors found for callback function `init/1` (defined by both GenServer and EventStore)
  - Location: `lib/game_bot/test_event_store.ex:1`
  - Fix: Removed the conflicting `@impl EventStore` annotation from the `start_link/1` function which was incorrectly marked as implementing the EventStore behavior

#### 1.2 Fix Module Redefinitions

- [x] **GameStarted EventValidator**
  - Issue: Redefining module `GameBot.Domain.Events.EventValidator.GameBot.Domain.Events.GameEvents.GameStarted`
  - Location: `lib/game_bot/domain/events/game_events.ex:1845`
  - Fix: Removed the duplicate EventValidator implementation at the end of the game_events.ex file

#### 1.3 Fix Undefined Module Attributes

- [x] **KnockoutMode Module**
  - Issue: Undefined module attributes `@default_round_duration` and `@default_elimination_limit`
  - Location: `lib/game_bot/domain/game_modes/knockout_mode.ex:116-117`
  - Fix: Added the module attributes with values from existing `@round_time_limit` and `@max_guesses` attributes

### Phase 2: Important Warnings (Medium Priority)

#### 2.1 Fix Incorrect @impl Annotations

- [ ] **GuessProcessed Module**
  - Issue: Missing `@impl true` for function `event_version/0`
  - Location: `lib/game_bot/domain/events/guess_events.ex:38`
  - Fix: Add `@impl true` annotation

- [ ] **GuessProcessed Module**
  - Issue: Incorrect `@impl true` for function `validate_attrs/1`
  - Location: `lib/game_bot/domain/events/guess_events.ex:84`
  - Fix: Remove `@impl true` annotation if function doesn't implement a behavior

- [ ] **GameError Module**
  - Issue: Missing `@impl true` for function `event_version/0`
  - Location: `lib/game_bot/domain/events/error_events.ex:206`
  - Fix: Add `@impl true` annotation

- [ ] **GuessPairError Module**
  - Issue: Missing `@impl true` for function `event_version/0`
  - Location: `lib/game_bot/domain/events/error_events.ex:115`
  - Fix: Add `@impl true` annotation

- [ ] **GuessError Module**
  - Issue: Missing `@impl true` for function `event_version/0`
  - Location: `lib/game_bot/domain/events/error_events.ex:26`
  - Fix: Add `@impl true` annotation

- [ ] **Postgres Module**
  - Issue: Got `@impl Ecto.Repo` for function `init/1` but this behavior doesn't specify such callback
  - Location: `lib/game_bot/infrastructure/persistence/event_store/adapter/postgres.ex:37`
  - Fix: Remove or correct the `@impl` annotation

#### 2.2 Fix Function Clause Organization

- [ ] **GameProjection Module**
  - Issue: Clauses with the same name should be grouped together - `handle_event/1` and `handle_event/2`
  - Location: `lib/game_bot/domain/projections/game_projection.ex:94, 109`
  - Fix: Group all `handle_event/1` implementations together, and all `handle_event/2` implementations together

- [ ] **ReplayCommands Module**
  - Issue: Clauses with the same name and arity should be grouped together - `handle_game_summary/2`
  - Location: `lib/game_bot/bot/commands/replay_commands.ex:347`
  - Fix: Group all `handle_game_summary/2` implementations together

#### 2.3 Fix Default Arguments Never Used

- [ ] **Transaction Module**
  - Issue: Default values for optional arguments in `with_retry/3` are never used
  - Location: `lib/game_bot/infrastructure/persistence/repo/transaction.ex:103`
  - Fix: Remove default arguments and use them directly in function calls, or revise the function implementation

#### 2.4 Fix Redefined @doc Attributes

- [ ] **ReplayCommands Module**
  - Issue: Redefining `@doc` attribute previously set at line 96
  - Location: `lib/game_bot/bot/commands/replay_commands.ex:335`
  - Fix: Remove duplicate `@doc` or use function head documentation pattern as suggested in the warning

### Phase 3: Maintainability Warnings (Lower Priority)

#### 3.1 Fix Unused Variables

- [ ] **Postgres Module**
  - Issue: Unused type definitions `conn/0`, `query/0`, `stream_version/0`
  - Location: `lib/game_bot/infrastructure/persistence/event_store/adapter/postgres.ex:24-26`
  - Fix: Remove or prefix with underscore

- [ ] **RoundStarted Module**
  - Issue: Unused variable `field` in various validation functions
  - Location: `lib/game_bot/domain/events/game_events.ex:500-509`
  - Fix: Prefix with underscore `_field`

- [ ] **GuessProcessed Module**
  - Issue: Unused variable `user_id`
  - Location: `lib/game_bot/domain/events/game_events.ex:700`
  - Fix: Prefix with underscore `_user_id`

- [ ] **TeamEliminated Module**
  - Issue: Unused variable `field` in various validation functions
  - Location: `lib/game_bot/domain/events/game_events.ex:1138-1147`
  - Fix: Prefix with underscore `_field`

- [ ] **RoundCompleted Module**
  - Issue: Unused variable `field` in various validation functions
  - Location: `lib/game_bot/domain/events/game_events.ex:1828-1834`
  - Fix: Prefix with underscore `_field`

- [ ] **Listener Module**
  - Issue: Unused module attributes `@min_word_length` and `@max_word_length`
  - Location: `lib/game_bot/bot/listener.ex:51-52`
  - Fix: Remove if not needed

- [ ] **GameCompletedValidator Module**
  - Issue: Unused variable `field` in various validation functions
  - Location: `lib/game_bot/domain/events/game_completed_validator.ex:6-15`
  - Fix: Prefix with underscore `_field`

- [ ] **Cleanup Module**
  - Issue: Unused variable `pid`
  - Location: `lib/game_bot/game_sessions/cleanup.ex:43`
  - Fix: Prefix with underscore `_pid`

- [ ] **Session Module**
  - Issue: Unused variable `previous_events`
  - Location: `lib/game_bot/game_sessions/session.ex:335`
  - Fix: Prefix with underscore `_previous_events`

- [ ] **TwoPlayerMode Module**
  - Issue: Unused variable `state` in `check_round_end/1`
  - Location: `lib/game_bot/domain/game_modes/two_player_mode.ex:203`
  - Fix: Prefix with underscore `_state`

- [ ] **RaceMode Module**
  - Issue: Unused variable `state` in `check_round_end/1`
  - Location: `lib/game_bot/domain/game_modes/race_mode.ex:240`
  - Fix: Prefix with underscore `_state`

- [ ] **Postgres Module**
  - Issue: Unused variables `e` in error catch clauses
  - Location: `lib/game_bot/infrastructure/persistence/repo/postgres.ex:267, 281`
  - Fix: Prefix with underscore `_e`

- [ ] **EventStoreCase Module**
  - Issue: Unused variables `repo` and `impl`
  - Location: `test/support/event_store_case.ex:152, 218`
  - Fix: Prefix with underscore

- [ ] **StatsCommands Module**
  - Issue: Unused variables `command` and multiple `metadata`
  - Location: `lib/game_bot/bot/commands/stats_commands.ex:64, 84, 173`
  - Fix: Prefix with underscore

- [ ] **ReplayCommands Module**
  - Issue: Unused variables `command_text` and `message`
  - Location: `lib/game_bot/bot/commands/replay_commands.ex:258`
  - Fix: Prefix with underscore

- [ ] **TeamAggregate Module**
  - Issue: Unused variable `state`
  - Location: `lib/game_bot/domain/aggregates/team_aggregate.ex:21`
  - Fix: Prefix with underscore `_state`

- [ ] **Serializer Module**
  - Issue: Unused variable `data` in `lookup_event_module/1`
  - Location: `lib/game_bot/infrastructure/persistence/event_store/serializer.ex:194`
  - Fix: Prefix with underscore `_data`

- [ ] **Migrate Task Module**
  - Issue: Unused variables `e` and `repo`
  - Location: `lib/tasks/migrate.ex:83, 98`
  - Fix: Prefix with underscore

#### 3.2 Fix Unused Aliases and Imports

- [ ] **TwoPlayerMode Module**
  - Issue: Unused alias `GameState`
  - Location: `lib/game_bot/domain/game_modes/two_player_mode.ex:38`
  - Fix: Remove the alias

- [ ] **TeamCommands Module**
  - Issue: Unused alias `Message`
  - Location: `lib/game_bot/bot/commands/team_commands.ex:9`
  - Fix: Remove the alias

- [ ] **TestEvents Module**
  - Issue: Unused aliases `EventSerializer`, `EventStructure`, `EventValidator`
  - Location: `lib/game_bot/domain/events/test_events.ex:6`
  - Fix: Remove the aliases

- [ ] **StatsCommands Module**
  - Issue: Unused alias `EventStore`
  - Location: `lib/game_bot/domain/commands/stats_commands.ex:6`
  - Fix: Remove the alias

- [ ] **BaseEvent Module**
  - Issue: Unused aliases `EventSerializer`, `EventValidator`, `Metadata`
  - Location: `lib/game_bot/domain/events/base_event.ex:10`
  - Fix: Remove the aliases

- [ ] **Pipeline Module**
  - Issue: Unused alias `Registry`
  - Location: `lib/game_bot/domain/events/pipeline.ex:11`
  - Fix: Remove the alias

- [ ] **Session Module**
  - Issue: Unused aliases `EventRegistry`, `GameCompleted`, `GuessProcessed`, `Metadata`
  - Location: `lib/game_bot/game_sessions/session.ex:18-19`
  - Fix: Remove the aliases

- [ ] **CommandHandlerTest Module**
  - Issue: Unused aliases `GameEvents`, `TeamEvents`
  - Location: `test/game_bot/bot/command_handler_test.exs:4`
  - Fix: Remove the aliases

- [ ] **RaceMode Module**
  - Issue: Unused aliases `GameState`, `GuessProcessed`
  - Location: `lib/game_bot/domain/game_modes/race_mode.ex:44-45`
  - Fix: Remove the aliases

- [ ] **KnockoutMode Module**
  - Issue: Unused aliases `GuessProcessed`, `KnockoutRoundCompleted`
  - Location: `lib/game_bot/domain/game_modes/knockout_mode.ex:43`
  - Fix: Remove the aliases

- [ ] **Serializer Module**
  - Issue: Unused aliases `Error`, `ErrorHelpers`, `EventRegistry`, `EventStructure`
  - Location: `lib/game_bot/infrastructure/persistence/event_store/serializer.ex:12-14`
  - Fix: Remove the aliases

- [ ] **Postgres Module**
  - Issue: Unused alias `Multi` and import `Ecto.Query`
  - Location: `lib/game_bot/infrastructure/persistence/repo/postgres.ex:10-11`
  - Fix: Remove the alias and import

#### 3.3 Fix Unused Functions

- [ ] **CommandHandlerTest Module**
  - Issue: Unused function `mock_message/0`
  - Location: `test/game_bot/bot/command_handler_test.exs:16`
  - Fix: Remove the function if not needed for future tests

- [ ] **TwoPlayerMode Module**
  - Issue: Unused function `validate_guess_pair/3`
  - Location: `lib/game_bot/domain/game_modes/two_player_mode.ex:306`
  - Fix: Remove the function if not needed or document why it's retained for future use

- [ ] **KnockoutMode Module**
  - Issue: Unused functions `validate_team_guess_count/1`, `validate_round_time/1`, `validate_active_team/2`
  - Location: `lib/game_bot/domain/game_modes/knockout_mode.ex:543, 341, 331`
  - Fix: Remove these functions if not needed

- [ ] **RoundStarted Module**
  - Issue: Unused function `validate_float/2`
  - Location: `lib/game_bot/domain/events/game_events.ex:509`
  - Fix: Remove the function if not needed

#### 3.4 Fix Documentation for Private Functions

- [ ] **Transaction Module**
  - Issue: `@doc` attribute is always discarded for private functions
  - Location: `lib/game_bot/infrastructure/persistence/repo/transaction.ex:91`
  - Fix: Either make the function public or remove the documentation

#### 3.5 Fix Unused Module Attributes

- [ ] **GameEvents Module**
  - Issue: Module attribute `@base_fields` was set but never used
  - Location: `lib/game_bot/domain/events/game_events.ex:30`
  - Fix: Remove if not needed

#### 3.6 Fix Test Code Warnings

- [x] **BaseTest Module**
  - Issue: Unused alias `Behaviour`
  - Location: `test/game_bot/infrastructure/persistence/event_store/adapter/base_test.exs:5:3`
  - Fix: Remove the alias

- [x] **PostgresTest Module**
  - Issue: Undefined or private function `unsubscribe_from_stream/3`
  - Location: `test/game_bot/infrastructure/persistence/event_store/postgres_test.exs:46:14`
  - Fix: Replace with the adapter module call `Adapter.unsubscribe_from_stream`

- [x] **HandlerTest Module**
  - Issue: Typing violation - clause will never match because it attempts to match on a dynamic(:ok) result
  - Location: `test/game_bot/domain/events/handler_test.exs:43`
  - Fix: Update the pattern match to handle the correct return type from `handle_event/1`

## Implementation Approach

### For Automated Fixes

Many of these issues can be resolved with automated processes:

```bash
# Script to prefix unused variables with underscore
find lib -name "*.ex" -exec sed -i 's/\bfield\b/_field/g' {} \;
find lib -name "*.ex" -exec sed -i 's/\buser_id\b/_user_id/g' {} \;
# etc.

# Script to remove unused aliases
find lib -name "*.ex" -exec sed -i '/alias GameBot.Domain.GameState/d' {} \;
# etc.
```

### For Manual Review and Fixes

Some issues require manual intervention and review:

1. Start with critical warnings (conflicting behaviors, module redefinitions)
2. Fix function clause organization issues
3. Address incorrect @impl annotations
4. Finally clean up unused variables, aliases, and functions

## Testing Strategy

After implementing each batch of fixes:

1. Run the full test suite to ensure no regressions were introduced
2. Verify that the number of warnings has decreased
3. Document which warnings have been fixed

## Progress Tracking

- [x] Phase 1: Critical Warnings - 3/3 completed
- [ ] Phase 2: Important Warnings - 0/11 completed
- [ ] Phase 3: Maintainability Warnings - 3/46 completed
- [ ] Total warnings fixed: 6/60

## Completion Criteria

The roadmap will be considered complete when:

1. All identified warnings have been addressed
2. The full test suite continues to pass
3. Running `mix compile --warnings-as-errors` completes successfully 