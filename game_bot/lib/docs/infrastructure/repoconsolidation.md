# Repository Consolidation Plan

## Current State

The codebase currently has multiple overlapping repositories:
- `GameBot.Infrastructure.Repository` (Interface layer)
- `GameBot.Infrastructure.Persistence.Repo` (Base repository)
- `GameBot.Infrastructure.Persistence.Repo.Postgres` (Postgres implementation)
- `GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres` (Event store)

## Target Architecture

### 1. Domain Repository (`GameBot.Infrastructure.Repository`)

Primary repository for domain-specific operations and regular database interactions.

#### Responsibilities
- CRUD operations for domain entities
- Domain-specific queries
- Transaction management for domain operations
- Schema migrations for domain tables

#### When to Use
- Storing/retrieving game state
- Managing user data
- Handling regular application data
- Any non-event-sourced data

#### Implementation Guidelines
```elixir
defmodule GameBot.Infrastructure.Repository do
  use Ecto.Repo,
    otp_app: :game_bot,
    adapter: Ecto.Adapters.Postgres

  # Add domain-specific helper functions here
  # Keep these focused on domain operations
end
```

### 2. Event Store Repository (`GameBot.Infrastructure.EventStore`)

Dedicated repository for event sourcing and event-related operations.

#### Responsibilities
- Event stream management
- Event persistence
- Subscription handling
- Event versioning
- Optimistic concurrency control

#### When to Use
- Storing domain events
- Event sourcing operations
- When you need event streams
- For event subscriptions
- When you need event versioning

#### Implementation Guidelines
```elixir
defmodule GameBot.Infrastructure.EventStore do
  use Ecto.Repo,
    otp_app: :game_bot,
    adapter: Ecto.Adapters.Postgres,
    types: EventStore.PostgresTypes

  # Event store specific operations
  # Keep focused on event sourcing concerns
end
```

## Data Separation Guidelines

### Event Store Repository (Events/Commands)

The Event Store should contain immutable events representing "what happened" in the system:

#### Game Events
- Game lifecycle events (game starts, endings with results)
- Round lifecycle events (round starts, ends)
- Guess processing events (the atomic game unit)

#### User/Team Events
- Team registry events
- Team name changes
- User display name changes
- Player join/leave events

#### Administrative Events
- Game mode selection/changes
- Administrative actions (cancellations, interventions)
- Tournament or special event participation

#### System Events
- Error events (failed operations, system failures)
- Important system state changes

The Event Store follows the principle that events are facts that have happened and cannot be changed, only appended to.

### Domain Repository (Read Models/Projections)

The Domain Repository should contain derived data models and configuration:

#### Derived Data
- Replay data
- Team statistics
- User statistics
- Team/user rating data
- Leaderboards
- Achievement records
- Game session metadata

#### Configuration
- Guild-specific configuration options
- User preferences
- Word lists or game assets
- Rate limiting data

#### Audit & Admin
- Audit logs for administrative actions
- System health data

This separation enables efficient querying of current state while maintaining a complete historical record of events.

## Migration Steps

1. **Preparation Phase**
   - Audit all repository usage in the codebase
   - Identify which operations belong to domain vs event store
   - Document all custom implementations that need to be preserved

2. **Repository Consolidation**
   - Create new `GameBot.Infrastructure.Repository`
   - Create new `GameBot.Infrastructure.EventStore`
   - Migrate custom implementations to appropriate repository
   - Update configuration for both repositories

3. **Code Updates**
   - Update all repository references in the codebase
   - Migrate existing queries to new repositories
   - Update tests to use correct repository

4. **Database Updates**
   - Ensure proper schema separation between repositories
   - Migrate any necessary data
   - Update database configuration

## Best Practices

### Repository Separation
1. **Clear Boundaries**
   - Domain repository for application state
   - Event store for event sourcing
   - No cross-repository queries

2. **Schema Naming**
   - Domain tables: No prefix
   - Event store tables: `event_store_` prefix
   - Clear separation in migrations

3. **Configuration**
   - Separate database configurations
   - Different connection pools
   - Independent runtime management

### Code Organization

1. **Domain Repository**
   ```elixir
   lib/game_bot/infrastructure/
   ├── repository.ex              # Main domain repository
   ├── schemas/                   # Domain schemas
   └── queries/                   # Complex domain queries
   ```

2. **Event Store**
   ```elixir
   lib/game_bot/infrastructure/
   ├── event_store.ex            # Event store repository
   ├── events/                   # Event definitions
   └── subscriptions/           # Subscription management
   ```

## Testing Guidelines

1. **Repository Tests**
   - Test domain operations in isolation
   - Use sandbox mode appropriately
   - Clear separation between domain and event tests

2. **Integration Tests**
   - Test interaction between repositories
   - Verify event sourcing flows
   - Test subscription behavior

## Configuration Example

```elixir
# config/config.exs
config :game_bot, GameBot.Infrastructure.Repository,
  database: "game_bot_domain",
  username: "postgres",
  password: "csstarahid",
  hostname: "localhost"

config :game_bot, GameBot.Infrastructure.EventStore,
  database: "game_bot_events",
  username: "postgres",
  password: "csstarahid",
  hostname: "localhost"
```

## Common Patterns

### Domain Operations
```elixir
# Use domain repository for regular CRUD
GameBot.Infrastructure.Repository.insert(user)
GameBot.Infrastructure.Repository.update(game)
```

### Event Operations
```elixir
# Use event store for event sourcing
GameBot.Infrastructure.EventStore.append_to_stream("game-123", events)
GameBot.Infrastructure.EventStore.subscribe_to_stream("game-123", subscriber)
```

## Migration Checklist

- [ ] Create new repository modules
- [ ] Update configuration
- [ ] Migrate custom implementations
- [ ] Update all repository references
- [ ] Update tests
- [ ] Verify event sourcing functionality
- [ ] Test in staging environment
- [ ] Document new repository usage
- [ ] Train team on new structure

## Monitoring and Maintenance

1. **Metrics to Track**
   - Query performance for both repositories
   - Connection pool usage
   - Transaction rates
   - Event store throughput

2. **Maintenance Tasks**
   - Regular schema cleanup
   - Index optimization
   - Connection pool tuning
   - Event store pruning

## Future Considerations

1. **Scaling**
   - Separate databases for domain and events
   - Read replicas for event store
   - Caching strategies

2. **Features**
   - Event store snapshots
   - Projection optimization
   - Query optimization

3. **Monitoring**
   - Custom telemetry
   - Performance tracking
   - Error reporting 