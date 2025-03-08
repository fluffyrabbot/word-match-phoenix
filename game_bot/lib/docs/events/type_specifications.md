# Event Type Specifications

This document centralizes type specifications for all events in the system to ensure consistency.

## Common Types

```elixir
@type metadata :: %{String.t() => term()}
@type player_info :: %{
  player_id: String.t(),
  team_id: String.t(),
  name: String.t() | nil,
  role: atom() | nil
}
@type team_info :: %{
  team_id: String.t(),
  player_ids: [String.t()],
  score: integer(),
  matches: integer(),
  total_guesses: integer()
}
@type player_stats :: %{
  total_guesses: pos_integer(),
  successful_matches: non_neg_integer(),
  abandoned_guesses: non_neg_integer(),
  average_guess_count: float()
}
```

## Base Event Fields

All events must include these base fields:

```elixir
@base_fields [
  game_id: String.t(),      # Unique identifier for the game
  guild_id: String.t(),     # Discord guild ID
  mode: atom(),             # Game mode (e.g., :two_player, :knockout)
  timestamp: DateTime.t(),   # When the event occurred
  metadata: metadata()      # Additional context data
]
```

## Game Events

### GuessProcessed

Records a processed guess attempt between two players.

```elixir
@type t :: %GuessProcessed{
  # Base Fields
  game_id: String.t(),
  guild_id: String.t(),
  mode: atom(),
  timestamp: DateTime.t(),
  metadata: metadata(),
  
  # Event-specific Fields
  round_number: pos_integer(),
  team_id: String.t(),
  player1_info: player_info(),
  player2_info: player_info(),
  player1_word: String.t(),
  player2_word: String.t(),
  guess_successful: boolean(),
  match_score: pos_integer() | nil,  # Required when guess_successful is true
  guess_count: pos_integer(),
  round_guess_count: pos_integer(),
  total_guesses: pos_integer(),
  guess_duration: non_neg_integer()
}
```

### GuessAbandoned

Records when a guess attempt is abandoned.

```elixir
@type t :: %GuessAbandoned{
  # Base Fields
  game_id: String.t(),
  guild_id: String.t(),
  mode: atom(),
  timestamp: DateTime.t(),
  metadata: metadata(),
  
  # Event-specific Fields
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
  round_guess_count: pos_integer(),
  total_guesses: pos_integer(),
  guess_duration: non_neg_integer() | nil
}
```

### GameStarted

Records game initialization.

```elixir
@type t :: %GameStarted{
  # Base Fields
  game_id: String.t(),
  guild_id: String.t(),
  mode: atom(),
  timestamp: DateTime.t(),
  metadata: metadata(),
  
  # Event-specific Fields
  round_number: pos_integer(),        # Always 1 for game start
  teams: %{String.t() => [String.t()]},  # team_id => [player_ids]
  team_ids: [String.t()],            # Ordered list of team IDs
  player_ids: [String.t()],          # Ordered list of all player IDs
  roles: %{String.t() => atom()},    # player_id => role mapping
  config: map(),                     # Mode-specific configuration
  started_at: DateTime.t()
}
```

### GameCompleted

Records game completion.

```elixir
@type t :: %GameCompleted{
  # Base Fields
  game_id: String.t(),
  guild_id: String.t(),
  mode: atom(),
  timestamp: DateTime.t(),
  metadata: metadata(),
  
  # Event-specific Fields
  round_number: pos_integer(),
  winners: [String.t()],
  final_scores: %{String.t() => %{
    score: integer(),
    matches: non_neg_integer(),
    total_guesses: pos_integer(),
    average_guesses: float(),
    player_stats: %{String.t() => player_stats()}
  }},
  game_duration: non_neg_integer(),
  total_rounds: pos_integer(),
  finished_at: DateTime.t()
}
```

## Type Validation Rules

1. **Integer Types**
   - Use `pos_integer()` for counts that must be positive (> 0)
   - Use `non_neg_integer()` for counts that can be zero (>= 0)
   - Use `integer()` only when negative values are valid

2. **String Types**
   - Use `String.t()` for all string fields
   - IDs should always be `String.t()`

3. **Maps and Lists**
   - Always specify key and value types for maps
   - Use specific atom literals when the set of values is known
   - Use `atom()` only when the set of values is dynamic

4. **Optional Fields**
   - Mark optional fields with `| nil`
   - Document when fields are conditionally required

## Validation Requirements

1. **Required Fields**
   - All base fields are always required
   - Event-specific required fields must be validated
   - Optional fields should be documented

2. **Numeric Validation**
   - Positive integers must be > 0
   - Non-negative integers must be >= 0
   - Scores must be integers
   - Durations must be non-negative

3. **Consistency Validation**
   - Team IDs must exist in the teams map
   - Player IDs must exist in player lists
   - Timestamps must be valid DateTime structs
   - Metadata must be a map

## Implementation Notes

1. **Type Checking**
   ```elixir
   @spec validate(t()) :: :ok | {:error, String.t()}
   ```

2. **Serialization**
   ```elixir
   @spec to_map(t()) :: map()
   @spec from_map(map()) :: t()
   ```

3. **Event Identification**
   ```elixir
   @spec event_type() :: String.t()
   @spec event_version() :: pos_integer()
   ``` 