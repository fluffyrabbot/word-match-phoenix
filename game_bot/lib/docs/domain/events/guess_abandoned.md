# GuessAbandoned Event

## Description
Emitted when a guess attempt is abandoned before completion, either due to a timeout, or the player giving up via command. This event captures the state of the incomplete guess attempt and the reason for abandonment.

## Structure
```elixir
@type t :: %GuessAbandoned{
  game_id: String.t(),           # Unique identifier for the game
  mode: atom(),                  # Game mode
  round_number: pos_integer(),   # Current round number
  team_id: String.t(),           # Team making the guess
  player1_info: player_info(),   # First player's information
  player2_info: player_info(),   # Second player's information
  reason: :timeout | :player_quit | :disconnected,  # Why the guess was abandoned
  abandoning_player_id: String.t(),  # Player who abandoned/timed out
  last_guess: %{                 # Last recorded guess if any
    player_id: String.t(),
    word: String.t(),
    timestamp: DateTime.t()
  } | nil,
  guess_count: pos_integer(),    # Number of attempts made
  timestamp: DateTime.t(),        # When the event occurred
  metadata: metadata()           # Additional context information
}

@type player_info :: {integer(), String.t(), String.t() | nil}  # {discord_id, username, nickname}
```

## Fields
- `game_id`: A unique identifier for the game session
- `mode`: The game mode being played
- `round_number`: The current round number
- `team_id`: Identifier of the team making the guess
- `player1_info`: Information about the first player (ID, team, role)
- `player2_info`: Information about the second player (ID, team, role)
- `reason`: Why the guess was abandoned (:timeout, :player_quit, or :disconnected)
- `abandoning_player_id`: ID of the player who abandoned or timed out
- `last_guess`: Information about the last guess made (if any)
- `guess_count`: Number of attempts made by the team in this round
- `timestamp`: When the event occurred
- `metadata`: Additional context information

## Validation
The event validates:
- All required fields are present
- Player information is complete
- Valid abandonment reason is provided
- Abandoning player ID is provided
- Guess count is positive

## Usage
This event is used to:
1. Track incomplete guess attempts
2. Handle player timeouts and disconnections
3. Update team statistics
4. Trigger game state transitions
5. Record player participation metrics

## Example
```elixir
%GuessAbandoned{
  game_id: "two_player-1234567890",
  mode: :two_player,
  round_number: 1,
  team_id: "team1",
  player1_info: %{
    player_id: "player1",
    team_id: "team1",
    role: :giver
  },
  player2_info: %{
    player_id: "player2",
    team_id: "team1",
    role: :guesser
  },
  reason: :timeout,
  abandoning_player_id: "player2",
  last_guess: %{
    player_id: "player1",
    word: "mountain",
    timestamp: ~U[2024-03-04 00:04:30Z]
  },
  guess_count: 2,
  timestamp: ~U[2024-03-04 00:05:00Z],
  metadata: %{
    client_version: "1.0.0",
    correlation_id: "jkl012"
  }
}
``` 