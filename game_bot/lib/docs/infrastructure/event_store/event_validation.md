# Event Validation System

This document provides an overview of the event validation system in GameBot, explaining its design, implementation, and usage patterns.

## Overview

The event validation system ensures that all events in the system adhere to their expected schemas and business rules. By validating events at both serialization and deserialization time, we can prevent invalid events from being stored or processed, increasing system reliability.

The validation system consists of:

1. `EventValidator` protocol - Defines the interface for event validation
2. Event struct validation - Primary validation logic implemented in each event struct
3. `EventValidatorHelpers` module - Provides common validation functions
4. Serialization integration - Ensures validation occurs during serialization/deserialization

## Key Components

### EventValidator Protocol

The `EventValidator` protocol defines a standard interface for validating events:

```elixir
defprotocol GameBot.Domain.Events.EventValidator do
  @spec validate(t) :: :ok | {:error, String.t()}
  def validate(event)
end
```

### Event Struct Validation

Each event struct implements its own validation logic through a `validate/1` function:

```elixir
defmodule GameBot.Domain.Events.GameEvents.GameStarted do
  # Struct definition...

  def validate(event) do
    with :ok <- validate_base_fields(event),
         :ok <- validate_round_number(event.round_number),
         :ok <- validate_teams(event.teams, event.team_ids, event.player_ids),
         :ok <- validate_roles(event.roles, event.player_ids),
         :ok <- validate_timestamp(event.started_at) do
      :ok
    end
  end
  
  # Validation helper functions...
end
```

### Protocol Implementation

The protocol implementations delegate to the struct's own validation method:

```elixir
defimpl GameBot.Domain.Events.EventValidator, for: GameBot.Domain.Events.GameEvents.GameStarted do
  def validate(event), do: event.__struct__.validate(event)
end
```

This approach keeps validation logic close to the data definition while maintaining a consistent interface through the protocol.

### EventValidatorHelpers

The `EventValidatorHelpers` module provides common validation functions that can be used across different validator implementations:

- `validate_base_fields/1` - Validates common fields in all events
- `validate_required/2` - Ensures required fields are present
- `validate_id/2` - Validates ID fields
- `validate_positive_integer/2` - Validates positive integers
- `validate_non_negative_integer/2` - Validates non-negative integers
- And more...

### Serialization Integration

The validation system is integrated with the serialization process to ensure that:

1. Events are validated before serialization
2. Serialized data is validated before deserialization
3. Deserialized events are validated after creation

## Using Event Validation

### Direct Validation

You can directly validate an event using the `EventValidator` protocol:

```elixir
case EventValidator.validate(event) do
  :ok -> process_event(event)
  {:error, reason} -> handle_error(reason)
end
```

### Validation During Serialization

Validation is automatically performed during serialization and deserialization:

```elixir
# Validate during serialization (enabled by default)
{:ok, serialized} = Serializer.serialize(event)

# Skip validation during serialization
{:ok, serialized} = Serializer.serialize(event, validate: false)

# Validate during deserialization (enabled by default)
{:ok, deserialized} = Serializer.deserialize(serialized)

# Skip validation during deserialization
{:ok, deserialized} = Serializer.deserialize(serialized, nil, validate: false)
```

## Adding New Event Types

To add validation for a new event type:

1. Add a `validate/1` function to your event struct module with event-specific validation logic
2. Use helpers from `EventValidatorHelpers` for common validations
3. Implement the `EventValidator` protocol for your event type, delegating to the struct's validate function
4. Add tests for the new validator implementation

Example implementation in the event struct:

```elixir
defmodule GameBot.Domain.Events.GameEvents.MyNewEvent do
  alias GameBot.Domain.Events.EventValidatorHelpers, as: Helpers

  defstruct [:game_id, :guild_id, :mode, :timestamp, :metadata, :field1, :field2]

  def validate(event) do
    with :ok <- Helpers.validate_base_fields(event),
         :ok <- validate_fields(event) do
      :ok
    end
  end

  defp validate_fields(event) do
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

Then implement the `EventValidator` protocol:

```elixir
defimpl GameBot.Domain.Events.EventValidator, for: GameBot.Domain.Events.GameEvents.MyNewEvent do
  def validate(event), do: event.__struct__.validate(event)
end
```

## Benefits of the Consolidated Approach

Our validation system uses a consolidated approach where:

1. Primary validation logic lives in the event struct modules
2. The `EventValidator` protocol implementations delegate to the struct's own validate function

This provides several benefits:

1. **Cohesion**: Validation logic is defined alongside the data structure it validates
2. **Discoverability**: Developers can find validation rules where they expect them - in the event module
3. **Maintainability**: When changing an event's structure, developers naturally update the validation in the same file
4. **Consistency**: The `EventValidator` protocol provides a consistent interface for all validation
5. **Simplicity**: Protocol implementations are simple and follow a consistent pattern

By validating events at both serialization and deserialization time, we ensure that only valid events are stored and processed, increasing the reliability of the system. The consolidated approach balances concerns of code organization with the need for a consistent validation interface. 