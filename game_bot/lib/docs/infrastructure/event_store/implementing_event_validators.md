# Implementing Event Validators

This guide explains how to implement validation for new event types in the GameBot system using our consolidated approach.

## Introduction

Each event type in the system has its own validation logic to ensure data integrity. Our validation system follows a consistent pattern:

1. Primary validation logic is implemented in the event struct module
2. The `EventValidator` protocol implementation delegates to the struct's validation method
3. Common validation functions are available in the `EventValidatorHelpers` module

This approach keeps validation logic close to the data definition while maintaining a consistent interface through the protocol.

## Implementation Pattern

### 1. Add Validation to the Event Struct

First, add a `validate/1` function to your event struct module:

```elixir
defmodule GameBot.Domain.Events.GameEvents.MyEvent do
  alias GameBot.Domain.Events.EventValidatorHelpers, as: Helpers

  defstruct [
    :game_id, 
    :guild_id, 
    :mode, 
    :timestamp, 
    :metadata,
    # Event-specific fields
    :field1,
    :field2
  ]

  @doc """
  Validates that the event has all required fields and meets business rules.
  """
  def validate(event) do
    with :ok <- Helpers.validate_base_fields(event),
         :ok <- validate_event_fields(event) do
      :ok
    end
  end

  defp validate_event_fields(event) do
    with :ok <- Helpers.validate_required(event, [:field1, :field2]),
         :ok <- validate_field1(event.field1),
         :ok <- validate_field2(event.field2) do
      :ok
    end
  end

  # Private validation functions
  defp validate_field1(value) when is_binary(value), do: :ok
  defp validate_field1(_), do: {:error, "field1 must be a string"}

  defp validate_field2(value) when is_integer(value) and value > 0, do: :ok
  defp validate_field2(_), do: {:error, "field2 must be a positive integer"}
end
```

### 2. Implement the EventValidator Protocol

Then, implement the `EventValidator` protocol for your event type:

```elixir
defimpl GameBot.Domain.Events.EventValidator, for: GameBot.Domain.Events.GameEvents.MyEvent do
  @doc """
  Delegates validation to the event struct's own validate method.
  """
  def validate(event), do: event.__struct__.validate(event)
end
```

That's it! The protocol implementation simply delegates to the struct's own validation method.

## Using EventValidatorHelpers

The `EventValidatorHelpers` module provides common validation functions:

### Base Validation

```elixir
# Validates common fields present in all events
Helpers.validate_base_fields(event)
```

### Field Presence

```elixir
# Ensures required fields are present
Helpers.validate_required(event, [:field1, :field2])
```

### String Validation

```elixir
# Validates string IDs (non-empty strings)
Helpers.validate_id(event.id, :id)
```

### Numeric Validation

```elixir
# Validates positive integers (> 0)
Helpers.validate_positive_integer(event.count, :count)

# Validates non-negative integers (>= 0)
Helpers.validate_non_negative_integer(event.index, :index)

# Validates floats within a range
Helpers.validate_float_in_range(event.probability, :probability, 0.0, 1.0)
```

### Collection Validation

```elixir
# Validates lists
Helpers.validate_list(event.items, :items)

# Validates maps
Helpers.validate_map(event.properties, :properties)

# Validates list elements
Helpers.validate_list_elements(event.users, :users, &validate_user/1)
```

## Common Validation Patterns

### Enum Values

```elixir
defp validate_status(status) when status in [:pending, :active, :completed], do: :ok
defp validate_status(_), do: {:error, "status must be one of [:pending, :active, :completed]"}
```

### Nested Structures

```elixir
defp validate_teams(teams) do
  case Helpers.validate_list(teams, :teams) do
    :ok ->
      Enum.reduce_while(teams, :ok, fn team, :ok ->
        case validate_team(team) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)

    error ->
      error
  end
end
```

### Optional Fields

```elixir
defp validate_optional_field(nil, _field_name), do: :ok
defp validate_optional_field(value, field_name) when is_binary(value), do: :ok
defp validate_optional_field(_, field_name), do: {:error, "#{field_name} must be a string or nil"}
```

## Complete Example

Here's a complete example for a hypothetical `GameFinished` event:

Event struct with validation:

```elixir
defmodule GameBot.Domain.Events.GameEvents.GameFinished do
  alias GameBot.Domain.Events.EventValidatorHelpers, as: Helpers

  defstruct [
    :game_id,
    :guild_id,
    :mode,
    :timestamp,
    :metadata,
    :winning_team_id,
    :scores,
    :duration
  ]

  def validate(event) do
    with :ok <- Helpers.validate_base_fields(event),
         :ok <- validate_event_fields(event) do
      :ok
    end
  end

  defp validate_event_fields(event) do
    with :ok <- Helpers.validate_required(event, [:game_id, :winning_team_id, :scores, :duration]),
         :ok <- Helpers.validate_id(event.game_id, :game_id),
         :ok <- Helpers.validate_id(event.winning_team_id, :winning_team_id),
         :ok <- validate_scores(event.scores),
         :ok <- Helpers.validate_positive_integer(event.duration, :duration) do
      :ok
    end
  end

  defp validate_scores(scores) do
    case Helpers.validate_map(scores, :scores) do
      :ok ->
        Enum.reduce_while(scores, :ok, fn {team_id, score}, :ok ->
          with :ok <- Helpers.validate_id(team_id, "scores key (team_id)"),
               :ok <- Helpers.validate_non_negative_integer(score, "scores value (score)") do
            {:cont, :ok}
          else
            error -> {:halt, error}
          end
        end)

      error ->
        error
    end
  end
end
```

Protocol implementation:

```elixir
defimpl GameBot.Domain.Events.EventValidator, for: GameBot.Domain.Events.GameEvents.GameFinished do
  def validate(event), do: event.__struct__.validate(event)
end
```

## Testing Event Validation

Always create tests for your validation logic. Here's a basic pattern:

```elixir
defmodule GameBot.Domain.Events.GameEvents.GameFinishedTest do
  use ExUnit.Case, async: true
  
  alias GameBot.Domain.Events.GameEvents.GameFinished
  alias GameBot.Domain.Events.EventValidator

  describe "validate/1" do
    test "accepts valid event" do
      event = valid_game_finished()
      assert :ok = EventValidator.validate(event)
    end

    test "rejects missing required fields" do
      event = Map.drop(valid_game_finished(), [:winning_team_id])
      assert {:error, error} = EventValidator.validate(event)
      assert error =~ "winning_team_id is required"
    end

    test "validates field types" do
      event = %{valid_game_finished() | winning_team_id: 123}
      assert {:error, error} = EventValidator.validate(event)
      assert error =~ "winning_team_id must be a string"
    end

    test "validates scores map" do
      event = %{valid_game_finished() | scores: %{"team1" => -1}}
      assert {:error, error} = EventValidator.validate(event)
      assert error =~ "scores value (score) must be a non-negative integer"
    end

    # Helper to create a valid event for testing
    defp valid_game_finished do
      %GameFinished{
        game_id: "game123",
        guild_id: "guild456",
        mode: :standard,
        timestamp: DateTime.utc_now(),
        metadata: %{source_id: "src123", correlation_id: "corr123"},
        winning_team_id: "team1",
        scores: %{"team1" => 10, "team2" => 5},
        duration: 600
      }
    end
  end
end
```

## Migrating Existing Event Types

When migrating existing event types to this approach:

1. Move validation logic from the protocol implementation to the event struct
2. Update the protocol implementation to delegate to the struct's validate method
3. Update tests to ensure they still pass with the new implementation

## Advantages of This Approach

1. **Cohesion**: Validation logic lives alongside the data structure it validates
2. **Discoverability**: Developers can find validation rules where they expect them
3. **Maintainability**: When changing an event's structure, developers update validation in the same file
4. **Consistency**: All event types follow the same validation pattern
5. **Simplicity**: Protocol implementations are simple and follow a consistent pattern

By following this pattern, you'll ensure that your event validation is consistent, maintainable, and closely tied to your data structures. 