# Game Mode Implementation Specification

## Core Game State
```elixir
defmodule GameBot.Domain.GameModes.GameState do
  @type team_state :: %{
    player_ids: [String.t()],
    current_words: [String.t()],
    guess_count: pos_integer(),    # Always >= 1, represents current attempt number
    pending_guess: %{              # Tracks incomplete guess pairs
      player_id: String.t(),
      word: String.t(),
      timestamp: DateTime.t()
    } | nil
  }

  defstruct [
    mode: nil,                    # Module implementing the game mode
    teams: %{},                   # Map of team_id to team_state
    forbidden_words: %{},         # Map of player_id to [forbidden words]
    round_number: 1,             # Current round number
    start_time: nil,             # Game start timestamp
    last_activity: nil,          # Last guess timestamp
    matches: [],                 # List of successful matches with metadata
    scores: %{},                 # Map of team_id to current score
    status: :waiting             # Game status (:waiting, :in_progress, :completed)
  ]
end

# Example team state structure:
# teams: %{
#   "team1" => %{
#     player_ids: ["player1", "player2"],
#     current_words: ["apple", "banana"],
#     guess_count: 1,             # First attempt
#     pending_guess: %{           # Incomplete pair - waiting for partner
#       player_id: "player1",
#       word: "test",
#       timestamp: ~U[2024-03-04 12:00:00Z]
#     }
#   },
#   "team2" => %{
#     player_ids: ["player3", "player4"],
#     current_words: ["cat", "dog"],
#     guess_count: 3,             # Third attempt after two failed matches
#     pending_guess: nil          # No pending guesses
#   }
# }

# Guess Count Behavior:
# 1. Initialize at 1 for each new word pair (representing first attempt)
# 2. Increment only after failed matches or abandoned guesses
# 3. Record final count in match history when successful
# Examples:
# - Match on first try = 1 guess
# - Match after one failed attempt = 2 guesses
# - Match after two failed attempts = 3 guesses
```

## Event Types
```elixir
# Core Events
defmodule GameBot.Domain.Events do
  # Game Lifecycle Events
  defmodule GameStarted do
    @type t :: %__MODULE__{
      game_id: String.t(),
      mode: atom(),
      teams: %{String.t() => [String.t()]},  # team_id => [player_ids]
      config: map(),                         # Mode-specific configuration
      timestamp: DateTime.t()
    }
  end

  defmodule RoundStarted do
    @type t :: %__MODULE__{
      game_id: String.t(),
      round_number: pos_integer(),
      team_states: map(),                    # Initial team states for round
      timestamp: DateTime.t()
    }
  end

  # Gameplay Events
  defmodule GuessProcessed do
    @type t :: %__MODULE__{
      game_id: String.t(),
      team_id: String.t(),
      player1_id: String.t(),
      player2_id: String.t(),
      player1_word: String.t(),
      player2_word: String.t(),
      guess_successful: boolean(),           # Whether the words matched
      guess_count: pos_integer(),            # Current attempt number
      timestamp: DateTime.t()
    }
  end

  defmodule GuessAbandoned do
    @type t :: %__MODULE__{
      game_id: String.t(),
      team_id: String.t(),
      reason: :timeout | :player_quit,
      last_guess: %{                         # Last recorded guess if any
        player_id: String.t(),
        word: String.t()
      } | nil,
      guess_count: pos_integer(),            # Current attempt number
      timestamp: DateTime.t()
    }
  end

  defmodule TeamEliminated do
    @type t :: %__MODULE__{
      game_id: String.t(),
      team_id: String.t(),
      reason: :timeout | :max_guesses | :round_loss,
      final_state: map(),                    # Team's final state
      timestamp: DateTime.t()
    }
  end

  defmodule GameCompleted do
    @type t :: %__MODULE__{
      game_id: String.t(),
      winners: [String.t()],                 # List of winning team_ids
      final_scores: map(),                   # Final scores/stats by team
      timestamp: DateTime.t()
    }
  end

  # Mode-specific Events
  defmodule KnockoutRoundCompleted do
    @type t :: %__MODULE__{
      game_id: String.t(),
      round_number: pos_integer(),
      eliminated_teams: [String.t()],
      advancing_teams: [String.t()],
      timestamp: DateTime.t()
    }
    defstruct [:game_id, :round_number, :eliminated_teams, :advancing_teams, :timestamp]
  end

  defmodule RaceModeTimeExpired do
    @type t :: %__MODULE__{
      game_id: String.t(),
      final_matches: map(),                  # Matches by team
      timestamp: DateTime.t()
    }
    defstruct [:game_id, :final_matches, :timestamp]
  end

  defmodule LongformDayEnded do
    @type t :: %__MODULE__{
      game_id: String.t(),
      day_number: pos_integer(),
      team_standings: map(),                 # Current team standings
      timestamp: DateTime.t()
    }
    defstruct [:game_id, :day_number, :team_standings, :timestamp]
  end
end
```

## Event Usage Matrix

| Event Type | Replay | Statistics | State Recovery |
|------------|--------|------------|----------------|
| GameStarted | ✓ Initial setup | ✓ Game counts | ✓ Base state |
| RoundStarted | ✓ Round transitions | ✓ Round counts | ✓ Round state |
| GuessProcessed | ✓ Guess pairs | ✓ Match rates, avg attempts | ✓ Team progress |
| GuessAbandoned | ✓ Timeouts/quits | ✓ Completion rates | ✓ Attempt tracking |
| TeamEliminated | ✓ Eliminations | ✓ Survival stats | ✓ Team removal |
| GameCompleted | ✓ End state | ✓ Win/loss records | ✓ Final state |
| KnockoutRoundCompleted | ✓ Round results | ✓ Elimination stats | ✓ Round transition |
| RaceModeTimeExpired | ✓ Time limit | ✓ Speed stats | ✓ Game end |
| LongformDayEnded | ✓ Daily summary | ✓ Long-term stats | ✓ Day transition |

## Common Game Logic

### State Machine Flow
1. `:waiting` -> Game initialization and team setup
2. `:in_progress` -> Active gameplay with paired guess processing
3. `:completed` -> Game end and results calculation

### Guess Processing Flow
1. First player submits guess -> stored as pending in team state
2. Second player submits guess -> pair is processed
3. Success/failure determined in single atomic operation
4. Timeouts/quits handled with explicit abandonment events

### Event Recording
Each game event must record:
- Timestamp
- Team and player identifiers
- Current game state snapshot
- Mode-specific metadata

### Game Reconstruction
Games can be reconstructed from event stream by:
1. Loading GameStarted event for initial state
2. Replaying all subsequent events in order
3. Applying mode-specific state transitions

## Mode-Specific Implementations

### Two Player Mode
```elixir
defmodule GameBot.Domain.GameModes.TwoPlayerMode do
  defstruct [
    rounds_required: 5,           # Configurable
    success_threshold: 4,         # Average guesses threshold (default: 4)
    current_round: 1,
    total_guesses: 0,
    team_guesses: %{},            # Tracks guesses by team
    completion_time: nil
  ]
end
```

### Knockout Mode
```elixir
defmodule GameBot.Domain.GameModes.KnockoutMode do
  defstruct [
    round_number: 1,
    round_start_time: nil,
    eliminated_teams: [],         # List of elimination records with reasons
    team_guesses: %{},            # Map of team_id to guess count
    round_duration: 300,          # 5 minutes in seconds
    elimination_limit: 12         # Max guesses before auto-elimination
  ]
  
  # Configuration Constants
  @round_time_limit 300           # 5 minutes in seconds
  @max_guesses 12                 # Maximum guesses before elimination
  @forced_elimination_threshold 8 # Teams above this count trigger forced eliminations
  @teams_to_eliminate 3           # Number of teams to eliminate when above threshold
  @min_teams 2                    # Minimum teams to start
  
  # Elimination reasons
  @type elimination_reason ::
    :time_expired |               # Failed to match within time limit
    :guess_limit |                # Exceeded maximum guesses
    :forced_elimination           # Eliminated due to high guess count
end
```

### Race Mode
```elixir
defmodule GameBot.Domain.GameModes.RaceMode do
  defstruct [
    time_limit: 180,              # 3 minutes in seconds
    guild_id: nil,                # Required for word validation
    matches_by_team: %{},         # Map of team_id to match count
    total_guesses_by_team: %{},   # Map of team_id to total guesses
    start_time: nil               # Game start timestamp
  ]
  
  # Special commands
  @give_up_command "give up"      # Command to skip difficult word pairs
  
  # NOTE: Win condition is based on matches completed when time expires,
  # with average guesses as a tiebreaker. Team rankings can be dynamically 
  # computed from the matches_by_team and total_guesses_by_team maps.
end
```

### Golf Race Mode
```elixir
defmodule GameBot.Domain.GameModes.GolfRaceMode do
  defstruct [
    time_limit: 180,              # 3 minutes in seconds
    points_by_team: %{},          # Map of team_id to points
    matches_by_team: %{},         # Map of team_id to match count
    start_time: nil
  ]

  @scoring_rules %{
    1 => 4,                       # 1 guess = 4 points
    2..4 => 3,                    # 2-4 guesses = 3 points
    5..7 => 2,                    # 5-7 guesses = 2 points
    8..10 => 1,                   # 8-10 guesses = 1 point
    11..999 => 0                  # 11+ guesses = 0 points
  }
end
```

### Longform Mode
```elixir
defmodule GameBot.Domain.GameModes.LongformMode do
  defstruct [
    round_duration: 86400,        # 24 hours in seconds
    eliminated_teams: [],
    round_start_time: nil,
    round_number: 1
  ]
end
```

## Replay System Requirements

The following data points must be captured for full replay reconstruction:

1. Game initialization state
   - Mode and configuration
   - Teams and players
   - Start time

2. Per-round data
   - Initial word pairs
   - All guesses in sequence with timestamps
   - Match results
   - Eliminations/scoring events

3. Game conclusion data
   - Final scores/rankings
   - Performance metrics
   - Total duration

## Error Handling and Edge Cases

1. Timeouts
   - Hard time limits trigger automatic game end
   - All teams failing time limit results in no winner

2. Game Recovery
   - Games reconstruct from event stream on bot restart
   - Recovery message sent to original channel
   - Teams maintain same word pairs and progress

3. Persistence Strategy
   - All events stored in EventStore
   - No additional persistence required
   - Event stream sufficient for reconstruction 