# Game Mode Implementation TODO

This document outlines the tasks required to implement the remaining game modes: GolfRaceMode and LongformMode.

## Priority Order
1. GolfRaceMode implementation
2. LongformMode implementation

## GolfRaceMode Implementation

GolfRaceMode is a timed competition where teams earn points based on how efficiently they match words, similar to golf scoring (fewer guesses = more points).

### Core Implementation Tasks

- [ ] **Module Structure**
  - [ ] Implement `GameBot.Domain.GameModes.GolfRaceMode` module
  - [ ] Define required callbacks from `BaseMode` behaviour
  - [ ] Define GolfRaceMode-specific types and structs

- [ ] **State Management**
  - [ ] Define state structure with:
    - [ ] Time limit (default 3 minutes)
    - [ ] Points tracking by team
    - [ ] Matches tracking by team
    - [ ] Start time tracking

- [ ] **Scoring System**
  - [ ] Implement scoring rules:
    - [ ] 4 points: 1 guess (perfect round)
    - [ ] 3 points: 2-4 guesses
    - [ ] 2 points: 5-7 guesses
    - [ ] 1 point: 8-10 guesses
    - [ ] 0 points: 11+ guesses
    - [ ] -1 point: Giving up on a round

- [ ] **Game Logic**
  - [ ] Implement `init/3` function
    - [ ] Validate team requirements (minimum 2 teams)
    - [ ] Initialize state with time limit and scoring
  - [ ] Implement `process_guess_pair/3` function
    - [ ] Handle successful matches with point allocation
    - [ ] Handle failed matches
    - [ ] Handle "give up" command with point penalty
  - [ ] Implement `check_game_end/1` function
    - [ ] Check time expiration
    - [ ] Determine winners based on points
    - [ ] Handle tiebreakers (lowest average guesses, then total matches)

- [ ] **Events**
  - [ ] Define and implement GolfRaceMode-specific events
  - [ ] Ensure proper event generation for scoring and game completion

- [ ] **Testing**
  - [ ] Unit tests for scoring system
  - [ ] Integration tests for game flow
  - [ ] Edge case tests (ties, time expiration, etc.)

## LongformMode Implementation

LongformMode is a multi-day game mode where teams compete over extended periods with daily eliminations.

### Core Implementation Tasks

- [ ] **Module Structure**
  - [ ] Implement `GameBot.Domain.GameModes.LongformMode` module
  - [ ] Define required callbacks from `BaseMode` behaviour
  - [ ] Define LongformMode-specific types and structs

- [ ] **State Management**
  - [ ] Define state structure with:
    - [ ] Round duration (default 24 hours)
    - [ ] Eliminated teams tracking
    - [ ] Round start time tracking
    - [ ] Round number tracking

- [ ] **Game Logic**
  - [ ] Implement `init/3` function
    - [ ] Validate team requirements
    - [ ] Initialize state with round duration
  - [ ] Implement `process_guess_pair/3` function
    - [ ] Handle successful matches
    - [ ] Handle failed matches
  - [ ] Implement `check_round_end/1` function
    - [ ] Check time expiration for rounds
    - [ ] Determine teams to eliminate
    - [ ] Handle tie scenarios for elimination
  - [ ] Implement `check_game_end/1` function
    - [ ] Check if only one team remains

- [ ] **Elimination Logic**
  - [ ] Implement team elimination based on highest guess count
  - [ ] Handle tie scenarios for elimination
  - [ ] Ensure proper event generation for eliminations

- [ ] **Events**
  - [ ] Define and implement LongformMode-specific events
  - [ ] Create `LongformDayEnded` event
  - [ ] Ensure proper event generation for day transitions

- [ ] **Testing**
  - [ ] Unit tests for elimination logic
  - [ ] Integration tests for multi-day flow
  - [ ] Time-based tests (simulating day transitions)

## Common Tasks for Both Modes

- [ ] **Documentation**
  - [ ] Add comprehensive @moduledoc and @doc strings
  - [ ] Document public functions with @spec annotations
  - [ ] Add examples to function documentation

- [ ] **Integration with Session Manager**
  - [ ] Ensure proper interaction with `GameBot.GameSessions.Session`
  - [ ] Verify event handling and persistence

- [ ] **UI/UX Considerations**
  - [ ] Define user-facing messages for mode-specific events
  - [ ] Ensure clear communication of game state to players

- [ ] **Performance Testing**
  - [ ] Test with maximum player/team counts
  - [ ] Verify memory usage and event throughput

## Implementation Guidelines

1. Follow existing patterns from RaceMode and KnockoutMode implementations
2. Maintain consistent error handling and validation approaches
3. Ensure proper event generation and persistence
4. Use BaseMode utility functions where appropriate
5. Follow functional programming principles and pattern matching
6. Maintain clear module boundaries (no direct DB or Discord dependencies)
7. Use 2-space indentation and follow Elixir style guidelines

## References

- `game_bot/lib/docs/game_mode_implementation.md` - Technical specifications
- `game_bot/lib/docs/gamemoderules.md` - Game rules documentation
- `game_bot/lib/game_bot/domain/game_modes/base_mode.ex` - Base behavior and utilities
- `game_bot/lib/game_bot/domain/game_modes/race_mode.ex` - Reference implementation for timed modes
- `game_bot/lib/game_bot/game_sessions/session.ex` - Session management integration 