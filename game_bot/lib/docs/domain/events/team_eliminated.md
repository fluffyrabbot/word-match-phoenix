# TeamEliminated Event

## Description
Emitted when a team is eliminated from the game. This can occur due to various reasons such as timeout, exceeding maximum guesses, losing a round, or forfeiting. The event captures the team's final state and statistics at the time of elimination.

## Structure
```elixir
@type t :: %TeamEliminated{
  game_id: String.t(),           # Unique identifier for the game
  mode: atom(),                  # Game mode
  round_number: pos_integer(),   # Current round number
  team_id: String.t(),           # Team being eliminated
  reason: :timeout | :max_guesses | :round_loss | :forfeit,  # Why the team was eliminated
  final_state: team_info(),      # Team's final state
  final_score: integer(),        # Team's final score
  player_stats: %{String.t() => %{  # Statistics for each player
    total_guesses: integer(),
    successful_matches: integer(),
    abandoned_guesses: integer(),
    average_guess_count: float()
  }},
  timestamp: DateTime.t(),        # When the event occurred
  metadata: metadata()           # Additional context information
}

@type team_info :: %{
  team_id: String.t(),
  player_ids: [String.t()],
  team_state: map()
}
```

## Fields
- `game_id`: A unique identifier for the game session
- `mode`: The game mode being played
- `round_number`: The current round number
- `team_id`: Identifier of the eliminated team
- `reason`: Why the team was eliminated
- `final_state`: The team's final state information
- `final_score`: The team's final score
- `player_stats`: Detailed statistics for each player on the team
- `timestamp`: When the event occurred
- `metadata`: Additional context information

## Validation
The event validates:
- All required fields are present
- Valid elimination reason is provided
- Final state is properly structured
- Final score is present
- Player statistics are complete

## Usage
This event is used to:
1. Track team eliminations
2. Update game state
3. Record final team statistics
4. Trigger game progression
5. Update player rankings and history

## Example
```elixir
%TeamEliminated{
  game_id: "knockout-1234567890",
  mode: :knockout,
  round_number: 2,
  team_id: "team1",
  reason: :max_guesses,
  final_state: %{
    team_id: "team1",
    player_ids: ["player1", "player2"],
    team_state: %{
      score: 15,
      matches: 3,
      total_guesses: 12
    }
  },
  final_score: 15,
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
  },
  timestamp: ~U[2024-03-04 00:30:00Z],
  metadata: %{
    client_version: "1.0.0",
    correlation_id: "mno345"
  }
}
``` 