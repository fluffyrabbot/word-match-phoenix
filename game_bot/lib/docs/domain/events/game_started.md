# GameStarted Event

## Overview

The `GameStarted` event is emitted when a game officially begins. This occurs after all players have been assigned to teams and roles, and the game configuration has been finalized.

## Event Definition

```elixir
defmodule GameBot.Domain.Events.GameEvents.GameStarted do
  use GameBot.Domain.Events.BaseEvent,
    event_type: "game_started",
    version: 1,
    fields: [
      field(:teams, :map),
      field(:team_ids, {:array, :string}),
      field(:player_ids, {:array, :string}),
      field(:roles, :map),
      field(:config, :map),
      field(:started_at, :utc_datetime_usec)
    ]
end
```

## Fields

### Base Fields (Inherited)
- `game_id` (string, required) - Unique identifier for the game
- `guild_id` (string, required) - Discord guild ID where the game is being played
- `mode` (enum, required) - Game mode (:two_player, :knockout, :race)
- `round_number` (integer, required) - Initial round number (typically 1)
- `timestamp` (utc_datetime_usec, required) - When the event occurred
- `metadata` (map, required) - Additional context about the event

### Custom Fields
- `teams` (map, required) - Map of team IDs to player IDs
  ```elixir
  %{
    "team_id" => [player_id_1, player_id_2]
  }
  ```
- `team_ids` (list of strings, required) - List of all team IDs in play order
- `player_ids` (list of strings, required) - List of all player IDs
- `roles` (map, required) - Map of player IDs to their roles
  ```elixir
  %{
    "player_id" => :giver | :guesser
  }
  ```
- `config` (map, required) - Game configuration settings
  ```elixir
  %{
    max_guesses: pos_integer(),
    time_limit: pos_integer() | nil,
    word_list: String.t(),
    scoring: :standard | :time_bonus | :streak
  }
  ```
- `started_at` (utc_datetime_usec, required) - Timestamp when the game started

## Validation Rules

1. Base field validation (handled by BaseEvent)
2. Required fields must be present
3. Custom field validation:
   ```elixir
   def validate_custom_fields(changeset) do
     super(changeset)
     |> validate_teams()
     |> validate_roles()
     |> validate_config()
   end
   ```
4. Team validation:
   - All teams must have exactly 2 players
   - All player IDs must be unique
   - Team IDs must match team_ids list
5. Role validation:
   - Each team must have one giver and one guesser
   - All player IDs must have assigned roles
6. Config validation:
   - max_guesses must be positive
   - time_limit must be positive or nil
   - word_list must be a valid identifier
   - scoring must be a valid strategy

## Example Usage

```elixir
# Creating a new GameStarted event
event = %GameBot.Domain.Events.GameEvents.GameStarted{
  game_id: "game-123",
  guild_id: "guild-456",
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
    max_guesses: 10,
    time_limit: 300,
    word_list: "standard",
    scoring: :standard
  },
  started_at: DateTime.utc_now(),
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
   test "creates valid game started event" do
     event = build(:game_started_event)
     assert :ok = EventValidator.validate(event)
   end
   ```

2. Team validation
   ```elixir
   test "validates team structure" do
     event = build(:game_started_event, teams: %{"team1" => ["player1"]})
     assert {:error, _} = EventValidator.validate(event)
   end
   ```

3. Role validation
   ```elixir
   test "validates role assignments" do
     event = build(:game_started_event, roles: %{"player1" => :giver, "player2" => :giver})
     assert {:error, _} = EventValidator.validate(event)
   end
   ```

4. Config validation
   ```elixir
   test "validates game configuration" do
     event = build(:game_started_event, config: %{max_guesses: 0})
     assert {:error, _} = EventValidator.validate(event)
   end
   ```

## Event Flow

The GameStarted event is typically part of the following flow:

1. GameCreated event
2. GameStarted event
3. RoundStarted event

## Related Events

- GameCreated - Initial game creation before player assignments
- RoundStarted - First round begins after game starts
- GameCompleted - Game ends after all rounds are complete 