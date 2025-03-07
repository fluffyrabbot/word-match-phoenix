# Game Events Documentation

## Overview

The game events system implements an event-sourced architecture for tracking game state changes. All game state modifications are recorded as immutable events, which can be used to rebuild game state and provide an audit trail of game progression.

## Core Event Behaviour

All events must implement the `GameBot.Domain.Events.GameEvents` behaviour, which requires:

```elixir
@callback event_type() :: String.t()
@callback event_version() :: pos_integer()
@callback to_map(struct()) :: map()
@callback from_map(map()) :: struct()
@callback validate(struct()) :: :ok | {:error, term()}
```

## Event Types

### Game Lifecycle Events

#### GameCreated
Emitted when a new game is initially created, before player assignments.

```elixir
%GameCreated{
  game_id: String.t(),
  guild_id: String.t(),
  mode: atom(),
  created_by: String.t(),
  created_at: DateTime.t(),
  team_ids: [String.t()],
  timestamp: DateTime.t(),
  metadata: map()
}
```

#### GameStarted
Emitted when a game officially begins with all players assigned.

```elixir
%GameStarted{
  game_id: String.t(),
  guild_id: String.t(),
  mode: atom(),
  round_number: pos_integer(),
  teams: %{String.t() => [String.t()]},
  team_ids: [String.t()],
  player_ids: [String.t()],
  roles: %{String.t() => atom()},
  config: map(),
  started_at: DateTime.t(),
  timestamp: DateTime.t(),
  metadata: map()
}
```

#### GameCompleted
Emitted when a game ends with final scores and statistics.

```elixir
%GameCompleted{
  game_id: String.t(),
  guild_id: String.t(),
  mode: atom(),
  round_number: pos_integer(),
  winners: [String.t()],
  final_scores: %{String.t() => %{
    score: integer(),
    matches: integer(),
    total_guesses: integer(),
    average_guesses: float(),
    player_stats: %{String.t() => %{
      total_guesses: integer(),
      successful_matches: integer(),
      abandoned_guesses: integer(),
      average_guess_count: float()
    }}
  }},
  game_duration: integer(),
  total_rounds: pos_integer(),
  timestamp: DateTime.t(),
  finished_at: DateTime.t(),
  metadata: map()
}
```

### Round Events

#### RoundStarted
Emitted when a new round begins.

```elixir
%RoundStarted{
  game_id: String.t(),
  guild_id: String.t(),
  mode: atom(),
  round_number: pos_integer(),
  team_states: map(),
  timestamp: DateTime.t(),
  metadata: map()
}
```

### Gameplay Events

#### GuessProcessed
Emitted when both players have submitted their guesses and the attempt is processed.

```elixir
%GuessProcessed{
  game_id: String.t(),
  mode: atom(),
  round_number: pos_integer(),
  team_id: String.t(),
  player1_info: player_info(),
  player2_info: player_info(),
  player1_word: String.t(),
  player2_word: String.t(),
  guess_successful: boolean(),
  guess_count: pos_integer(),
  match_score: integer(),
  timestamp: DateTime.t(),
  metadata: map()
}
```

#### GuessAbandoned
Emitted when a guess attempt is abandoned due to timeout or player giving up.

```elixir
%GuessAbandoned{
  game_id: String.t(),
  mode: atom(),
  round_number: pos_integer(),
  team_id: String.t(),
  player1_info: player_info(),
  player2_info: player_info(),
  reason: :timeout | :player_quit | :disconnected,
  abandoning_player_id: String.t(),
  last_guess: %{
    player_id: String.t(),
    word: String.t(),
    timestamp: DateTime.t()
  } | nil,
  guess_count: pos_integer(),
  timestamp: DateTime.t(),
  metadata: map()
}
```

#### TeamEliminated
Emitted when a team is eliminated from the game.

```elixir
%TeamEliminated{
  game_id: String.t(),
  mode: atom(),
  round_number: pos_integer(),
  team_id: String.t(),
  reason: :timeout | :max_guesses | :round_loss | :forfeit,
  final_state: team_info(),
  final_score: integer(),
  player_stats: %{String.t() => %{
    total_guesses: integer(),
    successful_matches: integer(),
    abandoned_guesses: integer(),
    average_guess_count: float()
  }},
  timestamp: DateTime.t(),
  metadata: map()
}
```

### Mode-Specific Events

#### KnockoutRoundCompleted
Emitted when a knockout round ends.

```elixir
%KnockoutRoundCompleted{
  game_id: String.t(),
  mode: atom(),
  round_number: pos_integer(),
  eliminated_teams: [%{
    team_id: String.t(),
    reason: :timeout | :max_guesses | :round_loss | :forfeit,
    final_score: integer(),
    player_stats: %{String.t() => map()}
  }],
  advancing_teams: [%{
    team_id: String.t(),
    score: integer(),
    matches: integer(),
    total_guesses: integer()
  }],
  round_duration: integer(),
  timestamp: DateTime.t(),
  metadata: map()
}
```

#### RaceModeTimeExpired
Emitted when time runs out in race mode.

```elixir
%RaceModeTimeExpired{
  game_id: String.t(),
  mode: atom(),
  round_number: pos_integer(),
  final_matches: %{String.t() => %{
    matches: integer(),
    total_guesses: integer(),
    average_guesses: float(),
    last_match_timestamp: DateTime.t(),
    player_stats: %{String.t() => map()}
  }},
  game_duration: integer(),
  timestamp: DateTime.t(),
  metadata: map()
}
```

## Event Handling

### Event Store Integration

Events are persisted using the EventStore with proper versioning and concurrency control:

```elixir
# Storing events
{:ok, _} = EventStore.append_to_stream(
  game_id,
  :any_version,
  [event]
)

# Reading events
{:ok, events} = EventStore.read_stream_forward(game_id)
```

### Event Validation

All events are validated before being stored:

1. Required fields are checked
2. Data types are verified
3. Business rules are enforced
4. DateTime fields are properly formatted

### Event Serialization

Events are serialized to maps for storage:

```elixir
def serialize(event) do
  %{
    "event_type" => event.__struct__.event_type(),
    "event_version" => event.__struct__.event_version(),
    "data" => event.__struct__.to_map(event),
    "stored_at" => DateTime.utc_now() |> DateTime.to_iso8601()
  }
end
```

### Event Deserialization

Events are reconstructed from stored data:

```elixir
def deserialize(%{"event_type" => type, "data" => data}) do
  module = get_event_module(type)
  module.from_map(data)
end
```

## Best Practices

1. **Event Versioning**
   - All events must have a version number
   - Version changes require migration strategy
   - Store schema version with event data

2. **DateTime Handling**
   - Always use UTC for timestamps
   - Store in ISO8601 format
   - Include both creation and occurrence times

3. **Metadata**
   - Include relevant context
   - Add correlation IDs
   - Track originating command

4. **Validation**
   - Validate before storing
   - Include business rule checks
   - Ensure data consistency

5. **Guild Context**
   - Include guild_id in relevant events
   - Maintain proper data segregation
   - Filter queries by guild

## Event Flow Examples

### Game Creation and Start
```elixir
[
  %GameCreated{...},
  %GameStarted{...}
]
```

### Successful Game Round
```elixir
[
  %RoundStarted{...},
  %GuessProcessed{guess_successful: true},
  %RoundCompleted{...}
]
```

### Game Completion
```elixir
[
  %GameCompleted{
    winners: ["team_1"],
    final_scores: %{
      "team_1" => %{score: 100, ...},
      "team_2" => %{score: 80, ...}
    }
  }
]
``` 