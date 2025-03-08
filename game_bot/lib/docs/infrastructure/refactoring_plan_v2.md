# Refactoring Plan V2: Integration and Warning Resolution

## Current State Assessment

### Completed Infrastructure Work (✅)
1. Basic directory structure for infrastructure layer
2. Initial error handling standardization
3. Basic behavior definitions
4. PostgreSQL implementations
5. Basic testing infrastructure
6. EventStore macro integration
7. Core test case implementations
8. Integration test framework
9. Error handling standardization

### Critical Warning Patterns (🚨)
1. ~~EventStore API compatibility issues~~ ✅
2. ~~Behavior conflicts and missing @impl annotations~~ ✅
3. ~~Undefined or incorrect function signatures~~ ✅
4. Layer violations between Domain and Infrastructure
5. Inconsistent error handling patterns

## Phase 0: Macro Integration Guidelines

### Best Practices for Macro Usage ✅

1. **Documentation Requirements** ✅
   - Clear documentation of macro-generated functions
   - Examples of proper macro integration
   - Warning about common pitfalls
   - Clear distinction between macro and custom functionality

2. **Function Implementation Rules** ✅
   ```elixir
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
   ```

3. **Required Documentation Sections** ✅
   - Macro Integration Guidelines
   - Implementation Notes
   - Example Usage
   - Function-specific documentation

4. **File Organization** ✅
   - Macro use statements at top
   - Type definitions
   - Configuration
   - Overridden callbacks
   - Custom functions
   - Private helpers

## Phase 1: EventStore Core Stabilization

### 1.1 API Compatibility ✅
- [x] Fix EventStore.Config usage in migrate.ex
- [x] Update Storage.Initializer calls
- [x] Fix Ecto.Repo integration
- [x] Verify all API calls match current EventStore version

### 1.2 Macro Integration ✅
- [x] Add macro integration documentation to postgres.ex
- [x] Remove conflicting function implementations
- [x] Add proper @impl annotations for actual overrides
- [x] Create wrapper functions for customization
- [x] Apply same patterns to other EventStore implementations

### 1.3 Testing Infrastructure ✅
- [x] Create test helpers for macro integration
  - Created `GameBot.Test.EventStoreCase` with comprehensive helpers
  - Added verification functions for behavior compliance
  - Added macro integration guidelines validation
- [x] Add tests for custom wrapper functions
  - Added stream operation tests
  - Added error handling tests
- [x] Verify proper macro function delegation
  - Added tests for macro-generated functions
  - Verified config/0 and ack/2 availability
- [x] Add integration tests for all implementations
  - Core EventStore
  - PostgreSQL implementation
  - Test implementation
  - Mock implementation
  - Added performance metrics
  - Added concurrency tests
  - Added transaction boundary tests

## Phase 2: Infrastructure Layer Cleanup

### 2.1 Error Handling Consolidation 🚧
- [ ] Create dedicated error module:
  ```elixir
  defmodule GameBot.Infrastructure.Error do
    @type error_type :: :validation | :concurrency | :system | :not_found
    
    defstruct [:type, :context, :message, :details]
    
    def new(type, context, message, details \\ nil)
  end
  ```
- [ ] Update error handling in:
  - [ ] EventStore adapter
  - [ ] Repository implementations
  - [ ] Transaction management

### 2.2 Layer Separation 🚧
- [ ] Move serialization to infrastructure:
  ```
  infrastructure/
  └── persistence/
      └── event_store/
          ├── serializer/
          │   ├── behaviour.ex
          │   └── json_serializer.ex
          └── adapter.ex
  ```
- [ ] Remove domain dependencies from adapter:
  - [ ] Extract EventStructure validation
  - [ ] Move event-specific logic to domain
  - [ ] Create proper boundary interfaces

## Phase 3: Function and Type Cleanup

### 3.1 Function Signature Fixes 🚧
- [ ] Update event creation functions:
  ```elixir
  # Fix arity mismatches
  def new(game_id, team_id, player_id, word, reason, metadata)  # GuessError
  def new(game_id, reason, metadata)  # RoundCheckError
  def new(game_id, team_id, word1, word2, reason, metadata)  # GuessPairError
  ```
- [ ] Fix DateTime usage:
  ```elixir
  # Replace deprecated calls
  - DateTime.from_iso8601!/1
  + DateTime.from_iso8601/1
  ```
- [ ] Update System calls:
  ```elixir
  # Replace deprecated calls
  - System.get_pid()
  + System.pid()
  ```

### 3.2 Code Organization 🚧
- [ ] Group related functions:
  ```elixir
  # In UserProjection
  def handle_event(%UserCreated{} = event), do: ...
  def handle_event(%UserUpdated{} = event), do: ...
  def handle_event(_, state), do: {:ok, state}
  ```
- [ ] Fix duplicate docs:
  - [ ] Remove redundant @doc in ReplayCommands
  - [ ] Consolidate documentation

## Phase 4: Testing and Validation

### 4.1 Test Infrastructure ✅
- [x] Create test helpers:
  ```elixir
  defmodule GameBot.Test.EventStoreCase do
    use ExUnit.CaseTemplate
    
    using do
      quote do
        alias GameBot.Infrastructure.EventStore
        import GameBot.Test.EventStoreHelpers
      end
    end
  end
  ```
- [x] Add specific test cases:
  - [x] API compatibility
  - [x] Behavior implementations
  - [x] Error handling
  - [x] Concurrent operations

### 4.2 Integration Tests ✅
- [x] Test EventStore operations:
  - [x] Stream versioning
  - [x] Concurrency control
  - [x] Error propagation
- [x] Test Repository integration:
  - [x] Transaction boundaries
  - [x] Error handling
  - [x] Concurrent access

## Success Criteria

### Documentation
- [x] All macro-using modules have clear integration guidelines
- [x] Examples provided for common use cases
- [x] Warning sections for common pitfalls

### Implementation
- [x] No macro conflicts
- [x] Proper separation between macro and custom code
- [x] Clear wrapper functions for customization

### Testing
- [x] Tests for macro integration
- [x] Tests for custom functionality
- [x] Error handling coverage

## Risk Mitigation

1. **Documentation**
   - Clear guidelines prevent future conflicts
   - Examples show proper usage
   - Warnings highlight common issues

2. **Testing**
   - Test macro integration specifically
   - Verify custom functionality
   - Check error conditions

3. **Gradual Migration**
   - Update one module at a time
   - Verify each change
   - Maintain backwards compatibility

## Next Steps

1. ~~Add macro integration documentation to all macro-using modules~~ ✅
2. ~~Fix existing macro conflicts~~ ✅
3. ~~Add proper tests~~ ✅
4. Continue with layer separation 🚧
5. Complete error handling consolidation 🚧
6. Finish function signature cleanup 🚧 