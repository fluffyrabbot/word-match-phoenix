# Refactoring Priority and Plans

## Progress Update

### ✅ Completed
1. Created new directory structure for infrastructure layer
2. Implemented standardized error handling
3. Created behavior definitions for repositories and event store
4. Implemented PostgreSQL repository with error handling
5. Implemented EventStore adapter with retries and validation
6. Added proper serialization with error handling
7. Added telemetry integration for monitoring

### 🚧 In Progress
1. Infrastructure Layer Cleanup
   - [x] Move event store code to infrastructure/persistence
   - [x] Create clear interfaces
   - [x] Standardize error handling
   - [ ] Add tests for new implementations
   - [ ] Remove old event store implementations

## Next Priorities

### 1. Immediate (Current Sprint)
1. **Testing Infrastructure**
   - [ ] Create test helpers for repository testing
   - [ ] Add unit tests for error handling
   - [ ] Add integration tests for PostgreSQL implementations
   - [ ] Add property tests for serialization

2. **Migration Tasks**
   - [ ] Update existing code to use new repository interface
   - [ ] Update existing code to use new event store interface
   - [ ] Remove deprecated modules:
     - `game_bot/lib/game_bot/infrastructure/event_store.ex`
     - `game_bot/lib/game_bot/infrastructure/event_store_adapter.ex`
     - `game_bot/lib/game_bot/infrastructure/event_store/serializer.ex`
     - `game_bot/lib/game_bot/infrastructure/repo.ex`

### 2. Next Sprint
1. **Domain Layer Reorganization**
   - [ ] Separate event definitions by context
   - [ ] Create proper aggregate roots
   - [ ] Define clear command/event flows
   - [ ] Remove circular dependencies

2. **Documentation**
   - [ ] Add detailed API documentation
   - [ ] Create usage examples
   - [ ] Document testing patterns

### 3. Future Work
1. **Bot Layer Refinement**
   - [ ] Simplify command handlers
   - [ ] Improve error reporting
   - [ ] Add telemetry/logging

## Implementation Approach

1. **Testing First**
   ```elixir
   # Create test helpers
   defmodule GameBot.Test.RepositoryCase do
     # Common test setup and helpers
   end

   # Add comprehensive tests
   describe "repository operations" do
     test "handles concurrent modifications"
     test "properly validates input"
     test "manages transactions"
   end
   ```

2. **Gradual Migration**
   ```elixir
   # Update existing code to use new interfaces
   alias GameBot.Infrastructure.Persistence.{Repo, EventStore.Adapter}

   def handle_command(command) do
     Repo.transaction(fn ->
       # Use new interfaces
     end)
   end
   ```

3. **Cleanup**
   - Remove old implementations only after all dependencies are updated
   - Verify no references to old modules exist
   - Run full test suite after each removal

## Success Metrics

- [ ] All tests passing
- [ ] No references to old implementations
- [ ] Improved error handling coverage
- [ ] Clear module boundaries
- [ ] Documentation up to date

## Risk Mitigation

1. **Testing**
   - Add tests before removing old code
   - Use property testing for serialization
   - Add integration tests for workflows

2. **Migration**
   - Update one module at a time
   - Keep old implementations until fully migrated
   - Verify each step with tests

3. **Monitoring**
   - Add telemetry for key operations
   - Monitor error rates during migration
   - Track performance metrics 