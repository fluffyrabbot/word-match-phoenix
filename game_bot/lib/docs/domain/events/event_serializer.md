# Event Serialization System

## Overview

The Event Serialization system in GameBot provides a consistent mechanism for converting event objects to and from persistent storage formats. This system is crucial for the event-sourcing architecture, allowing events to be stored in the database and reconstructed correctly when retrieved.

## Core Components

### `EventSerializer` Protocol

The `EventSerializer` protocol defines a standard interface for serializing and deserializing events:

```elixir
defprotocol GameBot.Domain.Events.EventSerializer do
  @doc "Converts an event to a map representation for storage"
  def to_map(event)
  
  @doc "Converts a map representation back to an event struct"
  def from_map(data)
end
```

### `EventStructure` Module

The `EventStructure` module defines the common structure and helper functions for all events:

- **Base Fields**: All events include `game_id`, `guild_id`, `mode`, `timestamp`, and `metadata`
- **Helper Functions**: For handling DateTime conversion, validation, and event creation

### Protocol Implementations

#### For Event Types

Each event type implements the `EventSerializer` protocol to handle its specific serialization needs. For example:

```elixir
defimpl EventSerializer, for: TestEvent do
  def to_map(event) do
    %{
      "game_id" => event.game_id,
      "guild_id" => event.guild_id,
      "mode" => Atom.to_string(event.mode),
      "timestamp" => EventStructure.to_iso8601(event.timestamp),
      # Additional fields specific to this event type...
    }
  end
  
  def from_map(data) do
    %TestEvent{
      game_id: data["game_id"],
      guild_id: data["guild_id"],
      mode: String.to_existing_atom(data["mode"]),
      timestamp: EventStructure.parse_timestamp(data["timestamp"]),
      # Conversion for additional fields...
    }
  end
end
```

#### Generic Map Implementation

A generic implementation for `Map` type is provided to support testing and initial deserialization:

```elixir
defimpl EventSerializer, for: Map do
  def to_map(map), do: map
  
  def from_map(data) do
    # Validation and conversion logic...
    # Typically constructs the appropriate event struct
  end
end
```

## Key Features

### Data Type Handling

The serializer handles various data types:

1. **Atoms**: Converted to strings for storage, back to atoms when loading
2. **DateTime**: Converted to ISO8601 strings for storage, parsed when loading
3. **MapSet**: Converted to lists for storage, reconstructed when loading
4. **Nested Structures**: Maps and lists are processed recursively
5. **Optional Fields**: Handled gracefully with appropriate defaults

### Nested Structure Processing

The serializer recursively processes nested data structures:

```elixir
defp serialize_nested(%DateTime{} = dt), do: EventStructure.to_iso8601(dt)
defp serialize_nested(data) when is_map(data) do
  data |> Enum.map(fn {k, v} -> {to_string(k), serialize_nested(v)} end) |> Map.new()
end
defp serialize_nested(data) when is_list(data) do
  Enum.map(data, &serialize_nested/1)
end
defp serialize_nested(other), do: other
```

And similarly for deserialization.

### Validation

The serializer validates critical aspects of the data:

1. **Required Fields**: Ensures all required fields are present
2. **DateTime Format**: Validates timestamp format
3. **Atom Existence**: Validates that mode atoms are registered

### Error Handling

Common error handling includes:

- Raising exceptions for invalid timestamp formats
- Raising exceptions for unregistered mode atoms
- Graceful handling of optional fields

## Usage Examples

### Serializing an Event

```elixir
event = %GameBot.Domain.Events.GameEvents.GameStarted{
  game_id: "game-123",
  guild_id: "guild-456",
  mode: :knockout,
  timestamp: DateTime.utc_now(),
  # Additional fields...
}

serialized_map = EventSerializer.to_map(event)
# Result is a map with string keys ready for JSON encoding
```

### Deserializing an Event

```elixir
data_map = %{
  "game_id" => "game-123",
  "guild_id" => "guild-456",
  "mode" => "knockout",
  "timestamp" => "2023-01-01T12:00:00Z",
  # Additional fields...
}

event = EventSerializer.from_map(data_map)
# Result is a proper event struct
```

## Extending the System

### Adding New Event Types

To add a new event type:

1. Define the event struct with appropriate fields
2. Implement the `EventSerializer` protocol for your event type
3. Register any new mode atoms in your application

### Future Enhancements

Planned improvements to the serialization system:

#### High Priority

1. **Schema Versioning**: Adding explicit versioning to support schema evolution
2. **Enhanced Validation**: More comprehensive validation of all fields
3. **Performance Optimization**: Profile and optimize serialization performance

#### Medium Priority

4. **Binary Format Support**: Support for more compact serialization formats
5. **Compression**: Transparent compression for large events
6. **Encryption**: Support for field-level encryption
7. **Reference Deduplication**: Optimization for repeated structures

#### Low Priority

8. **Partial Serialization**: Support for serializing only changed fields
9. **Custom Formatters**: Extensible formatting for complex types
10. **Streaming Support**: Handling very large events efficiently

## Best Practices

1. **Always validate** input data before deserialization
2. **Include version information** in all serialized formats
3. **Design for forwards compatibility** to support schema evolution
4. **Test roundtrip serialization** for all event types
5. **Handle missing fields gracefully** with sensible defaults
6. **Document the serialization format** for each event type
7. **Keep serialization logic separate** from business logic

## Troubleshooting

### Common Issues

1. **Atom not found errors**: Ensure all mode atoms are registered
2. **DateTime parsing errors**: Validate ISO8601 format
3. **Missing fields**: Check for required field validation
4. **Type mismatches**: Ensure correct data types in the serialized format

### Debugging Techniques

1. Inspect the raw serialized data format
2. Log intermediate conversion steps
3. Test with minimal valid examples
4. Verify protocol implementations for each event type 