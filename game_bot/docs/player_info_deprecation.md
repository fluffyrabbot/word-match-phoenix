# Player Info Type Deprecation

## Overview

This document outlines the changes made to deprecate the `player_info` type and specification in the GameBot system. The `player_info` type was previously used to store player information as a tuple `{discord_id, username, nickname}` or as a map `%{id: id, name: name}` in various events, particularly in guess events.

The decision to deprecate this type was made to simplify the event structure by using direct string references to player IDs (`player1_id` and `player2_id`) instead of the more complex nested structures.

## Changes Made

The following changes have been implemented to replace `player_info` with direct player ID references:

### 1. Event Definitions

- Updated `GuessProcessed` event to replace:
  - `player1_info: player_info_map()` → `player1_id: String.t()`
  - `player2_info: player_info_map()` → `player2_id: String.t()`

- Updated `GuessAbandoned` event to replace:
  - `player1_info: player_info_map()` → `player1_id: String.t()`
  - `player2_info: player_info_map()` → `player2_id: String.t()`

### 2. Type Definitions

- Removed `player_info` type definition from:
  - `GameBot.Domain.Events.EventStructure`
  - `GameBot.Domain.Events.Types`
  - `GameBot.Domain.Events.GuessEvents`

### 3. Event Creation and Processing

- Updated event creation in game modes to use player IDs directly:
  - `GameBot.Domain.GameModes.BaseMode.process_guess_pair`
  - `GameBot.Domain.GameModes.BaseMode.handle_guess_abandoned`
  - `GameBot.Domain.GameModes.Shared.Events.build_guess_processed`
  - `GameBot.Domain.GameModes.Shared.Events.build_guess_abandoned`
  - `GameBot.Domain.GameModes.RaceMode.handle_give_up`

### 4. Database Integration

- Updated `GameBot.Infrastructure.Repo.Schemas.Guess.create_from_event` to use player IDs directly

### 5. Validation Functions

- Added `validate_non_negative` function to `ValidationHelpers` for use in `GuessAbandoned`
- Fixed validation functions in `GuessAbandoned` to use proper validation helpers
- Removed `validate_player_info` and `validate_player_info_tuple` functions from `ValidationHelpers`

### 6. Module Removal

- Deleted `GameBot.Domain.Events.PlayerInfoType` module
- Deleted `GameBot.Domain.Events.PlayerInfoTypeTest` test module

### 7. Documentation Updates

- Updated `game_bot/lib/docs/events/type_specifications.md` to remove `player_info` type and update event definitions
- Updated `game_bot/lib/docs/domain/events/guess_processed.md` to use player IDs instead of player info
- Updated `game_bot/lib/docs/domain/events/guess_abandoned.md` to use player IDs instead of player info
- Updated `game_bot/lib/docs/events/event_system_conventions.md` to remove `player_info` type
- Updated `game_bot/lib/docs/infrastructure/event_store/schemav1.md` to remove `player_info` type and update event schemas

## Remaining Tasks

To fully deprecate the `player_info` type and complete the transition, the following tasks need to be completed:

1. **Delete PlayerInfoType Module** ✅
   - [x] Delete `game_bot/lib/game_bot/domain/events/player_info_type.ex`
   - [x] Delete `game_bot/test/game_bot/domain/events/player_info_type_test.exs`

2. **Update Validation Helpers** ✅
   - [x] Remove `validate_player_info` and `validate_player_info_tuple` functions from `ValidationHelpers`
   - [x] Add `validate_non_negative` function to `ValidationHelpers` for use in `GuessAbandoned`

3. **Fix GuessAbandoned Validation** ✅
   - [x] Fix validation functions in `GuessAbandoned` to use proper validation helpers
   - [x] Ensure `validate_string_value` and `validate_non_negative` are properly defined or imported

4. **Update Documentation** ✅
   - [x] Update `game_bot/lib/docs/events/type_specifications.md`
   - [x] Update `game_bot/lib/docs/domain/events/guess_processed.md`
   - [x] Update `game_bot/lib/docs/domain/events/guess_abandoned.md`
   - [x] Update `game_bot/lib/docs/events/event_system_conventions.md`
   - [x] Update `game_bot/lib/docs/infrastructure/event_store/schemav1.md`

5. **Testing**
   - [ ] Update tests that use `player_info` to use direct player IDs
   - [ ] Add tests to verify the new event structure works correctly
   - [ ] Ensure all existing functionality continues to work with the new structure

## Benefits of This Change

1. **Simplicity**: Direct string IDs are simpler to understand and work with than nested structures
2. **Performance**: Reduces the amount of data stored and processed in events
3. **Consistency**: Aligns with the use of direct IDs in other parts of the system
4. **Maintainability**: Reduces the number of custom types and conversions needed

## Potential Risks

1. **Code References**: Any code that expects the old structure will need updates
2. **Documentation**: All documentation referencing the old structure needs updates

## Conclusion

This deprecation simplifies our event model by removing an unnecessary level of indirection. Instead of storing player information as complex nested structures, we now use direct string references to player IDs, which is more efficient and easier to work with. 