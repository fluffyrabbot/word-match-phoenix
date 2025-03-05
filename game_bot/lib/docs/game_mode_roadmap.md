# Game Mode Implementation Roadmap

## Phase 1: Core Infrastructure (2-3 weeks)

### 1.1 Event Store Setup (Priority)
- [ ] Configure EventStore
  ```elixir
  config :game_bot, GameBot.EventStore,
    serializer: GameBot.EventStore.JSONSerializer,
    username: "postgres",
    password: "postgres",
    database: "game_bot_eventstore",
    hostname: "localhost"
  ```

- [ ] Implement event serialization
  ```elixir
  defmodule GameBot.EventStore.JSONSerializer do
    def serialize(term) do
      Jason.encode!(term)
    end

    def deserialize(binary, type) do
      Jason.decode!(binary)
      |> to_struct(type)
    end
  end
  ```

- [ ] Set up event subscriptions
  ```elixir
  defmodule GameBot.EventStore.Subscriptions do
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def init(_opts) do
      {:ok, %{subscriptions: %{}}}
    end

    def subscribe(stream_id, pid) do
      GenServer.call(__MODULE__, {:subscribe, stream_id, pid})
    end
  end
  ```

### 1.2 Session Management (Priority)
- [ ] Implement Session GenServer
  ```elixir
  defmodule GameBot.GameSessions.Session do
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts)
    end

    def init(opts) do
      {:ok, build_initial_state(opts)}
    end

    def handle_call({:process_guess, team_id, guess}, _from, state) do
      # Implementation
    end
  end
  ```

- [ ] Create Session Supervisor
  ```elixir
  defmodule GameBot.GameSessions.Supervisor do
    use DynamicSupervisor

    def start_link(opts) do
      DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def init(_opts) do
      DynamicSupervisor.init(strategy: :one_for_one)
    end
  end
  ```

### 1.3 Base Infrastructure
- [ ] Implement state persistence
- [ ] Add monitoring system
- [ ] Create cleanup processes

## Phase 2: Game Mode Testing (2-3 weeks)

### 2.1 Two Player Mode Testing
- [x] Core implementation complete
- [ ] Add event handling
- [ ] Implement state recovery
- [ ] Create integration tests

### 2.2 Knockout Mode Testing
- [x] Core implementation complete
- [ ] Add event handling
- [ ] Implement state recovery
- [ ] Create integration tests

## Phase 3: Core Infrastructure (1-2 weeks)

### 3.1 Base Game Mode Implementation
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

### 3.2 Game Session Management
- [ ] Implement `GameBot.GameSessions.Session` GenServer
- [ ] Create session supervisor
- [ ] Implement game state recovery from events
- [ ] Add pending guess timeout handling
- [ ] Implement paired guess processing

## Phase 4: Two Player Mode (1 week)

### 4.1 Core Implementation
- [ ] Implement `GameBot.Domain.GameModes.TwoPlayerMode`
- [ ] Add mode-specific event handlers
- [ ] Implement scoring and win condition logic
- [ ] Ensure proper guess count tracking for perfect rounds

### 4.2 Testing
- [ ] Unit tests for game logic
- [ ] Integration tests with session management
- [ ] Event reconstruction tests
- [ ] Verify guess pair processing:
  - First player submission
  - Second player completion
  - Timeout handling
  - Abandoned guess cleanup

## Phase 5: Knockout Mode (1-2 weeks)

### 5.1 Core Implementation
- [ ] Create elimination system
- [ ] Implement round timers
- [ ] Add team progression
- [ ] Handle guess count thresholds for elimination

### 5.2 Timer Management
- [ ] Add round timer implementation
- [ ] Handle timeout eliminations
- [ ] Implement round delay mechanics

## Phase 6: Race Mode (1 week)

### 6.1 Core Implementation
- [ ] Create match counting
- [ ] Implement game timer
- [ ] Add scoring system
- [ ] Track independent team progress

### 6.2 Scoring System
- [ ] Implement match tracking
- [ ] Add tiebreaker calculations based on average guess count
- [ ] Create score display formatting

## Phase 7: Golf Race Mode (1 week)

### 7.1 Core Implementation
- [ ] Create point system based on guess counts:
  - 1 guess = 4 points
  - 2-4 guesses = 3 points
  - 5-7 guesses = 2 points
  - 8-10 guesses = 1 point
  - 11+ guesses = 0 points
- [ ] Implement efficiency tracking
- [ ] Add game timer

### 7.2 Scoring System
- [ ] Implement point tracking
- [ ] Add efficiency calculations
- [ ] Create score display formatting

## Phase 8: Longform Mode (1-2 weeks)

### 8.1 Core Implementation
- [ ] Create day-based rounds
- [ ] Implement elimination system
- [ ] Add persistence handling
- [ ] Track cumulative team performance

## Phase 9: Discord Integration (1 week)

### 9.1 Command System
- [x] Implement command parsing
- [x] Create command routing through CommandHandler
- [x] Organize commands in dedicated modules
- [x] Add basic response formatting
- [ ] Add advanced response formatting

### 9.2 DM Management
- [ ] Implement word distribution
- [ ] Create guess handling
- [ ] Add player state tracking

## Phase 10: Testing and Optimization (1-2 weeks)

### 10.1 Comprehensive Testing
- [ ] Integration tests across all modes
- [ ] Load testing with multiple concurrent games
- [ ] Event reconstruction testing
- [ ] Verify guess count consistency across modes

### 10.2 Performance Optimization
- [ ] Add ETS caching where beneficial
- [ ] Optimize event retrieval
- [ ] Implement cleanup for completed games

### 10.3 Monitoring
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