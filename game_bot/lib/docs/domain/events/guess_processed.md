# GuessProcessed Event

## Overview

The `GuessProcessed` event is emitted when a guess attempt is processed in the game. This event represents the complete lifecycle of a guess:
1. Both players have submitted their words
2. The guess has been validated
3. The match has been checked
4. The result has been recorded

## Event Definition

```elixir
defmodule GameBot.Domain.Events.GameEvents.GuessProcessed do
  use GameBot.Domain.Events.BaseEvent,
    event_type: "guess_processed",
    version: 1,
    fields: [
      field(:team_id, :string),
      field(:player1_id, :string),
      field(:player2_id, :string),
      field(:player1_word, :string),
      field(:player2_word, :string),
      field(:guess_successful, :boolean),
      field(:match_score, :integer),
      field(:guess_count, :integer),
      field(:round_guess_count, :integer),
      field(:total_guesses, :integer),
      field(:guess_duration, :integer),
      field(:player1_duration, :integer),
      field(:player2_duration, :integer)
    ]
end
```

## Fields

### Base Fields (Inherited)
- `game_id` (string, required) - Unique identifier for the game
- `guild_id` (string, required) - Discord guild ID where the game is being played
- `mode` (enum, required) - Game mode (:two_player, :knockout, :race)
- `round_number` (integer, required) - Current round number
- `timestamp` (utc_datetime_usec, required) - When the event occurred
- `metadata` (map, required) - Additional context about the event

### Custom Fields
- `team_id` (string, required) - ID of the team making the guess
- `player1_id` (string, required) - Discord ID of the first player
- `player2_id` (string, required) - Discord ID of the second player
- `player1_word` (string, required) - Word submitted by player 1
- `player2_word` (string, required) - Word submitted by player 2
- `guess_successful` (boolean, required) - Whether the guess matched
- `match_score` (integer, optional) - Points awarded for the match (nil if unsuccessful)
- `guess_count` (integer, required) - Number of guesses made in this attempt
- `round_guess_count` (integer, required) - Total guesses made in the current round
- `total_guesses` (integer, required) - Total guesses made in the game
- `guess_duration` (integer, required) - Time taken for this guess attempt in milliseconds
- `player1_duration` (integer, required) - Time taken for player 1 to submit their word in milliseconds
- `player2_duration` (integer, required) - Time taken for player 2 to submit their word in milliseconds

## Validation Rules

1. Base field validation (handled by BaseEvent)
2. Required fields must be present
3. Custom field validation:
   ```elixir
   def validate_custom_fields(changeset) do
     super(changeset)
     |> validate_number(:guess_count, greater_than: 0)
     |> validate_number(:round_guess_count, greater_than: 0)
     |> validate_number(:total_guesses, greater_than: 0)
     |> validate_number(:guess_duration, greater_than_or_equal_to: 0)
     |> validate_number(:player1_duration, greater_than_or_equal_to: 0)
     |> validate_number(:player2_duration, greater_than_or_equal_to: 0)
     |> validate_match_score()
   end
   ```
4. Match score validation:
   - Must be present and positive when guess is successful
   - Must be nil when guess is unsuccessful
5. Player ID validation:
   - Must be a non-empty string

## Example Usage

```elixir
# Creating a new GuessProcessed event
event = %GameBot.Domain.Events.GameEvents.GuessProcessed{
  game_id: "game-123",
  guild_id: "guild-456",
  mode: :two_player,
  round_number: 1,
  team_id: "team-789",
  player1_id: "123456789",
  player2_id: "987654321",
  player1_word: "apple",
  player2_word: "apple",
  guess_successful: true,
  match_score: 10,
  guess_count: 1,
  round_guess_count: 5,
  total_guesses: 15,
  guess_duration: 12500,
  player1_duration: 5000,
  player2_duration: 7500,
  timestamp: DateTime.utc_now(),
  metadata: %{
    source_id: "msg-123",
    correlation_id: "corr-456",
    causation_id: "cmd-789"
  }
}

# Validating the event
case GameBot.Domain.Events.EventValidator.validate(event) do
  :ok ->
    # Event is valid
    {:ok, event}
  
  {:error, reason} ->
    # Handle validation error
    {:error, reason}
end
```

## Testing

Required test cases:

1. Valid event creation
   ```elixir
   test "creates valid guess processed event" do
     event = build(:guess_processed_event)
     assert :ok = EventValidator.validate(event)
   end
   ```

2. Field validation
   ```elixir
   test "validates guess count is positive" do
     event = build(:guess_processed_event, guess_count: 0)
     assert {:error, _} = EventValidator.validate(event)
   end
   ```

3. Match score validation
   ```elixir
   test "requires match score when guess is successful" do
     event = build(:guess_processed_event, guess_successful: true, match_score: nil)
     assert {:error, _} = EventValidator.validate(event)
   end
   ```

4. Player duration validation
   ```elixir
   test "validates player durations are non-negative" do
     event = build(:guess_processed_event, player1_duration: -1)
     assert {:error, _} = EventValidator.validate(event)
   end
   ```

5. Serialization roundtrip
   ```elixir
   test "serializes and deserializes correctly" do
     event = build(:guess_processed_event)
     serialized = EventSerializer.to_map(event)
     deserialized = EventSerializer.from_map(serialized)
     assert event == deserialized
   end
   ```

## Event Flow

The GuessProcessed event is typically part of the following flow:

1. RoundStarted event
2. Multiple GuessProcessed events
3. Either:
   - RoundCompleted event (when successful match)
   - GuessAbandoned event (when attempt abandoned)
   - TeamEliminated event (when max guesses reached)

## Related Events

- RoundStarted - Initiates a round where guesses can be made
- GuessAbandoned - When a guess attempt is abandoned
- RoundCompleted - When a successful guess completes a round
- TeamEliminated - When a team is eliminated due to max guesses 

## Importance Level

The GuessProcessed event is classified as **CRITICAL** importance because:
- It represents the atomic unit of gameplay
- It contains essential data for game state reconstruction
- It's required for accurate scoring and game progression
- It's needed for analytics and player performance tracking 