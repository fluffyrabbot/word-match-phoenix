# Game Events

## Overview

Game events represent all state changes in the game system. Each event is an immutable record of something that has happened. Events are processed through a validation and serialization pipeline before being stored and broadcast to interested subscribers.

## Event Types

### Core Game Events

1. **GameCreated**
   - Emitted when a new game is created
   - Fields:
     ```elixir
     field :game_id, :string
     field :guild_id, :string
     field :mode, Ecto.Enum, values: [:two_player, :knockout, :race]
     field :created_by, :string
     field :created_at, :utc_datetime_usec
     field :team_ids, {:array, :string}
     ```

2. **GameStarted**
   - Emitted when a game begins
   - Fields:
     ```elixir
     field :teams, :map
     field :team_ids, {:array, :string}
     field :player_ids, {:array, :string}
     field :roles, :map
     field :config, :map
     field :started_at, :utc_datetime_usec
     ```

3. **GameCompleted**
   - Emitted when a game ends
   - Fields:
     ```elixir
     field :winners, {:array, :string}
     field :final_scores, :map
     field :game_duration, :integer
     field :total_rounds, :integer
     field :finished_at, :utc_datetime_usec
     ```

### Round Events

1. **RoundStarted**
   - Emitted when a new round begins
   - Fields:
     ```elixir
     field :team_states, :map
     ```

2. **RoundCompleted**
   - Emitted when a round ends
   - Fields:
     ```elixir
     field :winner_team_id, :string
     field :round_score, :integer
     field :round_stats, :map
     ```

### Guess Events

1. **GuessProcessed**
   - Emitted when a guess attempt is processed
   - Fields:
     ```elixir
     field :team_id, :string
     field :player1_info, :map
     field :player2_info, :map
     field :player1_word, :string
     field :player2_word, :string
     field :guess_successful, :boolean
     field :match_score, :integer
     field :guess_count, :integer
     field :round_guess_count, :integer
     field :total_guesses, :integer
     field :guess_duration, :integer
     ```

2. **GuessAbandoned**
   - Emitted when a guess attempt is abandoned
   - Fields:
     ```elixir
     field :team_id, :string
     field :player1_info, :map
     field :player2_info, :map
     field :reason, Ecto.Enum, values: [:timeout, :player_quit, :disconnected]
     field :abandoning_player_id, :string
     field :last_guess, :map
     field :guess_count, :integer
     field :round_guess_count, :integer
     field :total_guesses, :integer
     field :guess_duration, :integer
     ```

### Game Mode Events

1. **TeamEliminated**
   - Emitted when a team is eliminated (Knockout mode)
   - Fields:
     ```elixir
     field :team_id, :string
     field :reason, Ecto.Enum, values: [:timeout, :max_guesses, :round_loss, :forfeit]
     field :final_state, :map
     field :final_score, :integer
     field :player_stats, :map
     ```

2. **KnockoutRoundCompleted**
   - Emitted when a knockout round ends
   - Fields:
     ```elixir
     field :eliminated_teams, {:array, :map}
     field :advancing_teams, {:array, :map}
     field :round_duration, :integer
     ```

3. **RaceModeTimeExpired**
   - Emitted when time runs out in race mode
   - Fields:
     ```elixir
     field :final_matches, :map
     field :game_duration, :integer
     ```

## Base Fields

All events include these base fields:
```elixir
field :game_id, :string
field :guild_id, :string
field :mode, Ecto.Enum, values: [:two_player, :knockout, :race]
field :round_number, :integer
field :timestamp, :utc_datetime_usec
field :metadata, :map
```

## Metadata Structure

Required metadata fields:
```elixir
%{
  source_id: String.t() | nil,    # Discord message ID or other source identifier
  correlation_id: String.t(),     # For tracking related events
  causation_id: String.t() | nil  # ID of event that caused this one
}
```

## Event Processing Pipeline

1. **Validation**
   ```elixir
   with :ok <- validate_base_fields(event),
        :ok <- validate_metadata(event),
        :ok <- validate_custom_fields(event) do
     :ok
   end
   ```

2. **Serialization**
   ```elixir
   def to_map(event) do
     Map.from_struct(event)
     |> Map.update!(:timestamp, &DateTime.to_iso8601/1)
   end
   ```

3. **Storage**
   - Events are stored in the EventStore
   - Indexed by game_id and timestamp
   - Versioned for schema evolution

4. **Broadcasting**
   - Events are broadcast on PubSub channels
   - Channel format: "game:{game_id}"
   - Subscribers receive `{:event, event}`

## Usage Example

```elixir
# Creating a new event
event = %GameBot.Domain.Events.GameEvents.GuessProcessed{
  game_id: "game-123",
  guild_id: "guild-456",
  mode: :two_player,
  round_number: 1,
  team_id: "team-789",
  player1_info: %{player_id: "player1"},
  player2_info: %{player_id: "player2"},
  player1_word: "word1",
  player2_word: "word2",
  guess_successful: true,
  match_score: 10,
  guess_count: 1,
  round_guess_count: 1,
  total_guesses: 1,
  guess_duration: 100,
  timestamp: DateTime.utc_now(),
  metadata: %{
    source_id: "msg-123",
    correlation_id: "corr-123"
  }
}

# Processing the event
case GameBot.Domain.Events.Pipeline.process_event(event) do
  {:ok, processed_event} ->
    # Event was successfully processed
    Logger.info("Event processed: #{processed_event.id}")
  
  {:error, reason} ->
    # Event processing failed
    Logger.error("Event processing failed: #{inspect(reason)}")
end
```

## Testing Events

Required test cases for each event:

1. Valid event creation
2. Field validation
3. Required field checks
4. Serialization roundtrip
5. Processing pipeline
6. Error cases

Example test:
```elixir
test "creates a valid event" do
  event = %GuessProcessed{
    game_id: "game-123",
    guild_id: "guild-456",
    mode: :two_player,
    round_number: 1,
    team_id: "team-789",
    player1_info: %{player_id: "player1"},
    player2_info: %{player_id: "player2"},
    player1_word: "word1",
    player2_word: "word2",
    guess_successful: true,
    match_score: 10,
    guess_count: 1,
    round_guess_count: 1,
    total_guesses: 1,
    guess_duration: 100,
    timestamp: DateTime.utc_now(),
    metadata: %{
      source_id: "msg-123",
      correlation_id: "corr-123"
    }
  }

  assert :ok = GameBot.Domain.Events.EventValidator.validate(event)
end
``` 