# GameBot Event System Documentation

## Overview

This directory contains comprehensive documentation for the event system that powers GameBot. The event system is the backbone of the application, implementing an event-sourcing architecture that enables robust game state management, auditing, and extensibility.

## Documentation Files

### Core Concepts

- [**Event System Architecture**](event_system_architecture.md) - High-level overview of the event-sourcing architecture, including commands, events, projections, and reactors.

### Components

- [**Event Serializer**](event_serializer.md) - Detailed documentation of the serialization system that converts events to/from persistent storage formats.
- [**Event Metadata**](event_metadata.md) - Information about the metadata system that provides context and tracking for all events.

## Quick Reference

### Event Flow

```
Command → Validation → Events → Persistence → Projections → Side Effects
```

### Key Modules

- `GameBot.Domain.Events.EventSerializer` - Protocol for serializing and deserializing events
- `GameBot.Domain.Events.EventStructure` - Common structure and utilities for events
- `GameBot.Domain.Events.Metadata` - Metadata creation and manipulation functions
- `GameBot.Infrastructure.Persistence.EventStore` - Storage and retrieval of events

### Best Practices

1. **Events are immutable** - Once created, never modify them
2. **Include all context** - Events should contain all relevant data
3. **Design for future evolution** - Consider how events might change over time
4. **Process events idempotently** - Handling the same event twice should be safe
5. **Test event roundtrips** - Ensure events serialize and deserialize correctly

## Usage Examples

### Creating and Serializing an Event

```elixir
# Create a game completed event
event = %GameBot.Domain.Events.GameEvents.GameCompleted{
  game_id: "game-123",
  guild_id: "guild-456",
  mode: :knockout,
  timestamp: DateTime.utc_now(),
  # Additional fields...
}

# Serialize for storage
serialized_map = EventSerializer.to_map(event)
```

### Retrieving and Deserializing Events

```elixir
# Read events from storage
{:ok, serialized_events} = EventStore.read_stream_forward("game-123")

# Deserialize events
events = Enum.map(serialized_events, &EventSerializer.from_map/1)
```

## Future Development

See the individual documentation files for roadmaps on future enhancements to each component of the event system.

## Contributing

When adding new event types or modifying existing ones:

1. Implement the `EventSerializer` protocol for any new event type
2. Update tests to cover serialization and deserialization
3. Consider backward compatibility with existing stored events
4. Document any changes to the event schema or structure 