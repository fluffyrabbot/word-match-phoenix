# Event System Conventions

## Overview

This document outlines the conventions and standards for the GameBot event system. These conventions ensure consistency, maintainability, and reliability across the event-driven architecture.

## Core Principles

### 1. Type Safety
- Use precise type specifications (`pos_integer()`, `non_neg_integer()`, etc.)
- Define clear type constraints for all fields
- Use common type definitions from `EventStructure`
- Document type requirements and constraints

### 2. Validation
- Validate all fields comprehensively
- Use pattern matching for validation where possible
- Return clear, descriptive error messages
- Validate at both struct and field levels

### 3. Serialization
- Ensure JSON compatibility
- Handle complex types consistently
- Preserve type information
- Handle optional fields appropriately

## Type Specifications

### 1. Base Types
```elixir
@type metadata :: %{String.t() => term()}

@type team_info :: %{
  team_id: String.t(),
  player_ids: [String.t()],
  score: integer(),
  matches: non_neg_integer(),
  total_guesses: pos_integer()
}

@type player_stats :: %{
  total_guesses: pos_integer(),
  successful_matches: non_neg_integer(),
  abandoned_guesses: non_neg_integer(),
  average_guess_count: float()
}
```

### 2. Base Fields
Every event must include:
```elixir
@base_fields [
  :game_id,    # String.t() - Unique identifier for the game
  :guild_id,   # String.t() - Discord guild ID
  :mode,       # atom() - Game mode
  :timestamp,  # DateTime.t() - When the event occurred
  :metadata    # metadata() - Additional event metadata
]
```

### 3. Numeric Types
- `pos_integer()`: For counts that must be positive (> 0)
  - guess_count
  - total_guesses
  - round_guess_count
- `non_neg_integer()`: For counts that can be zero (>= 0)
  - matches
  - abandoned_guesses
  - game_duration
- `integer()`: For scores that can be negative
  - score
  - final_score

## Protocol Implementations

### 1. EventValidator Protocol
```elixir
defimpl EventValidator, for: MyEvent do
  def validate(event) do
    with :ok <- validate_base_fields(event),
         :ok <- validate_event_fields(event) do
      :ok
    end
  end

  defp validate_base_fields(event) do
    with :ok <- validate_required_fields(event),
         :ok <- validate_id_fields(event),
         :ok <- validate_timestamp(event.timestamp),
         :ok <- validate_mode(event.mode) do
      :ok
    end
  end

  defp validate_event_fields(event) do
    with :ok <- validate_numeric_constraints(event),
         :ok <- validate_nested_structures(event) do
      :ok
    end
  end
end
```

### 2. EventSerializer Protocol
```elixir
defimpl EventSerializer, for: MyEvent do
  def to_map(event) do
    %{
      "game_id" => event.game_id,
      "guild_id" => event.guild_id,
      "mode" => Atom.to_string(event.mode),
      "timestamp" => DateTime.to_iso8601(event.timestamp),
      "metadata" => event.metadata || %{}
    }
  end

  def from_map(data) do
    %MyEvent{
      game_id: data["game_id"],
      guild_id: data["guild_id"],
      mode: String.to_existing_atom(data["mode"]),
      timestamp: EventStructure.parse_timestamp(data["timestamp"]),
      metadata: data["metadata"] || %{}
    }
  end
end
```

## Event Module Structure

### 1. Module Definition
```elixir
defmodule GameBot.Domain.Events.GameEvents.MyEvent do
  @moduledoc """
  Emitted when [event description].

  Base fields:
  - game_id: Unique identifier for the game
  - guild_id: Discord guild ID where the game is being played
  - timestamp: When the event occurred
  - metadata: Additional context about the event

  Event-specific fields:
  - [field]: [description]
  """
  use EventStructure

  @type t :: %__MODULE__{
    # Base fields
    game_id: String.t(),
    guild_id: String.t(),
    mode: atom(),
    timestamp: DateTime.t(),
    metadata: metadata(),
    # Event-specific fields
    field1: type1(),
    field2: type2()
  }
  defstruct [:game_id, :guild_id, :mode, :timestamp, :metadata, :field1, :field2]
end
```

### 2. Required Callbacks
```elixir
@impl true
def event_type(), do: "my_event"

@impl true
def event_version(), do: 1

@impl true
def validate(%__MODULE__{} = event) do
  with :ok <- validate_base_fields(event),
       :ok <- validate_event_fields(event) do
    :ok
  end
end
```

## Validation Guidelines

### 1. Base Field Validation
- Check presence of all required fields
- Validate ID fields are non-empty strings
- Ensure timestamp is valid and not in future
- Verify mode is a valid atom

### 2. Numeric Validation
- Use appropriate numeric type constraints
- Validate ranges where applicable
- Check mathematical relationships
- Handle edge cases (zero, negative)

### 3. Nested Structure Validation
- Validate all nested maps and lists
- Check required nested fields
- Validate relationships between nested fields
- Handle optional nested fields

## Serialization Guidelines

### 1. DateTime Handling
- Serialize to ISO8601 strings
- Use EventStructure.parse_timestamp for parsing
- Handle timezone information correctly
- Validate parsed timestamps

### 2. Complex Type Handling
- Convert atoms to strings
- Handle MapSets and other collections
- Preserve type information
- Handle recursive structures

### 3. Optional Field Handling
- Preserve nil values
- Use default values consistently
- Document optional field behavior
- Handle missing fields gracefully

## Testing Requirements

### 1. Validation Tests
```elixir
test "validates required fields" do
  event = %MyEvent{
    game_id: "game123",
    guild_id: "guild123",
    mode: :two_player,
    timestamp: DateTime.utc_now(),
    metadata: %{"guild_id" => "guild123"}
  }
  assert :ok = MyEvent.validate(event)
end

test "fails validation with missing fields" do
  event = %MyEvent{game_id: "game123"}
  assert {:error, "guild_id is required"} = MyEvent.validate(event)
end
```

### 2. Serialization Tests
```elixir
test "serializes and deserializes correctly" do
  original = %MyEvent{
    game_id: "game123",
    guild_id: "guild123",
    mode: :two_player,
    timestamp: DateTime.utc_now(),
    metadata: %{"guild_id" => "guild123"}
  }
  serialized = MyEvent.to_map(original)
  reconstructed = MyEvent.from_map(serialized)
  assert reconstructed == original
end
```

### 3. Edge Case Tests
```elixir
test "handles optional fields" do
  event = %MyEvent{
    game_id: "game123",
    guild_id: "guild123",
    mode: :two_player,
    timestamp: DateTime.utc_now(),
    metadata: %{"guild_id" => "guild123"},
    optional_field: nil
  }
  assert :ok = MyEvent.validate(event)
end
```

## Error Handling

### 1. Validation Errors
- Return `{:error, reason}` with descriptive messages
- Use pattern matching for specific error cases
- Include field name in error messages
- Provide actionable error information

### 2. Serialization Errors
- Raise ArgumentError for invalid data
- Include context in error messages
- Handle missing or malformed data
- Preserve error context

## Best Practices

1. **Type Safety**
   - Use precise type specifications
   - Document type constraints
   - Validate types comprehensively
   - Handle edge cases

2. **Validation**
   - Validate early and often
   - Use pattern matching
   - Return clear error messages
   - Check logical constraints

3. **Serialization**
   - Ensure JSON compatibility
   - Handle complex types
   - Preserve type information
   - Handle optional fields

4. **Documentation**
   - Document all fields
   - Include examples
   - Explain constraints
   - Document error cases

5. **Testing**
   - Test validation thoroughly
   - Test serialization
   - Test edge cases
   - Test error handling

## Event Structure Conventions

### 1. Event Type Naming
- Use underscores for event type names (e.g., `guess_processed`, `team_created`)
- Avoid using dots (e.g., `guess.matched`, `team.created`)
- Event types should be descriptive and follow the pattern: `{entity}_{action}`
- Examples:
  - ✅ `guess_processed`
  - ✅ `team_created`
  - ✅ `round_completed`
  - ❌ `guess.matched`
  - ❌ `team.created`

### 2. Event Module Structure
- All events must implement the `GameBot.Domain.Events.GameEvents` behaviour
- Required callbacks:
  ```elixir
  @callback event_type() :: String.t()
  @callback event_version() :: pos_integer()
  @callback to_map(struct()) :: map()
  @callback from_map(map()) :: struct()
  @callback validate(struct()) :: :ok | {:error, term()}
  ```

### 3. Required Fields
Every event must include:
- `game_id`: String.t() - Unique identifier for the game
- `guild_id`: String.t() - Discord guild ID
- `timestamp`: DateTime.t() - When the event occurred
- `metadata`: map() - Additional event metadata

### 4. Event-Specific Fields
#### GuessProcessed Event
The GuessProcessed event represents a complete guess attempt lifecycle and includes:

Required Fields:
- `team_id`: String.t() - Team making the guess
- `player1_info`, `player2_info`: player_info() - Information about both players
- `player1_word`, `player2_word`: String.t() - The words guessed
- `guess_successful`: boolean() - Whether the words matched
- `match_score`: integer() | nil - Score if matched, nil if not matched

Timing and Round Context:
- `guess_duration`: integer() - Time taken for this guess in milliseconds
- `round_number`: pos_integer() - Current round number
- `round_guess_count`: pos_integer() - Number of guesses in this round
- `total_guesses`: pos_integer() - Total guesses across all rounds

### 5. Event Validation
- Implement comprehensive validation in the `validate/1` callback
- Use pattern matching and guard clauses where possible
- Return `:ok` or `{:error, reason}`
- Validate all required fields
- Ensure logical consistency (e.g., match_score presence matches guess_successful)

### 6. Serialization
- Implement `to_map/1` and `from_map/1` callbacks
- Handle DateTime serialization consistently
- Include all fields in serialization
- Handle nil values appropriately

## Event Organization

### 1. Event Module Location
- Core game events: `lib/game_bot/domain/events/game_events.ex`
- Team events: `lib/game_bot/domain/events/team_events.ex`
- Guess events: `lib/game_bot/domain/events/guess_events.ex`
- Error events: `lib/game_bot/domain/events/error_events.ex`

### 2. Event Categorization
- Game lifecycle events (start, end, round)
- Player/Team events (creation, updates)
- Gameplay events (guesses, matches)
- Error events (validation failures, system errors)

## Recent Changes

### 1. Event Type Standardization
- Changed all event types to use underscore notation
- Removed dot notation from event types
- Updated all references to event types

### 2. Event Structure Improvements
- Added consistent metadata support
- Standardized validation patterns
- Added proper type specs
- Implemented consistent serialization

### 3. Removed Redundant Events
- Removed `PlayerJoined` event
- Consolidated round events (`RoundEnded` and `RoundFinished` into `RoundCompleted`)
- Standardized guess events structure

### 4. Validation Enhancements
- Added comprehensive field validation
- Implemented mode-specific validation
- Added proper error messages
- Standardized validation patterns

## Implementation Guidelines

### 1. Creating New Events
```elixir
defmodule GameBot.Domain.Events.GameEvents.NewEvent do
  @moduledoc "Emitted when something happens"
  @behaviour GameBot.Domain.Events.GameEvents

  @type t :: %__MODULE__{
    game_id: String.t(),
    guild_id: String.t(),
    timestamp: DateTime.t(),
    metadata: GameBot.Domain.Events.GameEvents.metadata(),
    # Add event-specific fields
  }
  defstruct [:game_id, :guild_id, :timestamp, :metadata]

  def event_type(), do: "new_event"
  def event_version(), do: 1

  def validate(%__MODULE__{} = event) do
    with :ok <- EventStructure.validate(event) do
      # Add event-specific validation
      :ok
    end
  end

  def to_map(%__MODULE__{} = event) do
    %{
      "game_id" => event.game_id,
      "guild_id" => event.guild_id,
      "timestamp" => DateTime.to_iso8601(event.timestamp),
      "metadata" => event.metadata || %{}
      # Add event-specific fields
    }
  end

  def from_map(data) do
    %__MODULE__{
      game_id: data["game_id"],
      guild_id: data["guild_id"],
      timestamp: GameBot.Domain.Events.GameEvents.parse_timestamp(data["timestamp"]),
      metadata: data["metadata"] || %{}
      # Add event-specific fields
    }
  end
end
```

### 2. Testing Events
```elixir
defmodule GameBot.Domain.Events.NewEventTest do
  use ExUnit.Case
  alias GameBot.Domain.Events.GameEvents.NewEvent

  describe "NewEvent" do
    test "creates a valid event" do
      event = %NewEvent{
        game_id: "game123",
        guild_id: "guild123",
        timestamp: DateTime.utc_now(),
        metadata: %{"round" => 1}
      }

      assert :ok = NewEvent.validate(event)
      assert "new_event" = NewEvent.event_type()
      assert 1 = NewEvent.event_version()
    end

    test "fails validation with missing required fields" do
      event = %NewEvent{
        game_id: "game123",
        timestamp: DateTime.utc_now()
      }

      assert {:error, "guild_id is required"} = NewEvent.validate(event)
    end

    test "converts to and from map" do
      original = %NewEvent{
        game_id: "game123",
        guild_id: "guild123",
        timestamp: DateTime.utc_now(),
        metadata: %{"round" => 1}
      }

      map = NewEvent.to_map(original)
      reconstructed = NewEvent.from_map(map)

      assert reconstructed.game_id == original.game_id
      assert reconstructed.guild_id == original.guild_id
      assert reconstructed.metadata == original.metadata
    end
  end
end
```

## Version Control

1. **Event Versioning**
   - Increment version for schema changes
   - Document version changes
   - Maintain backward compatibility

2. **Migration Strategy**
   - Document migration paths
   - Provide upgrade guides
   - Test migration scenarios

## Event Processing Guidelines

### 1. Timing and Performance
- Record start and end times for operations
- Calculate and include duration in relevant events
- Use consistent timestamp handling
- Example:
  ```elixir
  start_time = DateTime.utc_now()
  # ... processing ...
  end_time = DateTime.utc_now()
  duration = DateTime.diff(end_time, start_time, :millisecond)
  ```

### 2. Round Context
- Include round-specific information in events
- Track both round-specific and total counts
- Maintain historical context
- Example:
  ```elixir
  %GuessProcessed{
    round_number: current_round,
    round_guess_count: team_round_guesses,
    total_guesses: team_total_guesses
  }
  ```

### 3. State Updates
- Complete all state updates before emitting events
- Ensure atomic operations where possible
- Validate state consistency
- Example:
  ```elixir
  with :ok <- validate_operation(state),
       {:ok, new_state} <- update_state(state),
       event <- create_event(new_state) do
    {:ok, new_state, event}
  end
  ``` 