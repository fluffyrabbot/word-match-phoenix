# GameSessions System

## Architecture Overview

The GameSessions system provides a resilient, event-sourced architecture for managing game state across multiple concurrent game instances. Each game exists as an isolated process with its own lifecycle, enabling concurrent gameplay across multiple Discord servers while maintaining reliable state management.

```
┌──────────────────────────────────────────────────┐
│                Bot Command Layer                 │
└──────────────────┬───────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────────┐
│             GameSessions.Supervisor              │
│                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────┐  │
│  │  Session 1  │  │  Session 2  │  │    ...   │  │
│  └─────────────┘  └─────────────┘  └──────────┘  │
└──────────────────────────────────────────────────┘
                   │
                   ▼
┌───────────────────────┐    ┌─────────────────────┐
│     Event Store       │    │  GameSessions.      │
│                       │◄───┤     Cleanup         │
└───────────────────────┘    └─────────────────────┘
                   ▲
                   │
┌──────────────────────────────────────────────────┐
│          GameSessions.Recovery                   │
└──────────────────────────────────────────────────┘
```

## Core Components

### Session (`GameBot.GameSessions.Session`)

The Session module is the heart of the game session system, responsible for:

- Managing game state throughout its lifecycle
- Processing player guesses with timing information
- Coordinating round transitions
- Generating and persisting events
- Handling error conditions with graceful degradation

#### State Lifecycle

```
┌─────────────┐     ┌────────────┐     ┌────────────┐
│             │     │            │     │            │
│ Initializing├────►│   Active   ├────►│ Completed  │
│             │     │            │     │            │
└─────────────┘     └────────────┘     └────────────┘
```

#### Key Functions

```elixir
# Create a new game session
create_game(%GameEvents.GameStarted{}) :: {:ok, pid()} | {:error, term()}

# Submit a guess (sync)
submit_guess(game_id, team_id, player_id, word) :: {:ok, :match | :no_match} | {:error, reason}

# Get current game state
get_state(game_id) :: {:ok, state} | {:error, reason}

# Check if round should end
check_round_end(game_id) :: {:reply, :continue | {:round_end, winners}, state}

# Check if game should end
check_game_end(game_id) :: {:reply, {:ok, :continue | :game_completed}, state}
```

### Supervisor (`GameBot.GameSessions.Supervisor`)

Dynamic supervisor that manages the lifecycle of game sessions, with:

- One-for-one supervision strategy
- Temporary child processes (no restart on failure)
- Clean start/stop mechanisms

#### API

```elixir
# Start a new game under supervision
start_game(opts) :: {:ok, pid()} | {:error, term()}

# Stop a running game
stop_game(game_id) :: :ok | {:error, :not_found}
```

### Cleanup (`GameBot.GameSessions.Cleanup`)

Manages the cleanup of stale or completed game sessions:

- Runs every 5 minutes automatically
- Terminates sessions older than 24 hours
- Ensures resource reclamation for abandoned games

#### Configuration

- **Cleanup Interval**: 5 minutes (`@cleanup_interval :timer.minutes(5)`)
- **Session Timeout**: 24 hours (`@session_timeout_seconds :timer.hours(24) |> div(1000)`)

### Recovery (`GameBot.GameSessions.Recovery`)

Enables session recovery from persisted event streams:

- Rebuilds game state from event history
- Validates event streams for consistency
- Provides robust error handling with context
- Implements timeout protection and retry mechanisms

#### Key Recovery Functions

```elixir
# Recover a session from its event stream
recover_session(game_id, opts \\ []) :: {:ok, state} | {:error, reason}

# Fetch events for a game
fetch_events(game_id, opts \\ []) :: {:ok, [Event.t()]} | {:error, reason}

# Validate event stream consistency
validate_event_stream(events) :: :ok | {:error, validation_error}
```

## State Design

### Session State

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

### Guess Workflow

1. **Validation**: Check word validity, player authorization, and duplicate submission
2. **Recording**: Store guess with timing information
3. **Pairing**: Match with teammate's guess when available
4. **Processing**: Apply game rules to determine match result
5. **Event Generation**: Create appropriate events based on outcome
6. **Persistence**: Store events with retry for transient failures
7. **Response**: Return match status to players

## Event System

### Event Types

The system uses a comprehensive set of events to track game state changes:

#### Game Events
```elixir
# Game lifecycle events
GameStarted             # Initial game setup
GameCompleted           # Game finish with final results
RoundCompleted          # Round completion with results
TeamEliminated          # Team removed from play (knockout mode)
KnockoutRoundCompleted  # Round completion in knockout mode
RaceModeTimeExpired     # Time limit reached in race mode
```

#### Guess Events
```elixir
# Guess processing events
GuessProcessed          # Complete guess pair processing result
GuessStarted            # Player initiated a guess attempt
GuessAbandoned          # Guess was abandoned (timeout, cancelled)
```

#### Error Events
```elixir
# Error tracking events
GuessError              # Error during individual guess validation
GuessPairError          # Error processing a complete guess pair
GameError               # Game-level error (invalid state, etc.)
RoundCheckError         # Error during round end checking
```

### Event Structure

Each event contains essential fields for tracking and recovery:
- `game_id`: Unique identifier for the game
- `guild_id`: Discord server ID
- `timestamp`: When the event occurred
- `metadata`: Additional context

#### Example: GuessProcessed
```elixir
%GuessProcessed{
  # Base fields
  game_id: String.t(),
  guild_id: String.t(),
  timestamp: DateTime.t(),
  metadata: metadata(),
  
  # Event-specific fields
  team_id: String.t(),
  player1_info: map(),
  player2_info: map(),
  player1_word: String.t(),
  player2_word: String.t(),
  guess_successful: boolean(),
  match_score: integer() | nil,
  guess_count: non_neg_integer(),
  round_guess_count: non_neg_integer(),
  total_guesses: non_neg_integer(),
  guess_duration: non_neg_integer(),
  player1_duration: non_neg_integer(),
  player2_duration: non_neg_integer()
}
```

### Event Persistence

Events are persisted with a robust retry mechanism:
- 3 retry attempts for transient failures
- Exponential backoff (50ms → 100ms → 200ms)
- Graceful degradation for permanent failures

## Reliability Features

1. **Process Isolation**: Each game runs in an isolated process
2. **Event Sourcing**: All state changes are persisted as events
3. **Automatic Cleanup**: Stale sessions are automatically terminated
4. **Retry Mechanisms**: Transient failures are handled with retry logic
5. **Timeout Protection**: Long-running operations have timeout guards
6. **Registry Management**: Players are registered in an ETS table for quick lookup
7. **Proper Termination**: Resources are cleaned up on process exit

## Configuration Constants

| Constant | Value | Description |
|----------|-------|-------------|
| Round Check Interval | 5 seconds | How often to check if round should end |
| Event Persistence Retries | 3 attempts | Retries for transient failures |
| Retry Delays | 50ms → 100ms → 200ms | Exponential backoff for retries |
| Session Timeout | 24 hours | Maximum session lifetime |
| Cleanup Interval | 5 minutes | How often to check for stale sessions |
| Recovery Timeout | 30 seconds | Maximum time for recovery operations |

## Usage Examples

### Creating a New Game

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
  "game_123",   # game_id
  "team1",      # team_id
  "player1",    # player_id
  "apple"       # word
)
```

### Recovering a Session

```elixir
# Recover a session from its event stream
{:ok, state} = GameBot.GameSessions.Recovery.recover_session(
  "game_123",
  timeout: :timer.seconds(60),  # Custom timeout
  retry_count: 5               # Custom retry count
)

# Start a new session with the recovered state
GameBot.GameSessions.Supervisor.start_game(state)
```

### Manual Cleanup

```elixir
# Manually trigger cleanup of stale sessions
GameBot.GameSessions.Cleanup.cleanup_old_sessions()
```

## Architecture Patterns

1. **Event Sourcing**: All state changes are stored as a sequence of events
2. **Command-Query Responsibility Segregation (CQRS)**: Commands modify state, queries read state
3. **Process Supervision**: Proper Elixir supervision tree for process lifecycle management
4. **Transient Process Design**: Sessions are not restarted on failure (until recovery is implemented)
5. **Registry Pattern**: Sessions are registered by ID for easy lookup
6. **State Machine**: Sessions follow a clear state transition model
7. **Validation Layers**: Multi-stage validation for all inputs

## Error Handling

The system provides comprehensive error handling:

- **Validation Errors**: Return descriptive error atoms with context
- **Persistence Failures**: Implement retry with exponential backoff
- **Timeout Protection**: Guard against long-running operations
- **Process Crashes**: Properly clean up resources on termination
- **Error Events**: Capture and persist error contexts as events

## Development Status

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
- [ ] State recovery from events implementation
- [ ] Distributed session management 