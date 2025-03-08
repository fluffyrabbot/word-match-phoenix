# Event System Architecture

## Overview

GameBot implements an event-sourcing architecture where all state changes are captured as immutable events. These events are the source of truth for the application and are used to reconstruct the current state when needed. The event system is central to the game's design, enabling features like game replay, audit trails, and distributed processing.

## Core Concepts

### Events as Source of Truth

In the event-sourcing pattern, events are:
- **Immutable**: Once created, they never change
- **Sequential**: They have a natural order
- **Complete**: They contain all data needed to understand what happened
- **Identifiable**: Each event has a unique identifier
- **Timestamped**: Each event occurs at a specific point in time

### Event Flow

Events flow through the system in the following pattern:

1. **Command** triggers an operation (e.g., `JoinTeam`)
2. **Command Handler** validates and processes the command
3. **Events** are generated as a result (e.g., `TeamJoined`)
4. **Event Store** persists events to the database
5. **Projections** update read models based on events
6. **Reactors** trigger side effects based on events

## Architecture Components

### Command Layer

Commands represent user intentions and contain:
- **Command Data**: The data needed to execute the command
- **Validation Rules**: Ensuring the command is valid before processing
- **Authorization Checks**: Verifying the user has permission to execute the command

```elixir
defmodule GameBot.Domain.Commands.TeamCommands.JoinTeam do
  defstruct [:team_id, :player_id, :guild_id]
  
  def execute(%__MODULE__{} = command) do
    # Validation and processing logic
    # Returns events if successful
  end
end
```

### Event Layer

Events represent state changes that have occurred:

```elixir
defmodule GameBot.Domain.Events.GameEvents.TeamJoined do
  defstruct [:team_id, :player_id, :guild_id, :joined_at, :metadata]
  
  # EventSerializer protocol implementation
  # Validation and other helper functions
end
```

#### Event Structure

All events contain:
- **Base Fields**: Common to all events (game_id, guild_id, mode, timestamp, metadata)
- **Specific Fields**: Unique to each event type
- **Version Information**: For supporting schema evolution

### Event Store

The event store is responsible for:
- **Persisting Events**: Storing events durably
- **Retrieving Events**: Fetching events by stream or timestamp
- **Ensuring Consistency**: Managing optimistic concurrency control

The event store leverages PostgreSQL with a schema designed for append-only operation:

```
event_store.streams - Stores stream metadata
event_store.events - Stores the actual events
event_store.subscriptions - Manages event subscriptions
```

### Projections

Projections build read models from events:
- **Game Projection**: Current state of games
- **Team Projection**: Current state of teams
- **Stats Projection**: Player and game statistics

```elixir
defmodule GameBot.Domain.Projections.GameProjection do
  def handle_event(%GameStarted{} = event) do
    # Update game state based on start event
  end
  
  def handle_event(%GameCompleted{} = event) do
    # Update game state based on completion event
  end
end
```

### Reactors

Reactors trigger side effects when events occur:
- **Notifications**: Sending messages to users
- **External Systems**: Updating external services
- **Cascading Actions**: Triggering additional commands

```elixir
defmodule GameBot.Domain.Reactors.NotificationReactor do
  def handle_event(%GameCompleted{} = event) do
    # Send game completion notifications
  end
end
```

## Event Serialization

Events are serialized for storage and deserialized when loading:

- **Serialization**: Converting event structs to maps with string keys
- **Deserialization**: Converting maps back to event structs
- **Type Handling**: Managing Elixir-specific types (atoms, DateTime, etc.)

See [Event Serializer Documentation](event_serializer.md) for details on the serialization system.

## Event Metadata

Every event includes metadata to provide context:

```elixir
%{
  guild_id: "123456789",
  source_id: "msg-123", # Message or interaction that triggered this
  correlation_id: "abcdef", # For tracking related events
  causation_id: "event-456", # Which event caused this one
  actor_id: "user-789" # Who triggered this event
}
```

This metadata enables:
- **Tracing**: Following chains of events
- **Auditing**: Understanding who did what and when
- **Debugging**: Diagnosing issues in the system

## Event Testing

The event system includes specialized testing support:

- **TestEvents Module**: Provides standardized test events
- **EventSerializerTest**: Ensures serialization works correctly
- **EventStoreMock**: For testing without a database

## Best Practices

### Event Design

1. **Make events meaningful**: Each event should represent a significant state change
2. **Include all context**: Events should contain all relevant data
3. **Be explicit about intent**: Name events to clearly indicate what happened
4. **Favor small, focused events**: One event per logical change
5. **Design for future evolution**: Consider how events might change over time

### Event Processing

1. **Process events idempotently**: Handling the same event twice should be safe
2. **Keep event handlers simple**: Focus on a single responsibility
3. **Avoid side effects in projections**: Use reactors for side effects
4. **Test event roundtrips**: Ensure events serialize and deserialize correctly
5. **Monitor event processing**: Track failures and latency

## Future Enhancements

1. **Event Versioning**: More sophisticated schema evolution
2. **Event Subscriptions**: Improved subscription management
3. **Event Replay**: Better tools for replaying specific event streams
4. **Performance Optimization**: Faster event processing
5. **Analytics Integration**: Using events for game analytics

## Troubleshooting

### Common Issues

1. **Missing Events**: Check event persistence and retrieval
2. **Serialization Errors**: Verify protocol implementations
3. **Projection Inconsistencies**: Events may be processed out of order
4. **Performance Problems**: Look for slow event handlers

### Debugging

1. **Inspect Event Streams**: Look at raw events in the database
2. **Check Event Metadata**: Use correlation IDs to trace related events
3. **Verify Command Validation**: Ensure commands are validated properly
4. **Test Projection Handlers**: Verify they correctly update state 