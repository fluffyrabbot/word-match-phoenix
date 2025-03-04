# RoundStarted Event

## Description
Emitted when a new round begins in a game. This event marks the start of a new round and contains the initial state for all teams participating in the round.

## Structure
```elixir
@type t :: %RoundStarted{
  game_id: String.t(),           # Unique identifier for the game
  mode: atom(),                  # Game mode
  round_number: pos_integer(),   # Current round number
  team_states: map(),            # Initial team states for the round
  timestamp: DateTime.t(),        # When the event occurred
  metadata: metadata()           # Additional context information
}
```

## Fields
- `game_id`: A unique identifier for the game session
- `mode`: The game mode being played
- `round_number`: The current round number (increments with each new round)
- `team_states`: Map containing the initial state for each team at round start
- `timestamp`: When the event occurred
- `metadata`: Additional context information (client version, correlation ID, etc.)

## Validation
The event validates:
- All required fields are present
- Round number is positive
- Team states are properly structured for the game mode

## Usage
This event is used to:
1. Initialize round-specific state
2. Reset team states for the new round
3. Set up round-specific configurations
4. Track round progression in the game

## Example
```elixir
%RoundStarted{
  game_id: "knockout-1234567890",
  mode: :knockout,
  round_number: 2,
  team_states: %{
    "team1" => %{
      score: 10,
      guess_count: 0,
      active_players: ["player1", "player2"],
      status: :ready
    },
    "team2" => %{
      score: 8,
      guess_count: 0,
      active_players: ["player3", "player4"],
      status: :ready
    }
  },
  timestamp: ~U[2024-03-04 00:15:00Z],
  metadata: %{
    client_version: "1.0.0",
    correlation_id: "def456"
  }
}
``` 