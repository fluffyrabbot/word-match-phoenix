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
   GuessFailed        # Failed match
   GuessError         # Validation errors
   RoundEnded         # Round completion
   GameCompleted      # Game finish
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
   # Enhanced guess validation flow
   validate_guess(word, player_id, state)
   -> find_player_team()           # Locate player's team
   -> check_existing_submission()  # Prevent duplicate guesses
   -> validate_word()             # Check word validity
   -> check_forbidden()           # Check forbidden status
   -> record_guess()             # Store in pending state
   -> process_guess_pair()       # If pair complete
   -> generate_result_event()    # Create appropriate event
   -> persist_events()           # Save to event store
   ```

### Guess State Management

The session now implements a robust guess handling system with the following features:

1. **Guess Validation Hierarchy**
   - Team membership verification
   - Duplicate submission prevention
   - Word validity checking
   - Forbidden word validation
   - Special command handling (e.g., "give up")

2. **Pending Guess States**
   ```elixir
   # First guess of a pair
   %{
     player_id: String.t(),
     word: String.t(),
     timestamp: DateTime.t()
   }

   # Complete guess pair
   %{
     player1_id: String.t(),
     player2_id: String.t(),
     player1_word: String.t(),
     player2_word: String.t()
   }
   ```

3. **Error Handling**
   - `:guess_already_submitted` - Player already has an active guess
   - `:invalid_word` - Word not in dictionary
   - `:forbidden_word` - Word is forbidden for the player
   - `:invalid_team` - Player not in a valid team
   - `:invalid_player` - Player not authorized for team
   - `:same_player` - Same player submitting both guesses

### Edge Cases and Recommended Improvements

1. **Out-of-Window Guesses**
   ```elixir
   # Recommended validation in validate_guess/3
   defp validate_guess(word, player_id, state) do
     cond do
       not is_active_game?(state) ->
         {:error, :game_not_active}
       
       not in_guess_window?(state, player_id) ->
         {:error, :not_guess_window}
         
       # ... existing validation ...
     end
   end
   ```

2. **Guess Window Management**
   ```elixir
   # Proposed guess window tracking
   %{
     game_id: String.t(),
     # ... existing state ...
     guess_windows: %{
       team_id => %{
         active: boolean(),
         starts_at: DateTime.t(),
         expires_at: DateTime.t() | nil
       }
     }
   }
   ```

3. **Rate Limiting**
   ```elixir
   # Recommended rate limiting structure
   %{
     player_guesses: %{
       player_id => %{
         last_guess: DateTime.t(),
         guess_count: integer()
       }
     },
     rate_limit: %{
       window_seconds: integer(),
       max_guesses: integer()
     }
   }
   ```

4. **Cleanup Recommendations**
   - Implement periodic cleanup of stale pending guesses
   - Add timeout for incomplete guess pairs
   - Clear player guess history on round transitions
   - Handle disconnected player scenarios

5. **Additional Validations**
   - Maximum word length checks
   - Minimum word length requirements
   - Character set validation
   - Language detection
   - Profanity filtering
   - Spam detection

### Architectural Validation Layers

1. **Discord Listener Layer** (`GameBot.Bot.Listener`)
   ```elixir
   # First line of defense
   def handle_message(msg) do
     with :ok <- validate_rate_limit(msg.author_id),
          :ok <- validate_message_format(msg.content),
          :ok <- basic_spam_check(msg) do
       forward_to_dispatcher(msg)
     end
   end
   ```
   Responsibilities:
   - Rate limiting
   - Basic message validation
   - Spam detection
   - Character set validation
   - Message length checks
   - Profanity filtering

2. **Command Dispatcher** (`GameBot.Bot.Dispatcher`)
   ```elixir
   # Command routing and game state checks
   def dispatch_command(msg) do
     with {:ok, game_id} <- lookup_active_game(msg.author_id),
          {:ok, game_state} <- verify_game_active(game_id),
          {:ok, command} <- parse_command(msg.content) do
       route_to_handler(command, game_state)
     end
   end
   ```
   Responsibilities:
   - Command parsing
   - Game existence validation
   - Basic game state checks
   - Player registration verification

3. **Command Handler** (`GameBot.Bot.CommandHandler`)
   ```elixir
   # Game-specific command validation
   def handle_guess(game_id, player_id, word) do
     with {:ok, game} <- fetch_game(game_id),
          :ok <- validate_player_in_game(game, player_id),
          :ok <- validate_game_phase(game),
          :ok <- validate_guess_window(game, player_id) do
       forward_to_session(game_id, player_id, word)
     end
   end
   ```
   Responsibilities:
   - Game phase validation
   - Player participation checks
   - Guess window validation
   - Basic game rule enforcement

4. **Session Layer** (`GameBot.GameSessions.Session`)
   ```elixir
   # Game state and rule enforcement
   def submit_guess(game_id, team_id, player_id, word) do
     with :ok <- validate_game_rules(state, team_id, player_id),
          :ok <- validate_no_duplicate_guess(state, player_id),
          {:ok, new_state} <- record_guess(state, team_id, player_id, word) do
       process_game_state(new_state)
     end
   end
   ```
   Responsibilities:
   - Game rule enforcement
   - State management
   - Guess pairing logic
   - Team coordination
   - Score tracking

5. **Game Mode Layer** (`GameBot.Domain.GameModes.*`)
   ```elixir
   # Game mode specific logic
   def process_guess_pair(state, team_id, guess_pair) do
     with :ok <- validate_mode_rules(state, team_id),
          {:ok, new_state} <- apply_guess_pair(state, team_id, guess_pair) do
       calculate_results(new_state)
     end
   end
   ```
   Responsibilities:
   - Mode-specific rules
   - Scoring logic
   - Win conditions
   - Round management

### Implementation Status

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