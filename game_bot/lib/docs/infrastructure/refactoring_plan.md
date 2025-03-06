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

### 🚧 In Progress
1. Infrastructure Layer Cleanup
   - [x] Moved event store code to `infrastructure/persistence`
   - [x] Created clear interfaces for components
   - [x] Standardized error handling across modules
   - [ ] Further test coverage improvements (e.g., additional edge case tests)
   - [ ] Removal of old event store implementations

## Next Priorities

### 1. Immediate (Current Sprint)
1. **Testing Infrastructure**
   - [x] Create test helpers for repository testing (e.g., `GameBot.Test.RepositoryCase`)
   - [x] Add unit tests for error handling and serialization (including property-based tests)
   - [x] Add integration tests for the PostgreSQL repository and combined flows between the event store and repository
   - [ ] Expand test coverage to include additional edge cases and performance scenarios, if needed

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
   - [ ] Document testing patterns and best practices (refer to the [Infrastructure Testing Guide](../infrastructure/testing.md))

### 3. Future Work
1. **Bot Layer Refinement**
   - [ ] Simplify command handlers
   - [ ] Improve error reporting and logging
   - [ ] Add telemetry/logging for end-to-end monitoring

## Implementation Approach

1. **Testing First**
   ```elixir
   # Create test helpers (GameBot.Test.RepositoryCase)
   defmodule GameBot.Test.RepositoryCase do
     # Common test setup, unique ID generators, and event builder functions.
   end

   # Comprehensive tests cover:
   describe "repository operations" do
     test "handles concurrent modifications"
     test "properly validates input"
     test "manages transactions"
   end
   ```
   - Unit tests are in `test/game_bot/infrastructure/persistence/repo` and `event_store`.
   - Integration tests are in `test/game_bot/infrastructure/persistence/integration_test.exs`.

2. **Gradual Migration**
   ```elixir
   # Update existing code to use new interfaces
   alias GameBot.Infrastructure.Persistence.{Repo, EventStore.Adapter}

   def handle_command(command) do
     Repo.transaction(fn ->
       # Use new interfaces for event store and repository operations
     end)
   end
   ```
3. **Cleanup**
   - Remove old implementations only after successful migration and test verification.
   - Verify that no references to deprecated modules remain.
   - Run the full test suite after each removal stage.

## Success Metrics

- [ ] All tests passing (unit, integration, and property tests)
- [ ] No remaining references to old implementations
- [ ] Improved error handling coverage (detailed errors with context)
- [ ] Clear separation of module boundaries (domain, infrastructure, bot)
- [ ] Up-to-date, complete documentation with usage examples

## Risk Mitigation

1. **Testing**
   - Add tests before removing old code.
   - Use property testing for serialization scenarios.
   - Include integration tests for critical workflows.
2. **Migration**
   - Update modules one at a time with comprehensive test verification.
   - Keep old implementations until the new system is fully validated.
3. **Monitoring**
   - Add telemetry for key operations.
   - Monitor error rates during the migration.
   - Track performance metrics to verify improvements. 