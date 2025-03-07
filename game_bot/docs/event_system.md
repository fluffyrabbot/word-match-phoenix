# Event System Documentation

## Overview

The event system in GameBot follows event sourcing principles and is designed to maintain a complete audit trail of all game-related activities. This document outlines the architecture, best practices, and implementation details.

## Core Principles

### Event Sourcing
- All state changes are captured as events
- Events are immutable and versioned
- State can be reconstructed by replaying events
- Events contain all necessary data for reconstruction

### Event Structure
- Events follow a consistent structure with required fields
- All events include metadata for tracking and debugging
- Events are validated before storage
- Events are serializable for persistence

### Guild Segregation
- All events are scoped to a Discord guild
- Events include guild_id for proper data isolation
- Queries and projections respect guild boundaries
- Cross-guild operations are explicitly marked

## Event Types

### Game Events
- `GameCreated`: Initial game setup
- `GameStarted`: Game begins
- `GameCompleted`: Game ends with results
- `RoundStarted`: New round begins
- `GuessProcessed`: Player guesses processed
- `GuessAbandoned`: Round abandoned
- `TeamEliminated`: Team eliminated from game

### Team Events
- `TeamCreated`: New team formation
- `TeamUpdated`: Team information changes
- `TeamMemberAdded`: Player joins team
- `TeamMemberRemoved`: Player leaves team
- `TeamInvitationCreated`: Team invitation sent
- `TeamInvitationAccepted`: Invitation accepted
- `TeamInvitationDeclined`: Invitation declined

## Event Structure

### Required Fields
```elixir
@type t :: %{
  id: String.t(),           # Unique event identifier
  type: String.t(),         # Event type identifier
  version: pos_integer(),   # Schema version
  timestamp: DateTime.t(),  # When the event occurred
  metadata: Metadata.t(),   # Tracking and context data
  data: map()              # Event-specific data
}
```

### Metadata Fields
```elixir
@type metadata :: %{
  guild_id: String.t(),           # Discord guild ID
  source_id: String.t(),          # Source identifier
  correlation_id: String.t(),     # Event chain tracking
  causation_id: String.t(),       # Causal event ID
  actor_id: String.t(),           # User who triggered event
  client_version: String.t(),     # Client version
  server_version: String.t(),     # Server version
  user_agent: String.t(),         # Client info
  ip_address: String.t()          # Security tracking
}
```

## Best Practices

### Event Creation
1. Always use the appropriate event constructor
2. Include all required fields
3. Validate events before storage
4. Use proper DateTime handling
5. Include meaningful metadata

### Event Storage
1. Version all event schemas
2. Maintain backward compatibility
3. Use proper serialization
4. Index frequently queried fields
5. Implement proper error handling

### Event Processing
1. Handle events idempotently
2. Validate event order
3. Maintain event chains
4. Track causation
5. Handle failures gracefully

### Projections
1. Build read models from events
2. Handle event ordering
3. Maintain consistency
4. Optimize for queries
5. Handle failures

## Implementation Guidelines

### Event Definition
```elixir
defmodule GameBot.Domain.Events.GameEvents.GameStarted do
  @behaviour GameBot.Domain.Events.GameEvents

  @type t :: %__MODULE__{
    game_id: String.t(),
    guild_id: String.t(),
    mode: atom(),
    # ... other fields
  }

  def validate(%__MODULE__{} = event) do
    # Validation logic
  end

  def to_map(%__MODULE__{} = event) do
    # Serialization logic
  end

  def from_map(data) do
    # Deserialization logic
  end
end
```

### Event Processing
```elixir
def handle_event(%GameStarted{} = event) do
  with :ok <- validate_event(event),
       {:ok, serialized} <- serialize(event) do
    store_event(serialized)
  end
end
```

### Projection Building
```elixir
def handle_event(%GameStarted{} = event, state) do
  updated_state = %{state |
    game_id: event.game_id,
    status: :active,
    started_at: event.timestamp
  }
  {:ok, updated_state}
end
```

## Error Handling

### Validation Errors
- Return {:error, reason} tuples
- Provide clear error messages
- Log validation failures
- Handle edge cases

### Processing Errors
- Implement retry mechanisms
- Log processing failures
- Maintain event order
- Handle partial failures

### Storage Errors
- Implement proper error handling
- Maintain data consistency
- Handle network issues
- Implement proper recovery

## Testing Guidelines

### Event Tests
1. Test event creation
2. Test validation
3. Test serialization
4. Test deserialization
5. Test edge cases

### Processing Tests
1. Test event handling
2. Test error cases
3. Test ordering
4. Test consistency
5. Test recovery

### Projection Tests
1. Test state building
2. Test consistency
3. Test performance
4. Test error handling
5. Test recovery

## Migration Guidelines

### Schema Changes
1. Version all changes
2. Maintain backward compatibility
3. Document changes
4. Test migrations
5. Handle failures

### Data Migration
1. Plan migrations
2. Test migrations
3. Handle failures
4. Verify results
5. Document process

## Performance Considerations

### Storage
1. Index frequently queried fields
2. Optimize storage format
3. Implement caching
4. Handle large datasets
5. Monitor performance

### Processing
1. Optimize event handling
2. Implement batching
3. Handle backpressure
4. Monitor latency
5. Scale appropriately

### Projections
1. Optimize read models
2. Implement caching
3. Handle large datasets
4. Monitor performance
5. Scale appropriately

## Security Considerations

### Data Protection
1. Validate all inputs
2. Sanitize outputs
3. Handle sensitive data
4. Implement access control
5. Monitor access

### Event Integrity
1. Validate event chains
2. Handle tampering
3. Implement signatures
4. Monitor integrity
5. Handle breaches

## Monitoring and Maintenance

### Health Checks
1. Monitor event processing
2. Check storage health
3. Verify projections
4. Monitor performance
5. Handle alerts

### Maintenance
1. Regular backups
2. Cleanup old data
3. Optimize storage
4. Update indexes
5. Handle failures

## Troubleshooting

### Common Issues
1. Event validation failures
2. Processing errors
3. Storage issues
4. Performance problems
5. Consistency issues

### Resolution Steps
1. Check event data
2. Verify processing
3. Check storage
4. Monitor performance
5. Verify consistency 