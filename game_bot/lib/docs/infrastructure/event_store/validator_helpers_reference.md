# Event Validator Helpers Reference

This document provides a reference for the `GameBot.Domain.Events.EventValidatorHelpers` module, which contains utility functions for validating events.

## Overview

The `EventValidatorHelpers` module provides a set of common validation functions that can be used across different event validator implementations. These functions help ensure consistent validation patterns and reduce code duplication.

## Core Validation Functions

### Base Event Validation

```elixir
@spec validate_base_fields(event :: struct()) :: :ok | {:error, String.t()}
def validate_base_fields(event)
```

Validates the base fields that should be present in all events, including:
- `:id` - Must be a non-empty string
- `:timestamp` - Must be a valid `DateTime` struct or ISO 8601 string

### Required Fields

```elixir
@spec validate_required(data :: map() | struct(), fields :: [atom()]) :: :ok | {:error, String.t()}
def validate_required(data, fields)
```

Validates that all required fields are present in the data.

**Examples:**
```elixir
# Checks that event has :field1, :field2, and :field3 fields
validate_required(event, [:field1, :field2, :field3])
```

### Map Structure Validation

```elixir
@spec validate_structure(data :: map(), required_keys :: [atom()]) :: :ok | {:error, String.t()}
def validate_structure(data, required_keys)
```

Validates that a map has all the required keys.

**Examples:**
```elixir
# Validates that data map has :type, :data, and :metadata keys
validate_structure(data, [:type, :data, :metadata])
```

## String Validation

### ID Validation

```elixir
@spec validate_id(value :: any(), field_name :: atom() | String.t()) :: :ok | {:error, String.t()}
def validate_id(value, field_name)
```

Validates that a value is a valid ID (non-empty string).

**Examples:**
```elixir
validate_id(event.id, :id)
validate_id(team_id, "team_id")
```

### Non-Empty String Validation

```elixir
@spec validate_non_empty_string(value :: any(), field_name :: atom() | String.t()) :: :ok | {:error, String.t()}
def validate_non_empty_string(value, field_name)
```

Validates that a value is a non-empty string.

**Examples:**
```elixir
validate_non_empty_string(event.user_name, :user_name)
```

### String Length Validation

```elixir
@spec validate_string_length(value :: any(), field_name :: atom() | String.t(), min_length :: non_neg_integer(), max_length :: non_neg_integer()) :: :ok | {:error, String.t()}
def validate_string_length(value, field_name, min_length, max_length)
```

Validates that a string's length is within the specified range.

**Examples:**
```elixir
# Validates that username is between 3 and 20 characters
validate_string_length(username, :username, 3, 20)
```

## Numeric Validation

### Positive Integer Validation

```elixir
@spec validate_positive_integer(value :: any(), field_name :: atom() | String.t()) :: :ok | {:error, String.t()}
def validate_positive_integer(value, field_name)
```

Validates that a value is a positive integer (greater than 0).

**Examples:**
```elixir
validate_positive_integer(event.round_number, :round_number)
```

### Non-Negative Integer Validation

```elixir
@spec validate_non_negative_integer(value :: any(), field_name :: atom() | String.t()) :: :ok | {:error, String.t()}
def validate_non_negative_integer(value, field_name)
```

Validates that a value is a non-negative integer (greater than or equal to 0).

**Examples:**
```elixir
validate_non_negative_integer(event.score, :score)
```

### Float Validation

```elixir
@spec validate_float(value :: any(), field_name :: atom() | String.t()) :: :ok | {:error, String.t()}
def validate_float(value, field_name)
```

Validates that a value is a float.

**Examples:**
```elixir
validate_float(event.probability, :probability)
```

### Float Range Validation

```elixir
@spec validate_float_in_range(value :: any(), field_name :: atom() | String.t(), min :: float(), max :: float()) :: :ok | {:error, String.t()}
def validate_float_in_range(value, field_name, min, max)
```

Validates that a value is a float within the specified range.

**Examples:**
```elixir
# Validates that probability is between 0.0 and 1.0
validate_float_in_range(event.probability, :probability, 0.0, 1.0)
```

## Collection Validation

### List Validation

```elixir
@spec validate_list(value :: any(), field_name :: atom() | String.t()) :: :ok | {:error, String.t()}
def validate_list(value, field_name)
```

Validates that a value is a list.

**Examples:**
```elixir
validate_list(event.teams, :teams)
```

### Map Validation

```elixir
@spec validate_map(value :: any(), field_name :: atom() | String.t()) :: :ok | {:error, String.t()}
def validate_map(value, field_name)
```

Validates that a value is a map.

**Examples:**
```elixir
validate_map(event.properties, :properties)
```

### List Elements Validation

```elixir
@spec validate_list_elements(list :: any(), field_name :: atom() | String.t(), validator :: (any() -> :ok | {:error, String.t()})) :: :ok | {:error, String.t()}
def validate_list_elements(list, field_name, validator)
```

Validates each element in a list using the provided validator function.

**Examples:**
```elixir
validate_list_elements(event.teams, :teams, &validate_team/1)
```

### Map Values Validation

```elixir
@spec validate_map_values(map :: any(), field_name :: atom() | String.t(), validator :: (any() -> :ok | {:error, String.t()})) :: :ok | {:error, String.t()}
def validate_map_values(map, field_name, validator)
```

Validates each value in a map using the provided validator function.

**Examples:**
```elixir
validate_map_values(event.team_scores, :team_scores, &validate_score/1)
```

## Time Validation

### DateTime Validation

```elixir
@spec validate_datetime(value :: any(), field_name :: atom() | String.t()) :: :ok | {:error, String.t()}
def validate_datetime(value, field_name)
```

Validates that a value is a valid DateTime struct or ISO 8601 string.

**Examples:**
```elixir
validate_datetime(event.timestamp, :timestamp)
```

## Boolean Validation

```elixir
@spec validate_boolean(value :: any(), field_name :: atom() | String.t()) :: :ok | {:error, String.t()}
def validate_boolean(value, field_name)
```

Validates that a value is a boolean.

**Examples:**
```elixir
validate_boolean(event.is_active, :is_active)
```

## Enum Validation

```elixir
@spec validate_enum(value :: any(), field_name :: atom() | String.t(), valid_values :: list()) :: :ok | {:error, String.t()}
def validate_enum(value, field_name, valid_values)
```

Validates that a value is one of the specified valid values.

**Examples:**
```elixir
validate_enum(event.status, :status, [:pending, :active, :completed])
```

## Protocol Implementation Check

```elixir
@spec validate_implements_protocol(value :: any(), protocol :: module(), field_name :: atom() | String.t()) :: :ok | {:error, String.t()}
def validate_implements_protocol(value, protocol, field_name)
```

Validates that a value implements the specified protocol.

**Examples:**
```elixir
validate_implements_protocol(event.metadata, GameBot.Domain.Events.Metadata, :metadata)
```

## Composite Validation

### Chain Validation

```elixir
@spec validate_all(validations :: [{:ok | {:error, String.t()}}]) :: :ok | {:error, String.t()}
def validate_all(validations)
```

Runs all validations and returns the first error encountered, or `:ok` if all validations pass.

**Examples:**
```elixir
validate_all([
  validate_id(event.id, :id),
  validate_datetime(event.timestamp, :timestamp),
  validate_non_empty_string(event.name, :name)
])
```

## Error Formatting

```elixir
@spec format_error(field_name :: atom() | String.t(), message :: String.t()) :: String.t()
def format_error(field_name, message)
```

Formats an error message for a specific field.

**Examples:**
```elixir
format_error(:score, "must be a non-negative integer")
# Returns: "score must be a non-negative integer"
```

## Usage Example

Here's a comprehensive example showing how to use multiple helper functions together:

```elixir
defimpl GameBot.Domain.Events.EventValidator, for: GameBot.Domain.Events.GameEvents.RoundStarted do
  alias GameBot.Domain.Events.EventValidatorHelpers, as: Helpers

  def validate(event) do
    with :ok <- Helpers.validate_base_fields(event),
         :ok <- validate_fields(event) do
      :ok
    end
  end

  defp validate_fields(event) do
    with :ok <- Helpers.validate_required(event, [:game_id, :round_number, :teams, :timer_seconds]),
         :ok <- Helpers.validate_id(event.game_id, :game_id),
         :ok <- Helpers.validate_positive_integer(event.round_number, :round_number),
         :ok <- validate_teams(event.teams),
         :ok <- Helpers.validate_positive_integer(event.timer_seconds, :timer_seconds) do
      :ok
    end
  end

  defp validate_teams(teams) do
    with :ok <- Helpers.validate_list(teams, :teams) do
      Helpers.validate_list_elements(teams, :teams, fn team ->
        with :ok <- Helpers.validate_required(team, [:id, :name, :score]),
             :ok <- Helpers.validate_id(team.id, "team.id"),
             :ok <- Helpers.validate_non_empty_string(team.name, "team.name"),
             :ok <- Helpers.validate_non_negative_integer(team.score, "team.score") do
          :ok
        end
      end)
    end
  end
end
```

## Best Practices

1. **Always validate base fields first**  
   Start validation with `validate_base_fields/1` to ensure common fields are valid.

2. **Use descriptive field names**  
   When calling validation functions, use descriptive field names to make error messages clearer.

3. **Chain validations with `with`**  
   Use the `with` statement to chain multiple validations together.

4. **Validate nested structures hierarchically**  
   First validate the structure (is it a list/map?), then validate its contents.

5. **Reuse validation functions**  
   Define reusable validation functions for common structures in your events.

6. **Add custom validators when needed**  
   When the helper functions aren't enough, create your own custom validator functions.

## Conclusion

The `EventValidatorHelpers` module provides a consistent set of validation functions that can be used across different event validators. By using these helpers, you can ensure consistent validation patterns and reduce code duplication across your validator implementations. 