# Module Organization

## Current Structure

### Infrastructure Layer
```
game_bot/lib/game_bot/infrastructure/persistence/
├── error.ex                # Standardized error handling
├── repo/                  # Repository pattern implementation
│   ├── behaviour.ex       # Repository behavior definition
│   ├── postgres.ex        # PostgreSQL repository implementation
│   └── repo.ex           # High-level repository interface
└── event_store/          # Event sourcing implementation
    ├── behaviour.ex      # EventStore behavior definition
    ├── adapter.ex        # High-level EventStore interface
    ├── postgres.ex       # PostgreSQL EventStore implementation
    └── serializer.ex     # Event serialization
```

### Domain Layer
```
game_bot/lib/game_bot/domain/
├── aggregates/         # Domain aggregates
├── commands/          # Command definitions
├── events/           # Event definitions
├── game_modes/       # Game mode implementations
└── projections/     # Event projections
```

### Bot Layer
```
game_bot/lib/game_bot/bot/
├── commands/         # Command handlers
│   ├── game_commands.ex
│   ├── replay_commands.ex
│   └── team_commands.ex
└── dispatcher.ex    # Command routing
```

## Infrastructure Layer Design

### Error Handling
- Standardized error types across all infrastructure components
- Consistent error structure with context, type, message, and details
- Clear error categorization (validation, concurrency, system, etc.)

### Repository Pattern
- Clear behavior definition for repositories
- Standardized CRUD operations
- Transaction support
- Proper error handling and mapping
- Dependency injection support

### Event Store
- Behavior-driven design
- Serialization/deserialization of events
- Retry mechanisms for transient failures
- Stream size management
- Telemetry integration

## Implementation Details

### Error Module
```elixir
%Error{
  type: error_type(),      # Type of error
  context: module(),       # Module where error occurred
  message: String.t(),     # Human-readable message
  details: term()          # Error-specific details
}
```

### Repository Interface
```elixir
# Core operations
transaction((() -> result)) :: {:ok, result} | {:error, Error.t()}
insert(struct()) :: {:ok, struct()} | {:error, Error.t()}
update(struct()) :: {:ok, struct()} | {:error, Error.t()}
delete(struct()) :: {:ok, struct()} | {:error, Error.t()}
```

### Event Store Interface
```elixir
# Core operations
append_to_stream(stream_id(), version(), [event()], opts()) :: {:ok, [event()]} | {:error, Error.t()}
read_stream_forward(stream_id(), version(), count(), opts()) :: {:ok, [event()]} | {:error, Error.t()}
subscribe_to_stream(stream_id(), pid(), opts(), opts()) :: {:ok, pid()} | {:error, Error.t()}
```

## Key Features

1. **Clear Module Boundaries**
   - Separate interfaces from implementations
   - Consistent naming conventions
   - Proper dependency management

2. **Error Handling**
   - Standardized error types
   - Detailed error context
   - Proper error propagation

3. **Dependency Injection**
   - Configurable implementations
   - Easy testing support
   - Runtime flexibility

4. **Monitoring & Telemetry**
   - Event store monitoring
   - Performance tracking
   - Error logging

## Usage Guidelines

1. **Error Handling**
```elixir
# Always use the standardized Error struct
{:error, %Error{type: :validation, context: __MODULE__}}

# Provide detailed error information
{:error, %Error{
  type: :concurrency,
  context: __MODULE__,
  message: "Concurrent modification",
  details: %{expected: version, actual: current}
}}
```

2. **Repository Usage**
```elixir
# Use the high-level interface
alias GameBot.Infrastructure.Persistence.Repo

# Operations return tagged tuples
{:ok, record} = Repo.insert(struct)
{:ok, record} = Repo.get(User, id)
```

3. **Event Store Usage**
```elixir
alias GameBot.Infrastructure.Persistence.EventStore.Adapter

# Operations include validation and retries
{:ok, events} = Adapter.append_to_stream("game-123", version, events)
```

## Testing Strategy

1. **Unit Tests**
   - Test each implementation separately
   - Mock dependencies using behaviors
   - Test error conditions

2. **Integration Tests**
   - Test complete workflows
   - Use test implementations
   - Verify error handling

3. **Property Tests**
   - Test serialization
   - Verify error handling
   - Check concurrent operations

## Current Issues

1. **Circular Dependencies**
   - Event definitions reference command modules
   - Command handlers reference event modules
   - Game modes reference both commands and events

2. **Unclear Boundaries**
   - Event store implementation mixed with business logic
   - Serialization concerns spread across modules
   - Error handling not consistently applied

3. **Missing Abstractions**
   - No clear interface definitions
   - Mixed responsibilities in modules
   - Inconsistent error handling patterns

## Proposed Refactoring

### 1. Clear Layer Separation

```
game_bot/
├── infrastructure/   # Technical concerns
│   ├── persistence/
│   │   ├── event_store/
│   │   └── repo/
│   └── messaging/
├── domain/          # Business logic
│   ├── game/
│   ├── team/
│   └── shared/
└── bot/            # Discord integration
    ├── commands/
    └── handlers/
```

### 2. Module Responsibilities

#### Infrastructure
- Event persistence
- Database access
- Message handling
- Error handling
- Serialization

#### Domain
- Game rules
- Team management
- Event definitions
- Command processing
- State management

#### Bot
- Discord integration
- Command routing
- Response formatting
- User interaction

### 3. Interface Definitions

```elixir
# Clear behavior definitions
defmodule GameBot.Infrastructure.EventStore.Behaviour do
  @callback append_to_stream(String.t(), term(), list(), keyword()) ::
    {:ok, list()} | {:error, term()}
end

# Consistent error handling
defmodule GameBot.Infrastructure.Error do
  @type t :: %__MODULE__{
    type: error_type(),
    context: module(),
    message: String.t(),
    details: term()
  }
end
```

## Implementation Plan

1. **Phase 1: Infrastructure Cleanup**
   - [ ] Move all event store related code to infrastructure/persistence
   - [ ] Create clear interfaces for persistence layer
   - [ ] Standardize error handling

2. **Phase 2: Domain Reorganization**
   - [ ] Separate event definitions by context
   - [ ] Create proper aggregate roots
   - [ ] Define clear command/event flows

3. **Phase 3: Bot Layer Refinement**
   - [ ] Simplify command handlers
   - [ ] Improve error reporting
   - [ ] Add telemetry/logging

4. **Phase 4: Testing & Documentation**
   - [ ] Add integration tests
   - [ ] Document interfaces
   - [ ] Create usage examples

## Migration Strategy

1. Create new structure alongside existing code
2. Gradually move functionality to new locations
3. Update references one module at a time
4. Remove old code once migration is complete

## Success Criteria

- No circular dependencies
- Clear module boundaries
- Consistent error handling
- Improved testability
- Better maintainability 