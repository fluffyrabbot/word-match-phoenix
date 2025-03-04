# GameStarted Event

## Description
Emitted when a new game is started. This event marks the beginning of a game session and contains all initial game configuration and player information.

## Structure
```elixir
@type t :: %GameStarted{
  game_id: String.t(),           # Unique identifier for the game
  mode: atom(),                  # Game mode (e.g. :two_player, :knockout, :race)
  round_number: pos_integer(),   # Always 1 for game start
  teams: %{String.t() => [String.t()]},  # Map of team_id to list of player_ids
  team_ids: [String.t()],        # Ordered list of team IDs
  player_ids: [String.t()],      # Ordered list of all player IDs
  roles: %{String.t() => atom()}, # Map of player_id to role
  config: map(),                 # Mode-specific configuration
  timestamp: DateTime.t(),        # When the event occurred
  metadata: metadata()           # Additional context information
}
```

## Fields
- `game_id`: A unique identifier for the game session
- `mode`: The game mode being played
- `round_number`: Always 1 for game start event
- `teams`: Map of team IDs to lists of player IDs, defining team composition
- `team_ids`: Ordered list of team IDs for maintaining team order
- `player_ids`: Ordered list of all player IDs in the game
- `roles`: Map of player IDs to their assigned roles
- `config`: Mode-specific configuration parameters
- `timestamp`: When the event occurred
- `metadata`: Additional context information (client version, correlation ID, etc.)

## Validation
The event validates:
- All required fields are present
- Team IDs in teams map match team_ids list
- Player IDs in teams match player_ids list

## Usage
This event is used to:
1. Initialize game state
2. Set up team structures
3. Assign player roles
4. Configure mode-specific settings

## Example
```elixir
%GameStarted{
  game_id: "two_player-1234567890",
  mode: :two_player,
  round_number: 1,
  teams: %{
    "team1" => ["player1", "player2"],
    "team2" => ["player3", "player4"]
  },
  team_ids: ["team1", "team2"],
  player_ids: ["player1", "player2", "player3", "player4"],
  roles: %{
    "player1" => :giver,
    "player2" => :guesser,
    "player3" => :giver,
    "player4" => :guesser
  },
  config: %{
    max_guesses: 3,
    time_limit: 300
  },
  timestamp: ~U[2024-03-04 00:00:00Z],
  metadata: %{
    client_version: "1.0.0",
    correlation_id: "abc123"
  }
}
``` 