# Event Store Documentation

## Overview
The GameBot event store implements event sourcing for game state management. It uses the Elixir EventStore library with a custom serialization system for game-specific events.

## Architecture

### Component Structure
The event store implementation follows a layered architecture for type safety, flexibility, and error handling:

1. **EventStore Layer** (`GameBot.Infrastructure.Persistence.EventStore`)
   - Implements EventStore behaviour through Elixir's EventStore library
   - Serves as the main entry point for the event store functionality
   - Delegates to the configured adapter

2. **Adapter Layer** 
   - **Adapter Module** (`GameBot.Infrastructure.Persistence.EventStore.Adapter`)
     - Provides a facade for all EventStore operations
     - Enables runtime configuration of the actual implementation
     - Adds unified error handling and validation
   - **Base Adapter** (`GameBot.Infrastructure.Persistence.EventStore.Adapter.Base`)
     - Provides common functionality for concrete adapter implementations
     - Implements retry mechanisms and telemetry integration
   - **PostgreSQL Adapter** (`GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres`)
     - Concrete implementation using PostgreSQL database
     - Handles optimistic concurrency control
     - Implements all adapter behaviour functions

3. **Serialization Layer**
   - **Behaviour Definition** (`GameBot.Infrastructure.Persistence.EventStore.Serialization.Behaviour`)
     - Defines the contract for serializers with versioning requirements
   - **JSON Serializer** (`GameBot.Infrastructure.Persistence.EventStore.Serialization.JsonSerializer`)
     - Concrete implementation of serialization using JSON format
     - Handles complex types (DateTime, MapSet, etc.)
     - Implements version tracking
   - **Serializer Facade** (`GameBot.Infrastructure.Persistence.EventStore.Serializer`)
     - Higher-level wrapper providing simplified serialization interface
     - Adds basic validation and test support
     - Acts as an adapter/facade over the more complex serialization system

4. **Event Translation Layer** 
   - **Event Translator** (`GameBot.Infrastructure.Persistence.EventStore.Serialization.EventTranslator`)
     - Manages event version mapping and migrations
     - Implements a directed graph approach for finding migration paths
     - Provides registration of event types and migration functions

5. **Transaction Management**
   - Provides transaction capabilities with guild_id context tracking
   - Handles proper logging and error recovery
   - Implements automatic retries for recoverable errors

### Type-Safe Operations
All event store operations provide:
- Strong type safety
- Detailed error reporting
- Validation at appropriate layers
- Consistent error transformation

### Concurrency Control
The event store uses optimistic concurrency control:

1. **Expected Version Options**
   - `:any` - Append regardless of version
   - `:no_stream` - Stream must not exist
   - `:stream_exists` - Stream must exist
   - `integer()` - Exact version expected

2. **Version Conflicts**
   - Detected when actual version differs from expected
   - Results in `:wrong_expected_version` error
   - Caller must handle conflicts (retry or error)

### Event Versioning
The event store supports comprehensive versioning:

1. **Event Version Tracking**
   - Each event includes explicit version number
   - Version is preserved during serialization
   - Event Registry maintains version mapping

2. **Version Migration**
   - Event Translator supports migration between versions
   - Uses a directed graph for finding migration paths
   - Applies migration functions in sequence

3. **Compatibility with Domain Events**
   - Fully compatible with `@event_type` and `@event_version` attributes
   - Registry maintains mapping between types, versions, and modules
   - Supports retrieving events by specific version

### Error Handling
All operations return tagged tuples with categorized errors:

```elixir
{:ok, result} | {:error, error_type}

error_type ::
  # Validation Errors
  :invalid_stream_id |
  :invalid_start_version |
  :invalid_batch_size |
  
  # Concurrency Errors
  :wrong_expected_version |
  :stream_not_found |
  
  # Infrastructure Errors
  :connection_error |
  :serialization_failed |
  :deserialization_failed |
  
  # Domain Errors
  :invalid_event_type |
  :invalid_event_data |
  term()
```

### Recovery Mechanism
The event store supports full state recovery:

1. **Session Recovery**
   - Events replayed in order
   - State validated after recovery
   - Automatic retry for transient failures

2. **Error Handling**
   - Validates event sequence
   - Ensures causal consistency
   - Handles missing or corrupt events

### Performance Guidelines

1. **Batch Operations**
   - Recommended batch size: 100-1000 events
   - Use streaming for large reads
   - Batch writes when possible

2. **Stream Limits**
   - Maximum stream size: 10,000 events
   - Consider archiving old streams
   - Use snapshots for large streams

## Current Event Schema (v1)

All events are currently at version 1. Each event includes these base fields:
- `game_id`: String
- `guild_id`: String
- `mode`: atom (:two_player, :knockout, :race)
- `round_number`: positive integer
- `timestamp`: DateTime
- `metadata`: map

### Event Types

| Event Type | Version | Purpose | Key Fields |
|------------|---------|---------|------------|
| game_started | 1 | New game initialization | teams, team_ids, player_ids, roles, config |
| round_started | 1 | Round beginning | team_states |
| guess_processed | 1 | Guess attempt result | team_id, player info, words, success status |
| guess_abandoned | 1 | Failed guess attempt | team_id, player info, reason |
| team_eliminated | 1 | Team removal | team_id, reason, final state, stats |
| game_completed | 1 | Game conclusion | winners, final scores, duration |
| knockout_round_completed | 1 | Knockout round end | eliminated/advancing teams |
| race_mode_time_expired | 1 | Race mode timeout | final matches, duration |

## Compatibility with Event System

The event store architecture is fully compatible with the domain events system:

1. **Event Structure Compatibility**
   - Both systems use the same base fields structure
   - Serialization preserves all required fields
   - Metadata handling is consistent across systems

2. **Versioning Compatibility**
   - Event store recognizes and preserves event versions
   - JSON serializer includes version in stored format
   - Version migrations can be registered for evolving events

3. **Serialization Protocol**
   - Event serializer respects the EventSerializer protocol
   - Complex types (DateTime, MapSet) are properly handled
   - Full roundtrip serialization is supported

4. **Broadcasting Integration**
   - Event store operations can trigger broadcasts
   - Subscription system works with stored events
   - Cached events maintain proper versioning

## Development Guidelines

### Event Updates
1. Add new event struct in `GameBot.Domain.Events`
2. Implement required callbacks (`event_type()`, `event_version()`, etc.)
3. Register any needed version migrations with EventTranslator
4. Update store schema in same commit if necessary

### Using the Event Store
1. Always use the adapter layer (`GameBot.Infrastructure.Persistence.EventStore.Adapter`)
2. Never use EventStore functions directly
3. Handle all possible error cases
4. Use proper type specifications

### Schema Changes
- During development, store can be dropped/recreated
- No migration scripts needed pre-production
- Document schema changes in commit messages

### Version Control
- All events must be versioned
- Version format: v1, v2, etc.
- Store schema must match latest event version

### Not Required (Pre-Production)
- Migration paths for old data
- Multi-version support in production
- Rollback procedures
- Historical data preservation 