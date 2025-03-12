# Using Event Validation with the Serializer

This document explains how to use the event validation system when working with the `Serializer` module.

## Introduction

The `Serializer` module incorporates event validation during both the serialization and deserialization processes. This ensures that invalid events are caught early, preventing them from being stored in the event store or processed by the application.

## Validation Architecture

Our validation system uses a consolidated approach:

1. Primary validation logic lives in each event struct module as a `validate/1` function
2. The `EventValidator` protocol provides a consistent interface for all validation
3. Protocol implementations delegate to the struct's own validation method
4. The serializer uses the `EventValidator` protocol to validate events

This architecture keeps validation logic close to data definitions while maintaining a consistent interface.

## Basic Usage

By default, validation is enabled for all serialization and deserialization operations:

```elixir
alias GameBot.Infrastructure.Persistence.EventStore.Serializer

# Serializing an event (with validation)
event = %GameBot.Domain.Events.GameEvents.GameStarted{...}
{:ok, serialized} = Serializer.serialize(event)

# Deserializing an event (with validation)
{:ok, deserialized_event} = Serializer.deserialize(serialized)
```

## Disabling Validation

In some cases, you may want to bypass validation:

```elixir
# Serializing without validation
{:ok, serialized} = Serializer.serialize(event, validate: false)

# Deserializing without validation
{:ok, deserialized} = Serializer.deserialize(serialized, nil, validate: false)
```

Use cases for disabling validation:
- During migrations when event formats may have changed
- For performance optimization in critical paths
- For compatibility with legacy events that don't conform to current validation rules
- During testing when you want to focus on other aspects

## Handling Validation Errors

When validation fails, the serializer will return an error tuple:

```elixir
case Serializer.serialize(invalid_event) do
  {:ok, serialized} -> 
    # Process the serialized event
    handle_success(serialized)
    
  {:error, reason} ->
    # Handle the validation error
    Logger.error("Validation failed: #{reason}")
    handle_error(reason)
end
```

Similarly for deserialization:

```elixir
case Serializer.deserialize(serialized_data) do
  {:ok, event} -> 
    # Process the deserialized event
    handle_event(event)
    
  {:error, reason} ->
    # Handle the validation error
    Logger.error("Deserialization failed: #{reason}")
    handle_error(reason)
end
```

## Validation Process

The validation process happens in these steps:

1. The serializer receives an event to serialize
2. The serializer calls `EventValidator.validate(event)`
3. The protocol implementation delegates to `event.__struct__.validate(event)`
4. The event struct's validate function performs validation checks
5. If validation passes, serialization continues
6. If validation fails, an error is returned

## Testing with Validation

When writing tests, it's often useful to test both valid and invalid cases:

```elixir
# Test valid event serialization
test "serializes valid event" do
  valid_event = create_valid_game_started()
  assert {:ok, _} = Serializer.serialize(valid_event)
end

# Test invalid event serialization
test "rejects invalid event during serialization" do
  invalid_event = %{create_valid_game_started() | round_number: 0}  # Invalid round number
  assert {:error, error_message} = Serializer.serialize(invalid_event)
  assert error_message =~ "round_number must be positive"
end

# Test bypassing validation
test "can bypass validation for invalid events" do
  invalid_event = %{create_valid_game_started() | round_number: 0}  # Invalid round number
  assert {:ok, _} = Serializer.serialize(invalid_event, validate: false)
end
```

## Common Issues and Solutions

### Missing Fields in Events

If you're getting validation errors about missing fields:

```
{:error, "Required field :id is missing"}
```

Ensure that all required fields are present in your event struct.

### Invalid Field Values

If a field value doesn't meet validation requirements:

```
{:error, "round_number must be a positive integer"}
```

Check the specific validation rules for that field and ensure your values comply.

### Missing Validation Logic

If you create a new event type and try to serialize it, but get an error:

```
{:error, "EventValidator not implemented for Event of type MyNewEvent"}
```

You need to:

1. Add a `validate/1` function to your event struct module:
   ```elixir
   def validate(event) do
     with :ok <- Helpers.validate_base_fields(event),
          :ok <- validate_event_fields(event) do
       :ok
     end
   end
   ```

2. Implement the `EventValidator` protocol for your event type:
   ```elixir
   defimpl GameBot.Domain.Events.EventValidator, for: GameBot.Domain.Events.GameEvents.MyNewEvent do
     def validate(event), do: event.__struct__.validate(event)
   end
   ```

### Error Messages Not Matching Tests

If your tests are failing because the error messages don't match expectations:

1. Check the validation function in the event struct
2. Make sure the error messages in your tests match those in the validation functions
3. Remember that error messages come from the event struct's validation functions

## Adding Validation to New Event Types

To add validation to a new event type:

1. Add validation logic to your event struct:

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
  
  # Field validation functions
  defp validate_field1(value) when is_binary(value), do: :ok
  defp validate_field1(_), do: {:error, "field1 must be a string"}
  
  defp validate_field2(value) when is_integer(value) and value > 0, do: :ok
  defp validate_field2(_), do: {:error, "field2 must be a positive integer"}
end
```

2. Implement the EventValidator protocol:

```elixir
defimpl GameBot.Domain.Events.EventValidator, for: GameBot.Domain.Events.GameEvents.MyNewEvent do
  def validate(event), do: event.__struct__.validate(event)
end
```

## Conclusion

Our consolidated validation approach keeps validation logic close to data definitions while providing a consistent interface through the `EventValidator` protocol. By integrating validation into the serialization process, we ensure that only valid events are stored and processed by the system, improving reliability and reducing the risk of data corruption. 