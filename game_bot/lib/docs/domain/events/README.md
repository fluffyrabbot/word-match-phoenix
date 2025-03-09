# GameBot Event System Documentation

## Overview

The GameBot event system implements a robust event-sourcing architecture that serves as the foundation for all game state management. Events are immutable facts that represent state changes in the system and provide a complete audit trail of all actions taken.

## Architecture Components

### Core Event Infrastructure

- **BaseEvent** - Base module that defines common structure and behaviors for all events
- **EventBuilder/Builder** - Macros for creating event modules with consistent structure
- **Types** - Shared type definitions used across the event system
- **Metadata** - Tracks contextual information including correlation IDs for event chains
- **Registry** - Runtime registration of event types with version support
- **Validator** - Protocol for validating event structure and business rules
- **Serializer** - Protocol for converting events to/from persistent formats
- **Pipeline** - Processes events through validation, enrichment, persistence, and broadcasting

### Event Processing

- **Handler** - Behavior for creating event handlers with standardized error handling
- **Broadcaster** - Enhanced event broadcasting with dual-topic patterns
- **SubscriptionManager** - Manages subscriptions to event topics
- **Cache** - ETS-based caching for recently processed events

### Monitoring & Performance

- **Telemetry** - Instrumentation for event processing metrics

## Event Structure

All events share a common structure with these base fields:

```elixir
@base_fields [
  :game_id,     # Unique identifier for the game
  :guild_id,    # Discord guild ID  
  :mode,        # Game mode (:two_player, :knockout, :race)
  :round_number, # Current round number
  :timestamp,   # When the event occurred
  :metadata     # Contextual information
]
```

Event-specific fields are added to these base fields to represent the specific state change.

## Event Versioning

Events in the system are versioned using explicit version numbers:

```elixir
@event_type "game_started"
@event_version 1
```

The Registry maintains a mapping between event types, versions, and their module implementations, allowing for:

- Running multiple versions of the same event type simultaneously
- Upgrading events through versioning
- Lookup of the appropriate module for a given event type and version

## Event Flow

1. **Creation** - Events are created with specific attributes and metadata
2. **Validation** - Event structure and business rules are validated
3. **Enrichment** - Additional metadata and context are added
4. **Persistence** - Events are stored in the event store
5. **Caching** - Recent events are cached for quick access
6. **Broadcasting** - Events are published to interested subscribers

## Event Types

The system includes several categories of events:

- **Game Events** - Core game mechanics (GameStarted, RoundCompleted, etc.)
- **User Events** - User registration and profile changes
- **Team Events** - Team creation and updates
- **Guess Events** - Player guesses and match results
- **Error Events** - Various error conditions that can occur

## Subscription Patterns

The system supports multiple subscription patterns:

- **Game-specific** - Subscribe to all events for a particular game
- **Event-type** - Subscribe to a specific type of event across all games
- **Custom topics** - Create custom subscription topics as needed

## Serialization

Events are serialized into a storage-friendly format with these rules:

1. DateTime fields are converted to ISO8601 strings
2. Atom fields are converted to strings 
3. Complex data structures are appropriately transformed
4. Field names are consistent as strings

## Best Practices

1. **Events Are Facts** - Events represent something that happened and are immutable
2. **Self-Contained** - Events should contain all context needed to understand what happened
3. **Validation** - Ensure events meet structural and business rule requirements
4. **Versioning** - Maintain consistent versioning for schema evolution
5. **Correlation** - Use metadata to track event chains and causation

## Future Considerations

1. **Schema Registry** - Consider implementing a formal schema registry
2. **Backward Compatibility** - Define policies for maintaining backward compatibility
3. **Event Upcasting** - Implement formal event version upgrading systems
4. **Advanced Projections** - Build more sophisticated event projections

## Usage Examples

### Creating an Event

```elixir
{:ok, event} = GameBot.Domain.Events.GameEvents.GameStarted.create(
  "game-123",
  "guild-456",
  :two_player,
  teams,
  team_ids,
  player_ids,
  roles,
  config,
  metadata
)
```

### Processing an Event

```elixir
GameBot.Domain.Events.Pipeline.process_event(event)
```

### Subscribing to Events

```elixir
# Subscribe to all events for a specific game
GameBot.Domain.Events.SubscriptionManager.subscribe_to_game("game-123")

# Subscribe to all events of a specific type
GameBot.Domain.Events.SubscriptionManager.subscribe_to_event_type("game_completed")
```

### Creating an Event Handler

```elixir
defmodule MyGameCompletedHandler do
  use GameBot.Domain.Events.Handler, 
    interests: ["event_type:game_completed"]
    
  @impl true
  def handle_event(event) do
    # Process the event
    :ok
  end
end
```

## Future Development

See the individual documentation files for roadmaps on future enhancements to each component of the event system.

## Contributing

When adding new event types or modifying existing ones:

1. Implement the `EventSerializer` protocol for any new event type
2. Update tests to cover serialization and deserialization
3. Consider backward compatibility with existing stored events
4. Document any changes to the event schema or structure 