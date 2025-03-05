# Game Session System

## Overview

The session system manages active game instances using GenServers, providing real-time state management and coordination between players. Each game session is a separate process that handles game state, player interactions, and game mode-specific logic. The system uses event sourcing for state persistence and recovery.

## Core Components

### Session GenServer (`GameBot.GameSessions.Session`)

Manages individual game sessions with the following responsibilities:
- State management for active games
- Player registration and tracking
- Guess validation and processing
- Round management and transitions
- Integration with game modes
- Event generation and persistence
- State recovery from events

#### State Structure
```elixir
%{
  game_id: String.t(),         # Unique identifier for the game
  mode: module(),              # Game mode module (e.g., TwoPlayerMode)
  mode_state: GameState.t(),   # Current game state
  teams: %{String.t() => team_state()},  # Team states
  started_at: DateTime.t(),    # Session start timestamp
  status: :initializing | :active | :completed,  # Current session status
  guild_id: String.t(),        # Discord server ID
  round_timer_ref: reference() | nil,  # Reference to round check timer
  pending_events: [Event.t()]  # Events pending persistence
}
```

### Session Supervisor (`GameBot.GameSessions.Supervisor`)

Dynamic supervisor that:
- Manages session lifecycle
- Handles session crashes
- Provides session lookup
- Manages cleanup of completed sessions

### Session Cleanup (`GameBot.GameSessions.Cleanup`)

Periodic cleanup process that:
- Removes completed/abandoned sessions
- Cleans up associated resources
- Maintains system health

### Event System Integration

The session integrates with the event store for:
1. **Event Generation**:
   - Game initialization events
   - Guess processing events
   - Round management events
   - Error events
   - Game completion events

2. **Event Persistence**:
   ```elixir
   # Event persistence flow
   generate_events()    # From game actions
   -> collect_events()  # Accumulate related events
   -> persist_events()  # Store in event store
   -> update_state()    # Apply event effects
   ```

3. **Event Types**:
   ```elixir
   # Core event types
   GameStarted        # Initial game setup
   GuessProcessed     # Guess handling
   GuessMatched      # Successful match
   GuessFailed       # Failed match
   GuessError        # Validation errors
   RoundEnded        # Round completion
   GameCompleted     # Game finish
   ```

## Key Interactions

1. **Game Mode Integration**
   ```elixir
   # Mode callbacks now return events
   @callback init(game_id, config) :: 
     {:ok, state, [Event.t()]} | {:error, term()}
   
   @callback process_guess_pair(state, team_id, guess_pair) :: 
     {:ok, new_state, [Event.t()]} | {:error, term()}
   
   @callback check_round_end(state) :: 
     {:round_end, winners, [Event.t()]} | :continue
   
   @callback check_game_end(state) :: 
     {:game_end, winners, [Event.t()]} | :continue
   ```

2. **Event Flow**
   ```elixir
   # Event handling flow
   handle_action()
   -> generate_events()
   -> persist_events()
   -> update_state()
   -> respond()
   ```

3. **Word Processing**
   ```elixir
   # Guess validation flow with events
   validate_guess(word)
   -> generate_validation_event()
   -> check_forbidden(word)
   -> record_guess(word)
   -> process_guess_pair()
   -> generate_result_event()
   -> persist_events()
   ```

## Implementation Status

### Completed
- [x] Basic GenServer structure
- [x] Player registration
- [x] Guess validation
- [x] Word matching integration
- [x] Forbidden word tracking
- [x] Basic state management
- [x] Round management
- [x] Round transitions
- [x] Event generation
- [x] Event persistence

### In Progress
- [ ] State recovery
- [ ] Error handling

### Pending
- [ ] State snapshots
- [ ] Performance optimization

## Implementation Plan

### Phase 1: Core Session Management
1. ✓ Implement round management
2. ✓ Add event system integration
3. Add state recovery

### Phase 2: Error Handling
1. Add comprehensive error handling
2. Implement error responses
3. Add logging system

### Phase 3: State Management
1. Add state snapshots
2. Add monitoring
3. Optimize performance

## Testing Strategy

1. **Unit Tests**
   - Session state management
   - Round transitions
   - Event generation
   - Event persistence
   - State recovery

2. **Integration Tests**
   - Game mode interaction
   - Event store integration
   - Recovery from events
   - Error handling

3. **Property Tests**
   - Event ordering
   - State consistency
   - Recovery correctness
   - Event persistence integrity

## Notes

- Sessions are temporary and will not be restarted on crash until state recovery is implemented
- Each session has a 24-hour maximum lifetime
- Cleanup runs every 5 minutes
- Round checks occur every 5 seconds
- All state changes generate events
- Events are persisted immediately after generation
- Event store provides the source of truth for game state

## Usage Examples

### Starting a Session
```elixir
GameBot.GameSessions.Supervisor.start_game(%{
  game_id: "game_123",
  mode: TwoPlayerMode,
  mode_config: config,
  teams: teams,
  guild_id: guild_id
})
```

### Submitting a Guess
```elixir
GameBot.GameSessions.Session.submit_guess(
  game_id,
  team_id,
  player_id,
  word
)
```

### Checking Game State
```elixir
GameBot.GameSessions.Session.get_state(game_id)
``` 