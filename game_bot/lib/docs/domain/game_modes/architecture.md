# Game Modes Architecture

## Overview

The game modes system is built on a modular architecture that separates common game functionality from mode-specific behavior. This design allows for maximum code reuse while maintaining flexibility for different game modes.

## Core Principles

1. **Event-Driven Architecture**
   - All game state changes are driven by events
   - Events are immutable and versioned
   - State can be reconstructed from event stream

2. **Mode Isolation**
   - Each mode is self-contained
   - Common functionality in BaseMode
   - Mode-specific logic properly encapsulated

3. **Validation First**
   - All events validated before processing
   - State transitions explicitly validated
   - Team and player validation standardized

4. **Consistent Error Handling**
   - Error types standardized across modes
   - Clear error messages for debugging
   - Graceful failure handling

## Module Structure

```
game_bot/lib/game_bot/domain/game_modes/
├── base_mode.ex              # Core behavior and common functionality
├── behaviours/
│   ├── game_mode.ex         # Behaviour specification
│   └── round_manager.ex     # Round management behaviour
├── implementations/
│   ├── two_player_mode.ex   # Standard two-player implementation
│   ├── knockout_mode.ex     # Tournament-style elimination mode
│   └── race_mode.ex         # Time-based racing mode
└── shared/
    ├── state.ex             # Common state management
    ├── validation.ex        # Shared validation logic
    └── events.ex            # Common event building
```

## Core Behaviors

### GameMode Behavior
```elixir
defmodule GameBot.Domain.GameModes.Behaviour.GameMode do
  @callback init(game_id(), teams(), config()) ::
    {:ok, state(), [Event.t()]} | {:error, term()}

  @callback process_guess_pair(state(), team_id(), guess_pair()) ::
    {:ok, state(), [Event.t()]} | {:error, term()}

  @callback check_round_end(state()) ::
    {:round_end, state()} | :continue | {:error, term()}

  @callback check_game_end(state()) ::
    {:game_end, [winner_id()]} | :continue
end
```

### RoundManager Behavior
```elixir
defmodule GameBot.Domain.GameModes.Behaviour.RoundManager do
  @callback start_round(state()) ::
    {:ok, state(), [Event.t()]} | {:error, term()}

  @callback end_round(state()) ::
    {:ok, state(), [Event.t()]} | {:error, term()}
end
```

## Base Mode Implementation

The BaseMode provides core functionality used by all game modes:

1. **Event Generation**
   - Common event building
   - Metadata generation
   - Event validation

2. **State Management**
   - Team state tracking
   - Round management
   - Game progression

3. **Validation**
   - Team requirements
   - Event structure
   - State transitions

```elixir
defmodule GameBot.Domain.GameModes.BaseMode do
  # Common validation for all modes
  def validate_teams(teams, :exact, team_count, mode_name) do
    if map_size(teams) != team_count do
      {:error, {:invalid_team_count, "#{mode_name} mode requires exactly #{team_count} team(s)"}}
    else
      :ok
    end
  end

  def validate_teams(teams, :minimum, team_count, mode_name) do
    if map_size(teams) < team_count do
      {:error, {:invalid_team_count, "#{mode_name} mode requires at least #{team_count} team(s)"}}
    else
      :ok
    end
  end

  # Event validation for all modes
  def validate_event(event, expected_mode, team_requirements \\ :minimum, team_count \\ 1) do
    with :ok <- validate_mode(event, expected_mode),
         :ok <- validate_teams(event.teams, team_requirements, team_count) do
      :ok
    end
  end
end
```

## Mode-Specific Implementations

### Two Player Mode
- Fixed number of rounds
- Success threshold for average guesses
- Both players must participate
- Simple scoring based on guess count

### Knockout Mode
- Tournament-style elimination
- Time-based rounds
- Progressive difficulty
- Team elimination mechanics

### Race Mode
- Time-based competition
- Asynchronous team play
- Points for successful matches
- Speed-based scoring

## Event Flow

1. **Game Initialization**
   ```
   init() -> GameStarted -> RoundStarted
   ```

2. **Guess Processing**
   ```
   process_guess_pair() -> GuessProcessed -> [Conditional Events]
   ```

3. **Round Management**
   ```
   check_round_end() -> RoundCompleted? -> RoundStarted/GameCompleted
   ```

## State Management

Each mode maintains its state through the `GameState` struct:

```elixir
defmodule GameBot.Domain.GameState do
  defstruct [
    mode: nil,                    # Module implementing the game mode
    teams: %{},                   # Map of team_id to team_state
    round_number: 1,             # Current round number
    start_time: nil,             # Game start timestamp
    last_activity: nil,          # Last guess timestamp
    matches: [],                 # List of successful matches
    status: :waiting             # Game status
  ]
end
```

## Testing Strategy

1. **Unit Tests**
   - Base mode functionality
   - Mode-specific logic
   - Event validation

2. **Integration Tests**
   - Full game sequences
   - Event store integration
   - State reconstruction

3. **Property Tests**
   - State transitions
   - Event sequences
   - Recovery scenarios

## Implementation Guidelines

1. **Event Generation**
   - Always validate before emission
   - Include all required metadata
   - Maintain event ordering

2. **State Updates**
   - Atomic state transitions
   - Validate before update
   - Handle edge cases

3. **Error Handling**
   - Clear error messages
   - Proper error types
   - Graceful degradation

4. **Recovery**
   - Full state reconstruction
   - Event sequence validation
   - Proper error handling

## Migration Status

1. ✅ Core Behaviors Defined
2. ✅ Base Mode Implementation
3. ✅ Two Player Mode
4. ✅ Knockout Mode
5. 🔶 Race Mode (In Progress)
6. ❌ Golf Mode (Planned)
7. ❌ Longform Mode (Planned) 