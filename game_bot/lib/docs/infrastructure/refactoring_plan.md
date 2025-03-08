# Refactoring Priority and Plans

## Progress Update

### ✅ Completed
1. Created new directory structure for the infrastructure layer.
2. Implemented standardized error handling.
3. Created behavior definitions for repositories and the event store.
4. Implemented PostgreSQL repository with error handling.
5. Implemented EventStore adapter with retries and validation.
6. Added proper serialization with error handling.
7. Added telemetry integration for monitoring.
8. Developed comprehensive unit tests for:
   - Event store components (Serializer, Adapter, Postgres implementation)
   - Repository operations (CRUD, transactions, concurrency errors)
9. Implemented a mock EventStore for controlled testing (simulated failures, delays, subscriptions).
10. Added full integration tests:
    - Testing interactions between the event store (via the adapter) and the repository.
    - Validating transaction boundaries, concurrent modifications, and subscription flows.
11. Fixed EventStore macro integration issues:
    - Proper implementation of behavior callbacks
    - Correct use of @impl annotations
    - Clear separation between macro-generated and custom functions

### 🚧 In Progress
1. Infrastructure Layer Cleanup
   - [x] Moved event store code to `infrastructure/persistence`
   - [x] Created clear interfaces for components
   - [x] Standardized error handling across modules
   - [x] Fixed EventStore macro integration
   - [ ] Further test coverage improvements (e.g., additional edge case tests)
   - [ ] Removal of old event store implementations

## Next Priorities

### 1. Immediate (Current Sprint)
1. **Testing Infrastructure**
   - [x] Create test helpers for repository testing (e.g., `GameBot.Test.RepositoryCase`)
   - [x] Add unit tests for error handling and serialization (including property-based tests)
   - [x] Add integration tests for the PostgreSQL repository and combined flows
   - [x] Add macro integration tests
   - [ ] Expand test coverage to include additional edge cases and performance scenarios

2. **Migration Tasks**
   - [ ] Update existing domain and bot code to utilize the new repository and event store interfaces
   - [ ] Remove deprecated modules:
     - `game_bot/lib/game_bot/infrastructure/event_store.ex`
     - `game_bot/lib/game_bot/infrastructure/event_store_adapter.ex`
     - `game_bot/lib/game_bot/infrastructure/event_store/serializer.ex`
     - `game_bot/lib/game_bot/infrastructure/repo.ex`

### 2. Next Sprint
1. **Domain Layer Reorganization**
   - [ ] Separate event definitions by context
   - [ ] Create proper aggregate roots
   - [ ] Define clear command/event flows and remove circular dependencies

2. **Documentation**
   - [ ] Add detailed API documentation and usage examples for new interfaces
   - [ ] Document testing patterns and best practices
   - [ ] Add macro integration guidelines for each EventStore implementation

### 3. Future Work
1. **Bot Layer Refinement**
   - [ ] Simplify command handlers
   - [ ] Improve error reporting and logging
   - [ ] Add telemetry/logging for end-to-end monitoring

## Implementation Guidelines

### 1. EventStore Macro Integration
```elixir
defmodule MyEventStore do
  use EventStore, otp_app: :game_bot

  # DO - Add custom wrapper functions
  def safe_operation(...) do
    # Custom validation and error handling
  end

  # DO - Override callbacks with @impl true when adding functionality
  @impl true
  def init(config) do
    # Add custom initialization
    {:ok, config}
  end

  # DON'T - Override macro-generated functions
  # def config do  # This would conflict
  #   ...
  # end
end
```

### 2. Testing Strategy
```elixir
# Base test case with proper setup
defmodule GameBot.Test.EventStoreCase do
  use ExUnit.CaseTemplate

  setup do
    config = Application.get_env(:game_bot, GameBot.EventStore)
    {:ok, conn} = EventStore.Config.parse(config)
    :ok = EventStore.Storage.Initializer.reset!(conn, [])
    :ok
  end
end

# Integration tests
describe "stream operations" do
  test "handles concurrent modifications" do
    # Test implementation
  end
end
```

### 3. Gradual Migration
```elixir
# Update existing code to use new interfaces
alias GameBot.Infrastructure.Persistence.{Repo, EventStore.Adapter}

def handle_command(command) do
  Repo.transaction(fn ->
    # Use new interfaces for event store and repository operations
  end)
end
```

### 4. Cleanup
- Remove old implementations only after successful migration and test verification
- Verify no references to deprecated modules remain
- Run full test suite after each removal stage

## Success Metrics

- [ ] All tests passing (unit, integration, property, and macro integration tests)
- [ ] No remaining references to old implementations
- [ ] Improved error handling coverage (detailed errors with context)
- [ ] Clear separation of module boundaries (domain, infrastructure, bot)
- [ ] Up-to-date, complete documentation with usage examples
- [ ] Proper macro integration across all EventStore implementations

## Risk Mitigation

1. **Testing**
   - Add tests before removing old code
   - Use property testing for serialization scenarios
   - Include integration tests for critical workflows
   - Add specific tests for macro integration

2. **Migration**
   - Update modules one at a time with comprehensive test verification
   - Keep old implementations until new system is fully validated
   - Follow macro integration guidelines strictly

3. **Monitoring**
   - Add telemetry for key operations
   - Monitor error rates during migration
   - Track performance metrics to verify improvements

## Implementation Notes

### EventStore Integration
- Follow proper macro integration patterns
- Use wrapper functions for custom functionality
- Maintain clear separation between macro and custom code
- Document all macro-related decisions

### Testing Requirements
- All EventStore implementations must pass macro integration tests
- Integration tests must verify proper event handling
- Performance tests must validate scalability
- Error handling must be comprehensive

### Documentation Standards
- Clear API documentation for all public functions
- Usage examples for common scenarios
- Warning sections for potential pitfalls
- Macro integration guidelines for each implementation

## Next Steps
1. Complete remaining macro integration tests
2. Update documentation for all EventStore implementations
3. Add performance benchmarks
4. Remove deprecated code
5. Verify full test coverage 