# Event Store Documentation

## Overview
The GameBot event store implements event sourcing for game state management. It uses the Elixir EventStore library with a custom serializer for game-specific events.

## Architecture

### Type-Safe Operations
The event store implementation follows a layered approach for type safety and error handling:

1. **Base Layer** (`GameBot.Infrastructure.Persistence.EventStore.Postgres`)
   - Implements EventStore behaviour through macro
   - Provides type-safe wrapper functions with `safe_` prefix:
     - `safe_stream_version/1`
     - `safe_append_to_stream/4`
     - `safe_read_stream_forward/3`
   - Handles input validation and detailed error reporting

2. **Adapter Layer** (`GameBot.Infrastructure.Persistence.EventStore.Adapter`)
   - Uses safe functions from base layer
   - Adds serialization/deserialization
   - Provides consistent error transformation
   - Main interface for other modules

3. **Usage Layer** (Sessions, Commands, etc.)
   - Always accesses event store through adapter
   - Benefits from type safety and error handling

### Concurrency Control
The event store uses optimistic concurrency control:

1. **Expected Version**
   - `:any` - Append regardless of version
   - `:no_stream` - Stream must not exist
   - `:stream_exists` - Stream must exist
   - `integer()` - Exact version expected

2. **Version Conflicts**
   - Detected when actual version differs from expected
   - Results in `:wrong_expected_version` error
   - Caller must handle conflicts (retry or error)

3. **Conflict Resolution**
   - Read current version
   - Merge changes if possible
   - Retry with new version
   - Or fail with conflict error

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
   - `GameBot.GameSessions.Recovery` handles reconstruction
   - Events replayed in order
   - State validated after recovery
   - Automatic retry for transient failures

2. **Recovery Process**
   ```elixir
   # Example recovery flow
   {:ok, events} = EventStore.read_stream_forward(game_id)
   {:ok, state} = Recovery.rebuild_state(events)
   {:ok, _pid} = GameSessions.restart_session(game_id, state)
   ```

3. **Error Handling**
   - Validates event sequence
   - Ensures causal consistency
   - Handles missing or corrupt events
   - Reports unrecoverable states

### Performance Guidelines

1. **Batch Operations**
   - Recommended batch size: 100-1000 events
   - Use streaming for large reads
   - Batch writes when possible

2. **Stream Limits**
   - Maximum stream size: 10,000 events
   - Consider archiving old streams
   - Use snapshots for large streams

3. **Caching Strategy**
   - Cache frequently accessed streams
   - Cache stream versions for concurrency
   - Invalidate on version changes

4. **Subscription Usage**
   - Use for real-time updates
   - Prefer catch-up subscriptions
   - Handle subscription restarts

## Current Event Schema (v1)

All events are currently at version 1. Each event includes these base fields:
- `game_id`: String
- `mode`: atom
- `round_number`: positive integer
- `timestamp`: DateTime
- `metadata`: optional map

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
| longform_day_ended | 1 | Longform day end | day number, standings |

## Implementation Details

### Serialization
- Events are serialized using `GameBot.Infrastructure.EventStore.Serializer`
- Each event implements the `GameBot.Domain.Events.GameEvents` behaviour
- Events are stored as JSON with type and version metadata

### Configuration
- Custom serializer configured in `GameBot.Infrastructure.EventStore.Config`
- Schema waiting enabled in test environment
- Default EventStore supervision tree used

## Development Guidelines

### Event Updates
1. Add new event struct in `GameBot.Domain.Events.GameEvents`
2. Implement required callbacks:
   - `event_type()`
   - `event_version()`
   - `to_map(event)`
   - `from_map(data)`
   - `validate(event)`
3. Add event type to serializer's `event_version/1` function
4. Update store schema in same commit

### Using the Event Store
1. Always use the adapter layer (`GameBot.Infrastructure.Persistence.EventStore.Adapter`)
2. Never use EventStore functions directly
3. Handle all possible error cases
4. Use proper type specifications
5. Document error handling in function docs

### Schema Changes
- Store can be dropped/recreated during development
- No migration scripts needed pre-production
- No backwards compatibility required
- Tests only needed for current version

### Version Control
- All events must be versioned
- Version format: v1, v2, etc.
- Store schema must match latest event version
- Document schema changes in commit messages

### Not Required (Pre-Production)
- Migration paths
- Multi-version support
- Rollback procedures
- Historical data preservation 