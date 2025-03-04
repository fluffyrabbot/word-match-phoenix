# Game Mode Implementation Roadmap

## Phase 1: Core Infrastructure (1-2 weeks)

### 1.1 Base Game Mode Implementation
- [x] Implement `GameBot.Domain.GameModes.BaseMode` behavior
  ```elixir
  defmodule GameBot.Domain.GameModes.BaseMode do
    @callback init(config :: term()) :: {:ok, state :: GameState.t()} | {:error, term()}
    @callback process_guess_pair(state :: GameState.t(), team_id :: String.t(), guess_pair :: guess_pair()) :: 
      {:ok, new_state :: GameState.t(), event :: Event.t()} | 
      {:error, term()}
    @callback handle_guess_abandoned(state :: GameState.t(), team_id :: String.t(), reason :: :timeout | :player_quit, last_guess :: map() | nil) ::
      {:ok, new_state :: GameState.t(), event :: Event.t()} |
      {:error, term()}
    @callback check_round_end(state :: GameState.t()) :: 
      {:round_end, winners :: [team_id()]} | 
      :continue
    @callback check_game_end(state :: GameState.t()) :: 
      {:game_end, winners :: [team_id()]} | 
      :continue
    
    # Common behavior implementation for all modes
    def initialize_team_state(player_ids) do
      %{
        player_ids: player_ids,
        current_words: [],
        guess_count: 1,  # Start at 1 for first attempt
        pending_guess: nil
      }
    end

    def handle_failed_match(team_state) do
      %{team_state | 
        guess_count: team_state.guess_count + 1,
        pending_guess: nil  # Clear pending guess on failure
      }
    end
  end
  ```

### 1.2 Event Store Setup
- [ ] Configure EventStore for game events
- [ ] Implement event serialization/deserialization
- [ ] Set up event subscriptions for game reconstruction
- [ ] Define core event structures:
  ```elixir
  defmodule GameBot.Domain.Events do
    defmodule GameStarted do
      defstruct [:game_id, :mode, :teams, :timestamp]
    end

    defmodule GuessProcessed do
      defstruct [:game_id, :team_id, :player1_id, :player2_id, 
                :player1_word, :player2_word, :guess_successful,
                :guess_count, :timestamp]
    end

    defmodule GuessAbandoned do
      defstruct [:game_id, :team_id, :reason, :last_guess, 
                :guess_count, :timestamp]
    end
  end
  ```

### 1.3 Game Session Management
- [ ] Implement `GameBot.GameSessions.Session` GenServer
- [ ] Create session supervisor
- [ ] Implement game state recovery from events
- [ ] Add pending guess timeout handling
- [ ] Implement paired guess processing

## Phase 2: Two Player Mode (1 week)

### 2.1 Core Implementation
- [ ] Implement `GameBot.Domain.GameModes.TwoPlayerMode`
- [ ] Add mode-specific event handlers
- [ ] Implement scoring and win condition logic
- [ ] Ensure proper guess count tracking for perfect rounds

### 2.2 Testing
- [ ] Unit tests for game logic
- [ ] Integration tests with session management
- [ ] Event reconstruction tests
- [ ] Verify guess pair processing:
  - First player submission
  - Second player completion
  - Timeout handling
  - Abandoned guess cleanup

## Phase 3: Knockout Mode (1-2 weeks)

### 3.1 Core Implementation
- [ ] Create elimination system
- [ ] Implement round timers
- [ ] Add team progression
- [ ] Handle guess count thresholds for elimination

### 3.2 Timer Management
- [ ] Add round timer implementation
- [ ] Handle timeout eliminations
- [ ] Implement round delay mechanics

## Phase 4: Race Mode (1 week)

### 4.1 Core Implementation
- [ ] Create match counting
- [ ] Implement game timer
- [ ] Add scoring system
- [ ] Track independent team progress

### 4.2 Scoring System
- [ ] Implement match tracking
- [ ] Add tiebreaker calculations based on average guess count
- [ ] Create score display formatting

## Phase 5: Golf Race Mode (1 week)

### 5.1 Core Implementation
- [ ] Create point system based on guess counts:
  - 1 guess = 4 points
  - 2-4 guesses = 3 points
  - 5-7 guesses = 2 points
  - 8-10 guesses = 1 point
  - 11+ guesses = 0 points
- [ ] Implement efficiency tracking
- [ ] Add game timer

### 5.2 Scoring System
- [ ] Implement point tracking
- [ ] Add efficiency calculations
- [ ] Create score display formatting

## Phase 6: Longform Mode (1-2 weeks)

### 6.1 Core Implementation
- [ ] Create day-based rounds
- [ ] Implement elimination system
- [ ] Add persistence handling
- [ ] Track cumulative team performance

## Phase 7: Discord Integration (1 week)

### 7.1 Command System
- [ ] Implement command parsing
- [ ] Create command routing
- [ ] Add response formatting

### 7.2 DM Management
- [ ] Implement word distribution
- [ ] Create guess handling
- [ ] Add player state tracking

## Phase 8: Testing and Optimization (1-2 weeks)

### 8.1 Comprehensive Testing
- [ ] Integration tests across all modes
- [ ] Load testing with multiple concurrent games
- [ ] Event reconstruction testing
- [ ] Verify guess count consistency across modes

### 8.2 Performance Optimization
- [ ] Add ETS caching where beneficial
- [ ] Optimize event retrieval
- [ ] Implement cleanup for completed games

### 8.3 Monitoring
- [ ] Add session monitoring
- [ ] Implement error tracking
- [ ] Create performance metrics

## Implementation Notes

### Directory Structure
All implementations should follow the existing structure in `lib/game_bot/`:
- Core game mode logic in `domain/game_modes/`
- Events in `domain/events/`
- Session management in `game_sessions/`
- Infrastructure in `infrastructure/`

### Testing Strategy
1. Unit test each game mode independently
2. Integration test with session management
3. End-to-end test with Discord commands
4. Load test with multiple concurrent games
5. Verify guess count behavior in all scenarios

### Deployment Considerations
1. Ensure proper event store configuration
2. Set up monitoring for game sessions
3. Configure appropriate timeouts
4. Implement graceful recovery procedures

Total Estimated Timeline: 8-12 weeks 