# RaceModeTimeExpired Event

## Description
Emitted when time runs out in race mode. This event captures the final state of all teams at the moment the time limit is reached, including their match counts, scores, and player statistics. It's specific to the race game mode.

## Structure
```elixir
@type t :: %RaceModeTimeExpired{
  game_id: String.t(),           # Unique identifier for the game
  mode: atom(),                  # Game mode (always :race)
  round_number: pos_integer(),   # Current round number
  final_matches: %{String.t() => %{  # Final match data by team
    matches: integer(),          # Number of successful matches
    total_guesses: integer(),    # Total guesses made
    average_guesses: float(),    # Average guesses per match
    last_match_timestamp: DateTime.t(),  # When last match occurred
    player_stats: %{String.t() => map()}  # Statistics by player
  }},
  game_duration: integer(),      # Total game duration in seconds
  timestamp: DateTime.t(),        # When the event occurred
  metadata: metadata()           # Additional context information
}
```

## Fields
- `game_id`: A unique identifier for the game session
- `mode`: The game mode (always :race)
- `round_number`: The current round number
- `final_matches`: Map of team IDs to their final match data
  - `matches`: Number of successful matches
  - `total_guesses`: Total number of guesses made
  - `average_guesses`: Average guesses per successful match
  - `last_match_timestamp`: When the team's last match occurred
  - `player_stats`: Statistics for each player on the team
- `game_duration`: Total duration of the game in seconds
- `timestamp`: When the event occurred
- `metadata`: Additional context information

## Validation
The event validates:
- All required fields are present
- Game duration is non-negative
- Final matches data is present
- Match statistics are valid
- Player statistics are complete

## Usage
This event is used to:
1. End race mode games
2. Calculate final rankings
3. Record team performance
4. Generate game summaries
5. Update player statistics
6. Trigger game completion

## Example
```elixir
%RaceModeTimeExpired{
  game_id: "race-1234567890",
  mode: :race,
  round_number: 1,
  final_matches: %{
    "team1" => %{
      matches: 8,
      total_guesses: 24,
      average_guesses: 3.0,
      last_match_timestamp: ~U[2024-03-04 00:14:30Z],
      player_stats: %{
        "player1" => %{
          total_guesses: 12,
          successful_matches: 4,
          abandoned_guesses: 0,
          average_guess_count: 3.0
        },
        "player2" => %{
          total_guesses: 12,
          successful_matches: 4,
          abandoned_guesses: 0,
          average_guess_count: 3.0
        }
      }
    },
    "team2" => %{
      matches: 6,
      total_guesses: 20,
      average_guesses: 3.33,
      last_match_timestamp: ~U[2024-03-04 00:14:45Z],
      player_stats: %{
        "player3" => %{
          total_guesses: 10,
          successful_matches: 3,
          abandoned_guesses: 1,
          average_guess_count: 3.33
        },
        "player4" => %{
          total_guesses: 10,
          successful_matches: 3,
          abandoned_guesses: 0,
          average_guess_count: 3.33
        }
      }
    }
  },
  game_duration: 900,  # 15 minutes
  timestamp: ~U[2024-03-04 00:15:00Z],
  metadata: %{
    client_version: "1.0.0",
    correlation_id: "vwx234"
  }
}
``` 