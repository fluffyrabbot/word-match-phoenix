# KnockoutRoundCompleted Event

## Description
Emitted when a round in knockout mode ends. This event captures the state of all teams at the end of the round, including which teams are eliminated and which teams advance to the next round. It's specific to the knockout game mode.

## Structure
```elixir
@type t :: %KnockoutRoundCompleted{
  game_id: String.t(),           # Unique identifier for the game
  mode: atom(),                  # Game mode (always :knockout)
  round_number: pos_integer(),   # Current round number
  eliminated_teams: [%{          # Teams eliminated this round
    team_id: String.t(),
    reason: :timeout | :max_guesses | :round_loss | :forfeit,
    final_score: integer(),
    player_stats: %{String.t() => map()}
  }],
  advancing_teams: [%{           # Teams advancing to next round
    team_id: String.t(),
    score: integer(),
    matches: integer(),
    total_guesses: integer()
  }],
  round_duration: integer(),     # Duration of the round in seconds
  timestamp: DateTime.t(),        # When the event occurred
  metadata: metadata()           # Additional context information
}
```

## Fields
- `game_id`: A unique identifier for the game session
- `mode`: The game mode (always :knockout)
- `round_number`: The current round number
- `eliminated_teams`: List of teams eliminated in this round
  - `team_id`: Identifier of the eliminated team
  - `reason`: Why the team was eliminated
  - `final_score`: Team's final score
  - `player_stats`: Statistics for each player on the team
- `advancing_teams`: List of teams advancing to the next round
  - `team_id`: Identifier of the advancing team
  - `score`: Current score
  - `matches`: Number of successful matches
  - `total_guesses`: Total guesses made
- `round_duration`: How long the round lasted in seconds
- `timestamp`: When the event occurred
- `metadata`: Additional context information

## Validation
The event validates:
- All required fields are present
- Round duration is non-negative
- Eliminated teams list is present
- Advancing teams list is present
- Teams have valid statistics

## Usage
This event is used to:
1. Track round progression in knockout mode
2. Record eliminated teams
3. Update tournament brackets
4. Calculate team rankings
5. Prepare next round setup
6. Generate round summaries

## Example
```elixir
%KnockoutRoundCompleted{
  game_id: "knockout-1234567890",
  mode: :knockout,
  round_number: 1,
  eliminated_teams: [
    %{
      team_id: "team1",
      reason: :round_loss,
      final_score: 10,
      player_stats: %{
        "player1" => %{
          total_guesses: 5,
          successful_matches: 1,
          abandoned_guesses: 0
        },
        "player2" => %{
          total_guesses: 5,
          successful_matches: 1,
          abandoned_guesses: 0
        }
      }
    }
  ],
  advancing_teams: [
    %{
      team_id: "team2",
      score: 15,
      matches: 3,
      total_guesses: 9
    }
  ],
  round_duration: 300,  # 5 minutes
  timestamp: ~U[2024-03-04 00:20:00Z],
  metadata: %{
    client_version: "1.0.0",
    correlation_id: "stu901"
  }
}
``` 