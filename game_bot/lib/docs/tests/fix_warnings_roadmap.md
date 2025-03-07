# Warning Fix Roadmap

This document outlines a structured approach to address all compiler warnings and potential runtime issues in the GameBot codebase.

## Priority 1: Critical Functionality Issues

These issues impact core system functionality and must be fixed first.

### 1.1 Undefined Functions

#### Command Handlers (COMPLETED)
- [x] Fix Metadata module references:
  - [x] Add alias and fix imports for `GameBot.Domain.Events.Metadata` in `StatsCommands` (lines 68, 84, 97)
  - [x] Ensure `Metadata.from_discord_interaction/1` is properly defined and accessible
- [x] Fix TeamProjection functions:
  - [x] Implement or fix imports for `GameBot.Domain.Projections.TeamProjection.create_team/1` (line 78)
  - [x] Implement or fix imports for `GameBot.Domain.Projections.TeamProjection.update_team/1` (line 102)
- [x] Fix or implement missing command handler functions:
  - [x] `GameBot.Bot.Commands.GameCommands.handle_command/2`
  - [x] `GameBot.Bot.Commands.StatsCommands.handle_command/2`
  - [x] `GameBot.Bot.Commands.TeamCommands.handle_team_create/2`
  - [x] `GameBot.Bot.Commands.TeamCommands.handle_team_update/3`
  - [x] Fix undefined functions in `GameBot.Bot.Commands.StatsCommands` handlers
  - [x] Fix undefined functions in `GameBot.Bot.Commands.ReplayCommands` handlers

#### EventStore Integration (COMPLETED)
- [x] Fix `GameBot.Domain.GameState.new/2` undefined
- [x] Add `GameBot.Infrastructure.EventStore.reset!/0` function
- [x] Add `GameBot.Infrastructure.EventStore.stream_version/1` function
- [x] Replace `EventStore.Config.parsed/1` with `EventStore.Config.parse/2`
- [x] Replace `EventStore.Tasks.Migrate.run/2` with `EventStore.Storage.Initializer.migrate/2`
- [x] Fix `EventStore.read_stream_forward/4` reference

### 1.2 Type and Pattern Matching Errors (COMPLETED)

#### Game Mode Type Issues
- [x] Fix typing violation in `GameBot.Domain.GameModes.TwoPlayerMode.init/3` (line 91)
- [x] Fix typing violation in `GameBot.Domain.GameModes.RaceMode.init/3` (line 109)
- [x] Fix pattern that will never match in `GameBot.Test.GameModes.TestHelpers.simulate_game_sequence/2` (line 83)
- [x] Fix invalid clause that will never match in `GameBot.Domain.GameModes.TwoPlayerMode.init/3` (line 91)
- [x] Fix invalid clause that will never match in `GameBot.Domain.GameModes.RaceMode.init/3` (line 109)

#### Command Handler Type Issues
- [x] Fix typing violation in `GameBot.Bot.Commands.StatsCommands.handle_player_stats/2` (line 54)
- [x] Fix typing violation in `GameBot.Bot.Commands.StatsCommands.handle_team_stats/2` (line 70)
- [x] Fix typing violation in `GameBot.Bot.Commands.StatsCommands.handle_leaderboard/3` (line 86)
- [x] Fix typing violation in `GameBot.Bot.Commands.ReplayCommands.handle_game_replay/2` (line 49)
- [x] Fix typing violation in `GameBot.Bot.Commands.ReplayCommands.handle_match_history/1` (line 67)
- [x] Fix typing violation in `GameBot.Bot.Commands.ReplayCommands.handle_game_summary/2` (line 80)

#### Map Key Errors
- [x] Fix unknown key `.config` in `GameBot.Domain.Projections.GameProjection.handle_event/1` (line 66)
- [x] Fix unknown key `.finished_at` in `GameBot.Domain.Projections.GameProjection.handle_event/2` (line 84)
- [x] Fix unknown key `.started_at` in `GameBot.Domain.Projections.GameProjection.handle_event/1` (line 97)

#### New Critical Type Issues
- [x] Fix incompatible types in `GameBot.Bot.Commands.ReplayCommands.handle_game_replay/2` (line 51)
- [x] Fix incompatible types in `GameBot.Bot.Commands.ReplayCommands.handle_match_history/1` (line 70)
- [x] Fix incompatible types in `GameBot.Bot.Commands.ReplayCommands.handle_game_summary/2` (line 84)
- [x] Fix conflicting behaviours between EventStore and GenServer in `GameBot.TestEventStore`
- [x] Fix undefined `GameBot.Domain.Events.GameFinished.new/4` in `GameBot.GameSessions.Session.handle_call/3`
- [x] Fix undefined `GameBot.Domain.GameState.increment_guess_count/2` in BaseMode (should be increment_guess_count/3)
- [x] Fix undefined `Phoenix.Component.used_input?/1` in CoreComponents
- [x] Fix undefined validate_event functions in game modes:
  - [x] `GameBot.Domain.GameModes.TwoPlayerMode.validate_event/1`
  - [x] `GameBot.Domain.GameModes.KnockoutMode.validate_event/1`
  - [x] `GameBot.Domain.GameModes.RaceMode.validate_event/1`

### 1.3 Error Handling Consistency (MOSTLY COMPLETED)

- [x] Standardize error structures across all error types
- [x] Implement consistent error handling in TestEventStore
- [x] Implement proper error transformation in Adapter
- [x] Add check in transform_error to preserve original error details
- [x] Standardize connection error details format
- [x] Update TestEventStore to return proper error structures
- [x] Update tests to expect proper error structures
- [x] Document error structure standards
- [x] Implement consistent error structure for connection errors
- [x] Modify tests to verify correct error details
- [x] Simplify error transformation to avoid double-wrapping
- [x] Add proper error structure for concurrency errors
- [ ] Add tests for timeout and validation errors

## Priority 2: Core Events and Structures

These issues affect data integrity and event handling but don't break immediate functionality.

### 2.1 Event Structure Improvements (MOSTLY COMPLETED)

#### Event Fields
- [x] Add missing `team_ids` field to GameCreated event
- [x] Add missing `started_at` field to GameStarted event
- [x] Add missing `finished_at` field to GameFinished event
- [x] Add missing `guild_id` field to RoundStarted event
- [ ] Update all event tests to include new fields

#### Event Creation Functions
- [x] Implement `GuessError.new/5`
- [x] Implement `RoundCheckError.new/2`
- [x] Implement `GameFinished.new/4`
- [x] Implement `GuessPairError.new/5`
- [ ] Add tests for all new event creation functions

### 2.2 Behaviour Implementation (MOSTLY COMPLETED)

#### EventStore Behaviour
- [x] Add @impl true annotations to all EventStore callbacks
- [x] Resolve conflicting behaviour implementations
- [x] Ensure proper error handling in callbacks
- [ ] Add tests for behaviour implementations
- [x] Fix missing @impl annotation for `ack/2` in `GameBot.Infrastructure.EventStore`

#### TestEventStore Implementation
- [x] Implement `ack/2`
- [x] Implement `config/0`
- [x] Implement stream management functions
- [x] Implement subscription management functions
- [ ] Add tests for TestEventStore

## Priority 3: Code Quality and Maintainability

These issues affect code maintainability, readability, and long-term sustainability.

### 3.1 Function Definition and Organization

#### Function Grouping
- [ ] Group `handle_event/1` implementations in `GameBot.Domain.Projections.GameProjection`
- [ ] Group `handle_event/2` implementations in `GameBot.Domain.Projections.GameProjection`
- [ ] Group `handle_call/3` in `GameBot.TestEventStore`
- [ ] Organize related functions together
- [ ] Add section comments for clarity

#### Function Definition Fixes
- [x] Fix `subscribe_to_stream/4` definition
- [x] Update function heads with proper default parameters
- [x] Ensure consistent function ordering
- [ ] Add typespecs to functions
- [ ] Fix documentation for private functions with @doc attributes
- [ ] Fix `EventStore.Config.parse/2` in migrate.ex (should be parse/1)
- [ ] Fix `EventStore.Storage.Initializer.migrate/2` in migrate.ex

### 3.2 Unused Variables and Aliases

#### Unused Variables (PARTIALLY COMPLETED)
- [x] Add underscore prefix to unused variables in game_sessions/session.ex
- [x] Add underscore prefix to unused variables in domain/game_modes.ex
- [x] Add underscore prefix to unused variables in game projection
- [x] Add underscore prefix to unused variables in replay commands
- [ ] Add underscore prefix to unused variable `command` in `GameBot.Domain.Commands.StatsCommands.FetchLeaderboard.execute/1`
- [ ] Add underscore prefix to unused variable `opts` in `GameBot.Infrastructure.EventStoreTraction.try_append_with_validation/4`
- [ ] Add underscore prefix to unused variable `recorded_events` in `GameBot.Infrastructure.EventStoreTraction.try_append_with_validation/4`
- [ ] Add underscore prefix to unused variables in other command handlers
- [ ] Add underscore prefix to unused variables in event handlers
- [ ] Add underscore prefix to unused variables in CoreComponents (col, action, item)
- [ ] Add underscore prefix to unused variables in ReplayCommands (reason in multiple functions)
- [ ] Add underscore prefix to unused variables in TestEventStore (events, expected_version, opts)
- [ ] Add underscore prefix to unused variables in BaseMode (team_id, state)
- [ ] Add underscore prefix to unused variables in RaceMode (state)
- [ ] Add underscore prefix to unused variables in TeamAggregate (state)
- [ ] Add underscore prefix to unused variables in EventStore.Adapter (opts, result)
- [ ] Add underscore prefix to unused variables in GameSessions.Cleanup (pid)
- [ ] Add underscore prefix to unused variables in Events module (state)
- [ ] Add underscore prefix to unused variables in ReplayCommands (user_id, game_events)
- [ ] Review and document intentionally unused variables

#### Unused Aliases (PARTIALLY COMPLETED)
- [x] Remove unused aliases from game modes
- [x] Remove unused aliases from game sessions
- [ ] Fix unused alias `Message` in `GameBot.Bot.Commands.TeamCommands`
- [ ] Fix unused alias `GameState` in `GameBot.Domain.GameModes.TwoPlayerMode`
- [ ] Fix unused alias `Metadata` in `GameBot.Domain.Events.BaseEvent`
- [ ] Fix unused alias `Interaction` in `GameBot.Bot.Commands.ReplayCommands`
- [ ] Fix unused alias `EventStore` in `GameBot.Domain.Commands.StatsCommands`
- [ ] Fix unused alias `Serializer` in `GameBot.Infrastructure.Persistence.EventStore.Adapter`
- [ ] Fix unused alias `BaseEvent` in `GameBot.Infrastructure.Persistence.EventStore.Serializer`
- [ ] Fix unused aliases in KnockoutMode (GameStarted, GuessProcessed, KnockoutRoundCompleted)
- [ ] Fix unused aliases in RaceMode (GameCompleted, GameStarted, GameState, GuessProcessed)
- [ ] Fix unused aliases in TwoPlayerMode (GameStarted, GameState)
- [ ] Fix unused aliases in TestHelpers (PlayerJoined)
- [ ] Remove unused aliases from event store
- [ ] Remove unused aliases from command handlers
- [ ] Update documentation to reflect removed aliases

### 3.3 Module Attribute Issues

- [ ] Fix module attribute `@impl` missing for function `ack/2` in `GameBot.Infrastructure.EventStore`
- [ ] Fix unused module attributes `@min_word_length` and `@max_word_length` in `GameBot.Bot.Listener`
- [ ] Fix unused module attribute `@base_fields` in `GameBot.Domain.Events.GameEvents`

### 3.4 Unused Functions and Clauses

- [x] Remove unused functions from listener module
- [ ] Clean up unused function `handle_transaction_error/2` in `GameBot.Infrastructure.Persistence.Repo.Transaction`
- [ ] Clean up unused function `transform_error/6` in `GameBot.Infrastructure.Persistence.EventStore.Adapter`
- [ ] Clean up unused function `handle_event/1` clause in `GameBot.Domain.Projections.GameProjection`
- [ ] Clean up unused import `Mix.Ecto` in migrate.ex
- [ ] Remove unused functions from other modules
- [ ] Document functions that appear unused but are needed

## Priority 4: API and Deprecation Fixes

These are important for future compatibility but don't affect current functionality.

### 4.1 Deprecation Fixes (COMPLETED)

#### Logger Updates
- [x] Replace Logger.warn in transaction module
- [x] Replace Logger.warn in event store adapter
- [x] Replace Logger.warn in game sessions recovery
- [x] Replace Logger.warn in other modules
- [x] Update log message formatting with proper context
- [x] Verify log levels are appropriate

#### Nostrum API Updates
- [x] Update `create_message/2` to `Message.create/2` in listener module
- [x] Update `create_message/2` to `Message.create/2` in dispatcher module
- [x] Update `create_interaction_response/3` to `Interaction.create_response/3` in error handler
- [x] Fix test mocking for Nostrum API modules
- [x] Test message creation in development environment
- [x] Add error handling for API calls

### 4.2 Configuration Access Updates (PARTIALLY COMPLETED)

- [x] Replace `Application.get_env/3` with `Application.compile_env/3` in listener module
- [ ] Replace `Application.get_env/3` with `Application.compile_env/3` in other modules
- [ ] Document configuration values in a central location
- [ ] Ensure consistent configuration access patterns

## Priority 5: Cleanup and Documentation

These are final polishing items for long-term maintainability.

### 5.1 Unused Function Cleanup

- [x] Remove unused functions from listener module
- [ ] Clean up unused function `handle_transaction_error/2` in `GameBot.Infrastructure.Persistence.Repo.Transaction`
- [ ] Clean up unused function `transform_error/6` in `GameBot.Infrastructure.Persistence.EventStore.Adapter`
- [ ] Clean up unused function `handle_event/1` clause in `GameBot.Domain.Projections.GameProjection`
- [ ] Remove unused functions from other modules
- [ ] Document functions that appear unused but are needed

### 5.2 Testing and Documentation

- [x] Fix test mocking for Nostrum API
- [ ] Create baseline test suite
- [ ] Add tests for each phase
- [ ] Create integration tests
- [ ] Update documentation across the system
- [ ] Add code examples and usage documentation

## Implementation Progress Summary

### Completed
- ✅ Fixed all critical functionality issues (Priority 1)
  - Fixed Metadata module references in StatsCommands
  - Implemented missing TeamProjection functions (create_team, update_team)
  - Added missing command handler functions for TeamCommands, StatsCommands, and ReplayCommands
  - Fixed Game Mode typing issues in TwoPlayerMode and RaceMode
  - Fixed Command Handler typing issues in StatsCommands and ReplayCommands
  - Fixed pattern matching issues in TestHelpers.simulate_game_sequence
  - Fixed GameProjection unknown key issues
  - Implemented `GameFinished.new/4` with proper documentation and type specs
  - Fixed incompatible types in ReplayCommands handlers
  - Fixed conflicting behaviours between EventStore and GenServer in TestEventStore
  - Added missing @impl annotation for ack/2 in EventStore
  - Updated BaseMode to use GameState.increment_guess_count/3 instead of /2
  - Fixed undefined Phoenix.Component.used_input?/1 in CoreComponents
  - Implemented validate_event functions in all game modes
- Fixed all critical EventStore-related warnings
- Added missing event fields and creation functions
- Standardized error handling across the codebase
- Updated all Logger and Nostrum API calls to latest versions
- Implemented proper EventStore behaviour in TestEventStore
- Fixed function definition issues with default parameters
- Added proper @impl annotations to behaviour implementations
- Added underscore prefix to many unused variables
- Removed numerous unused aliases
- Updated migration system to use current EventStore API

### In Progress
- Test coverage for new events and EventStore operations
- Function grouping and organization
- Addressing remaining Application.get_env deprecation warnings
- Adding underscore prefixes to remaining unused variables
- Removing unused aliases from other modules

### Next Steps
1. Complete remaining tests for timeout and validation errors (Priority 1.3)
2. Update all event tests to include new fields (Priority 2.1)
3. Add tests for all new event creation functions (Priority 2.1)
4. Add tests for behaviour implementations (Priority 2.2)
5. Move on to Priority 3 issues (Code Quality and Maintainability)

## Testing Guidelines

1. Each fix should include corresponding tests
2. Focus on testing critical functionality first
3. Add regression tests for fixed issues
4. Ensure tests cover error conditions

## Deployment Considerations

- High priority items should be addressed before merging new features
- Medium priority items should be fixed in the next cleanup phase
- Low priority items can be addressed during routine maintenance
- Consider feature flags for major changes 