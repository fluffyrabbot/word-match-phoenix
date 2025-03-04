# GameCompleted Event

## Description
Emitted when a game ends. This event captures the final state of the game, including winners, final scores, and comprehensive statistics for all teams and players. It serves as the definitive record of the game's outcome.

## Structure
```elixir
@type t :: %GameCompleted{
  game_id: String.t(),           # Unique identifier for the game
  mode: atom(),                  # Game mode
  round_number: pos_integer(),   # Final round number
  winners: [String.t()],         # List of winning team IDs
  final_scores: %{String.t() => %{  # Final scores and stats by team
    score: integer(),            # Team's final score
    matches: integer(),          # Total successful matches
    total_guesses: integer(),    # Total guesses made
    average_guesses: float(),    # Average guesses per match
    player_stats: %{String.t() => %{  # Statistics for each player
      total_guesses: integer(),
      successful_matches: integer(),
      abandoned_guesses: integer(),
      average_guess_count: float()
    }}
  }},
  game_duration: integer(),      # Total game duration in seconds
  total_rounds: pos_integer(),   # Total number of rounds played
  timestamp: DateTime.t(),        # When the event occurred
  metadata: metadata()           # Additional context information
}
```

## Fields
- `game_id`: A unique identifier for the game session
- `mode`: The game mode being played
- `round_number`: The final round number when the game ended
- `winners`: List of team IDs that won the game
- `final_scores`: Comprehensive scoring and statistics for each team
  - `score`: Final score for the team
  - `matches`: Number of successful matches
  - `total_guesses`: Total number of guesses made
  - `average_guesses`: Average guesses per successful match
  - `player_stats`: Detailed statistics for each player
    - `total_guesses`: Total guesses made by the player
    - `successful_matches`: Number of successful matches
    - `abandoned_guesses`: Number of abandoned guess attempts
    - `average_guess_count`: Average guesses per successful match
- `game_duration`: Total duration of the game in seconds
- `total_rounds`: Total number of rounds played
- `timestamp`: When the event occurred
- `metadata`: Additional context information

## Validation
The event validates:
- All required fields are present
- Total rounds is positive
- Game duration is non-negative
- Winners list is present
- Final scores are complete and valid
- Player statistics are complete

## Usage
This event is used to:
1. Record game completion and results
2. Update player and team rankings
3. Generate game summaries
4. Update matchmaking data
5. Archive game statistics
6. Trigger post-game processes

## Example
```elixir
%GameCompleted{
  game_id: "knockout-1234567890",
  mode: :knockout,
  round_number: 3,
  winners: ["team2"],
  final_scores: %{
    "team1" => %{
      score: 15,
      matches: 3,
      total_guesses: 12,
      average_guesses: 4.0,
      player_stats: %{
        "player1" => %{
          total_guesses: 6,
          successful_matches: 2,
          abandoned_guesses: 1,
          average_guess_count: 3.0
        },
        "player2" => %{
          total_guesses: 6,
          successful_matches: 1,
          abandoned_guesses: 0,
          average_guess_count: 2.0
        }
      }
    },
    "team2" => %{
      score: 25,
      matches: 5,
      total_guesses: 15,
      average_guesses: 3.0,
      player_stats: %{
        "player3" => %{
          total_guesses: 8,
          successful_matches: 3,
          abandoned_guesses: 0,
          average_guess_count: 2.67
        },
        "player4" => %{
          total_guesses: 7,
          successful_matches: 2,
          abandoned_guesses: 0,
          average_guess_count: 3.5
        }
      }
    }
  },
  game_duration: 900,  # 15 minutes
  total_rounds: 3,
  timestamp: ~U[2024-03-04 00:45:00Z],
  metadata: %{
    client_version: "1.0.0",
    correlation_id: "pqr678"
  }
}
``` 