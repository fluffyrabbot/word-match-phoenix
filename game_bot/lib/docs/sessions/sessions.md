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
  round_start_time: DateTime.t(), # Timestamp when current round started
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

2. **Event Persistence with Retry**:
   ```elixir
   # Event persistence flow with exponential backoff retry
   defp persist_events(events, state, retries) when retries > 0 do
     case EventStore.append_to_stream(state.game_id, :any_version, events, []) do
       :ok -> :ok
       
       # Retry on transient failures with exponential backoff
       {:error, reason} 
       when reason == :connection_timeout or
              reason == :database_unavailable or
              reason == :timeout or
              (is_tuple(reason) and elem(reason, 0) == :shutdown) and retries > 1 ->
         delay = trunc(:math.pow(2, (3 - retries)) * 50) # 50ms -> 100ms -> 200ms
         Process.sleep(delay)
         persist_events(events, state, retries - 1)

       # Permanent failure
       {:error, reason} ->
         {:error, reason}
     end
   end
   ```

3. **Event Types**:
   ```elixir
   # Core event types
   GameStarted        # Initial game setup
   GuessProcessed     # Guess handling
   GuessFailed        # Failed match
   GuessError         # Validation errors
   GuessPairError     # Errors processing a pair
   RoundEnded         # Round completion
   RoundCheckError    # Errors checking round state
   GameCompleted      # Game finish
   ```

## Key Interactions

1. **Game Mode Integration**
   ```elixir
   # Mode callbacks now return events
   @callback init(game_id, teams, config) :: 
     {:ok, state, [Event.t()]} | {:error, term()}
   
   @callback process_guess_pair(state, team_id, guess_pair) :: 
     {:ok, new_state, [Event.t()]} | {:error, term()}
   
   @callback check_round_end(state) :: 
     {:round_end, winners, [Event.t()]} | :continue | {:error, term()}
   
   @callback check_game_end(state) :: 
     {:game_end, winners, [Event.t()]} | :continue
     
   @callback update_round_results(state, winners) ::
     {:ok, new_state, [Event.t()]} | {:error, term()}
     
   @callback start_new_round(state) ::
     {:ok, new_state, [Event.t()]} | {:error, term()}
   ```

2. **Event Flow**
   ```elixir
   # Event handling flow
   handle_action()
   -> generate_events()
   -> persist_events()  # With retry mechanism
   -> update_state()
   -> respond()
   ```

3. **Word Processing with Timing**
   ```elixir
   # Enhanced guess validation flow with timing information
   validate_guess(word, player_id, state)
   -> find_player_team()            # Locate player's team
   -> check_existing_submission()   # Prevent duplicate guesses
   -> validate_word()               # Check word validity
   -> check_forbidden()             # Check forbidden status
   -> record_guess_with_timestamp() # Store in pending state with timing
   -> process_guess_pair()          # If pair complete
   -> generate_result_event()       # Create appropriate event
   -> persist_events()              # Save to event store with retry
   ```

### Guess State Management

The session implements a robust guess handling system with the following features:

1. **Guess Validation Hierarchy**
   - Team membership verification
   - Duplicate submission prevention
   - Word validity checking
   - Forbidden word validation
   - Special command handling (e.g., "give up")
   - Guild context validation

2. **Pending Guess States with Timing**
   ```elixir
   # First guess of a pair
   %{
     player_id: String.t(),
     word: String.t(),
     timestamp: DateTime.t()  # Actual submission time
   }

   # Complete guess pair with timing information
   %{
     player1_id: String.t(),
     player2_id: String.t(),
     player1_word: String.t(),
     player2_word: String.t(),
     player1_timestamp: DateTime.t(),
     player2_timestamp: DateTime.t(),
     player1_duration: integer(),  # Milliseconds from round start
     player2_duration: integer()   # Milliseconds from round start
   }
   ```

3. **Error Handling with Error Events**
   - `:guess_already_submitted` - Player already has an active guess
   - `:invalid_word` - Word not in dictionary or empty
   - `:forbidden_word` - Word is forbidden for the player
   - `:not_in_guild` - Player not in the correct guild
   - `:player_not_in_game` - Player not authorized for team
   - `GuessError`, `GuessPairError`, `RoundCheckError` events capture failure details

### Round Management

The session implements automatic round management:

1. **Round Checking**
   ```elixir
   # Periodic round checks
   @round_check_interval :timer.seconds(5)  # Check every 5 seconds
   
   defp schedule_round_check(state) do
     if state.round_timer_ref, do: Process.cancel_timer(state.round_timer_ref)
     Process.send_after(self(), :check_round_status, @round_check_interval)
   end
   ```

2. **Round Transitions**
   ```elixir
   # Flow for round transitions
   check_round_end()
   -> {:round_end, winners, events}
   -> update_round_results()        # Update scores and stats
   -> persist_events()
   -> check_game_end()              # Check if game should end
   -> start_new_round()             # If game continues
   -> reset_round_start_time()      # Track new round timing
   ```

3. **Timing-aware State Tracking**
   - `round_start_time` tracks when each round begins
   - Guess durations are calculated relative to round start
   - Timestamps are captured at each submission for precise timing

### Game Completion

1. **Game End Conditions**
   ```elixir
   # Game completion flow
   check_game_end()
   -> {:game_end, winners, events}
   -> compute_final_scores()      # Generate detailed stats
   -> create_game_completed()     # Create GameCompleted event
   -> persist_events()            # Persist final events
   -> unregister_players()        # Clean up player registrations
   -> update_status(:completed)   # Mark session as complete
   ```

2. **Score Computation**
   ```elixir
   # Detailed final score calculation
   defp compute_final_scores(state) do
     Enum.into(state.teams, %{}, fn {team_id, team_state} ->
       {team_id, %{
         score: team_state.score,
         matches: team_state.matches,
         total_guesses: team_state.total_guesses,
         average_guesses: compute_average_guesses(team_state),
         player_stats: compute_player_stats(team_state)
       }}
     end)
   end
   ```

### Player Management

1. **Active Game Registration**
   ```elixir
   # Register players in the active games ETS table
   defp register_players(%{teams: teams, game_id: game_id}) do
     for {_team_id, %{player_ids: player_ids}} <- teams,
         player_id <- player_ids,
         CommandHandler.get_active_game(player_id, game_id) == nil do
       CommandHandler.set_active_game(player_id, game_id, game_id)
     end
   end
   
   # Unregister on game completion or termination
   defp unregister_players(%{teams: teams, game_id: game_id}) do
     for {_team_id, %{player_ids: player_ids}} <- teams,
         player_id <- player_ids do
       CommandHandler.clear_active_game(player_id, game_id)
     end
   end
   ```

### Edge Cases and Error Handling

1. **Event Persistence Retry**
   - Exponential backoff for transient failures (50ms -> 100ms -> 200ms)
   - Distinguishes between retryable and permanent failures
   - Maximum 3 retry attempts for database connectivity issues
   - Graceful degradation on permanent failures

2. **Process Lifecycle Management**
   ```elixir
   # Proper cleanup on termination
   def terminate(_reason, state) do
     # Cancel any pending timers
     if state.round_timer_ref, do: Process.cancel_timer(state.round_timer_ref)
     
     # Clean up player registrations
     unregister_players(state)
     :ok
   end
   ```

3. **Guild Context Validation**
   ```elixir
   # Ensure player belongs to the correct guild
   defp validate_guild_context(_word, player_id, %{guild_id: guild_id} = _state) do
     if player_in_guild?(player_id, guild_id) do
       :ok
     else
       {:error, :not_in_guild}
     end
   end
   ```

### Architectural Validation Layers

The session implements a multi-layered validation approach:

1. **Initial Command Validation**
   - Word validity (non-empty, in dictionary)
   - Player authorization (in guild, in team)
   - Duplicate guess detection

2. **Game State Validation**
   - Current game status checks
   - Round timing validation
   - Team membership verification

3. **Game Rule Enforcement**
   - Mode-specific rule application
   - Forbidden word checking
   - Team coordination rules

4. **Event Persistence Guarantees**
   - Retry mechanism for transient failures
   - Clear error reporting
   - State consistency preservation

### Implementation Status

### Completed
- [x] Basic GenServer structure
- [x] Player registration and tracking
- [x] Guess validation with timing
- [x] Word matching integration
- [x] Forbidden word tracking
- [x] Robust state management
- [x] Round management with timed checking
- [x] Round transitions
- [x] Event generation
- [x] Event persistence with retry
- [x] Guild context validation
- [x] Detailed score computation
- [x] Proper process lifecycle management

### In Progress
- [ ] Enhanced error handling
- [ ] Performance optimization

### Pending
- [ ] State snapshots
- [ ] State recovery from events

## Implementation Plan

### Phase 1: Reliability Enhancements (Current)
1. ✓ Improve event persistence with retry logic
2. ✓ Add detailed error events
3. ✓ Enhance timing precision for guesses
4. [ ] Complete robust error handling

### Phase 2: Performance Optimization
1. [ ] Add state snapshots
2. [ ] Optimize event persistence
3. [ ] Add monitoring and metrics

### Phase 3: Resilience
1. [ ] Implement state recovery from events
2. [ ] Add distributed session management
3. [ ] Implement horizontal scaling

## Constants and Configurations

- **Round Check Interval**: 5 seconds (`@round_check_interval :timer.seconds(5)`)
- **Event Persistence Retries**: 3 attempts with exponential backoff
- **Retry Delays**: 50ms -> 100ms -> 200ms

## Notes

- Sessions are transient and won't restart on crash until state recovery is implemented
- All state changes generate events that are persisted immediately
- Guild context validation ensures players belong to the correct Discord server
- Timing information is tracked with millisecond precision relative to round start
- Round checks occur automatically every 5 seconds
- Event persistence includes retry logic for transient database failures

## Usage Examples

### Starting a Session
```elixir
# Create a game from a GameStarted event
GameBot.GameSessions.Session.create_game(%GameEvents.GameStarted{
  game_id: "game_123",
  mode: GameBot.Domain.GameModes.TwoPlayerMode,
  config: %{rounds: 3},
  guild_id: "discord_guild_123",
  teams: %{"team1" => %{player_ids: ["player1", "player2"]}}
})
```

### Submitting a Guess
```elixir
# Submit a guess and get the result
GameBot.GameSessions.Session.submit_guess(
  "game_123",
  "team1",
  "player1",
  "apple"
)
```

### Checking Game State
```elixir
# Get the current game state
{:ok, state} = GameBot.GameSessions.Session.get_state("game_123")
```

### Manually Checking Round End
```elixir
# Manually trigger a round end check
GameBot.GameSessions.Session.check_round_end("game_123")
``` 