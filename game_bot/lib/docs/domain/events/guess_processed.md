# GuessProcessed Event

## Description
Emitted when both players in a team have submitted their guesses and the attempt has been processed. This event captures the outcome of a guess attempt, including whether it was successful and the words that were guessed.

## Structure
```elixir
@type t :: %GuessProcessed{
  game_id: String.t(),           # Unique identifier for the game
  mode: atom(),                  # Game mode
  round_number: pos_integer(),   # Current round number
  team_id: String.t(),           # Team making the guess
  player1_info: player_info(),   # First player's information
  player2_info: player_info(),   # Second player's information
  player1_word: String.t(),      # Word submitted by first player
  player2_word: String.t(),      # Word submitted by second player
  guess_successful: boolean(),    # Whether the words matched
  guess_count: pos_integer(),    # Number of attempts made
  match_score: integer(),        # Points awarded for this match
  timestamp: DateTime.t(),        # When the event occurred
  metadata: metadata()           # Additional context information
}

@type player_info :: %{
  player_id: String.t(),
  team_id: String.t(),
  role: atom()                   # :giver or :guesser
}
```

## Fields
- `game_id`: A unique identifier for the game session
- `mode`: The game mode being played
- `round_number`: The current round number
- `team_id`: Identifier of the team making the guess
- `player1_info`: Information about the first player (ID, team, role)
- `player2_info`: Information about the second player (ID, team, role)
- `player1_word`: The word submitted by the first player
- `player2_word`: The word submitted by the second player
- `guess_successful`: Boolean indicating if the words matched
- `guess_count`: Number of attempts made by the team in this round
- `match_score`: Points awarded for this match (if successful)
- `timestamp`: When the event occurred
- `metadata`: Additional context information

## Validation
The event validates:
- All required fields are present
- Player information is complete
- Words are provided for both players
- Guess count is positive
- Match score is valid for the game mode

## Usage
This event is used to:
1. Track guess attempts and outcomes
2. Update team scores
3. Record word matching history
4. Calculate player statistics
5. Trigger game progression logic

## Example
```elixir
%GuessProcessed{
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
  player1_word: "mountain",
  player2_word: "hill",
  guess_successful: false,
  guess_count: 2,
  match_score: 0,
  timestamp: ~U[2024-03-04 00:05:00Z],
  metadata: %{
    client_version: "1.0.0",
    correlation_id: "ghi789"
  }
}
``` 