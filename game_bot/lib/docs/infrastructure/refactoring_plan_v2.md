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
9. Error handling standardization ✅
10. Test connection management and sandbox setup ✅

### Critical Warning Patterns (🚨)
1. ~~EventStore API compatibility issues~~ ✅
2. ~~Behavior conflicts and missing @impl annotations~~ ✅
3. ~~Undefined or incorrect function signatures~~ ✅
4. Layer violations between Domain and Infrastructure
5. ~~Inconsistent error handling patterns~~ ✅

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

### 2.1 Error Handling Consolidation ✅
- [x] Create unified error module in Infrastructure.Error:
  ```elixir
  # Unified error types and consistent interface
  @type error_type ::
    :validation |
    :serialization |
    :not_found |
    :concurrency |
    :timeout |
    :connection |
    :system |
    :stream_too_large
  ```
- [x] Create error helpers module:
  ```elixir
  defmodule GameBot.Infrastructure.ErrorHelpers do
    def wrap_error(operation, context)
    def with_retries(operation, context, opts \\ [])
    def translate_error(reason, context)
  end
  ```
- [x] Migration steps for existing code:
  - [x] Update EventStore.Error usage:
    - [x] Replace error creation with new Error module
    - [x] Update error handling to use ErrorHelpers
    - [x] Add context tracking
  - [x] Update Persistence.Error usage:
    - [x] Replace error creation with new Error module
    - [x] Update error handling to use ErrorHelpers
    - [x] Add context tracking
  - [x] Update error translation layers:
    - [x] Add translation for external dependencies
    - [x] Update error message formatting
    - [x] Add proper context propagation
    - [x] Add handling for event store specific errors
    - [x] Add exception detection without hard dependencies

### 2.2 Layer Separation ✅
- [x] Create proper infrastructure boundaries:
  ```
  infrastructure/
  └── persistence/
      ├── event_store/
      │   ├── serialization/
      │   │   ├── behaviour.ex ✅
      │   │   ├── json_serializer.ex ✅
      │   │   └── event_translator.ex ✅
      │   ├── adapter/
      │   │   ├── behaviour.ex ✅
      │   │   ├── base.ex ✅
      │   │   └── postgres.ex ✅
      │   └── config.ex
      └── repository/
          ├── behaviour.ex
          ├── postgres_repo.ex
          └── cache.ex
  ```
- [x] Implement clean serialization layer:
  - [x] Create serialization behaviour
  - [x] Move event serialization to infrastructure
  - [x] Add versioning support
  - [x] Implement event translation
- [x] Create proper adapter interfaces:
  - [x] Define clear adapter behaviors
  - [x] Add base implementation
  - [x] Add proper error translation
  - [x] Remove domain dependencies
- [x] Clean up deprecated implementations:
  - [x] Remove old adapter.ex
  - [x] Remove old postgres.ex
  - [x] Remove old serializer.ex
  - [x] Remove old behaviour.ex
  - [x] Update all references to new implementations
  - [x] Update test files

### 2.3 Test Connection Management ✅
- [x] Fix sandbox database handling
  - [x] Update EventStoreCase setup
  - [x] Add proper connection cleanup
  - [x] Add explicit checkout pattern
  - [x] Add connection cleanup on exit
- [x] Improve test helpers
  - [x] Create ConnectionHelper module
  - [x] Enhance connection cleanup
  - [x] Fix test isolation issues
  - [x] Add reliable teardown
- [x] Fix test_helper.exs configuration
  - [x] Start applications in correct order
  - [x] Configure sandbox mode consistently
  - [x] Clean state before tests
  - [x] Optimize test environment

### Next Steps:
1. Update repository layer:
   - Create repository behaviour
   - Implement base repository
   - Add caching support
   - Add telemetry

2. Create configuration:
   - Add config module
   - Define settings schema
   - Add validation
   - Add documentation

3. Testing and validation:
   - Add integration tests
   - Test error scenarios
   - Verify boundaries
   - Test performance

4. Documentation:
   - Update module docs
   - Add examples
   - Document error handling
   - Add architecture diagrams

5. Final cleanup:
   - Remove old modules
   - Update dependencies
   - Fix warnings
   - Add missing tests

### Migration Guide:
1. Error Handling:
   - Use new Error module for all errors
   - Add proper context tracking
   - Use ErrorHelpers for retries
   - Add telemetry for errors

2. Serialization:
   - Use JsonSerializer for events
   - Add version support
   - Implement migrations
   - Update tests

3. Adapters:
   - Use Base adapter
   - Implement required callbacks
   - Add telemetry
   - Add error handling

4. Repository:
   - Use new behaviours
   - Add caching
   - Add telemetry
   - Update tests

## Phase 3: Function and Type Cleanup

### 3.1 Function Signature Fixes 🚧
- [ ] Update event creation functions:
  ```elixir
  # Standardize event creation
  def new(attrs, metadata) when is_map(attrs) do
    with {:ok, event} <- validate_attrs(attrs),
         {:ok, meta} <- validate_metadata(metadata) do
      {:ok, struct(__MODULE__, Map.merge(event, %{metadata: meta}))}
    end
  end
  ```
- [ ] Implement proper validation:
  ```elixir
  # Add type validation
  @type validation_error :: {:error, :invalid_type | :missing_field | :invalid_format}
  
  @spec validate_attrs(map()) :: {:ok, map()} | validation_error
  def validate_attrs(attrs) do
    # Implementation
  end
  ```
- [ ] Add proper type specs:
  - [ ] Update all public function specs
  - [ ] Add proper return type annotations
  - [ ] Document error conditions

### 3.2 Code Organization 🚧
- [ ] Group related functions:
  ```elixir
  # Example organization pattern
  defmodule GameBot.Domain.Events.GameEvent do
    # Type definitions
    @type t :: %__MODULE__{}
    
    # Struct definition
    defstruct [:id, :type, :data, :metadata]
    
    # Public API
    @spec new(map(), map()) :: {:ok, t()} | {:error, term()}
    
    # Validation functions
    @spec validate_attrs(map()) :: {:ok, map()} | {:error, term()}
    
    # Private helpers
    defp build_event(attrs, meta)
  end
  ```
- [ ] Implement consistent patterns:
  - [ ] Use proper type specs
  - [ ] Follow consistent naming
  - [ ] Group related functions
  - [ ] Add proper documentation

### 3.3 Compiler Warning Resolution 🚧
- [ ] Address pattern match warnings:
  ```elixir
  # Before
  def handle_event(event, state) do
    # Missing pattern match
  end
  
  # After
  def handle_event(%Event{} = event, %State{} = state) do
    # Proper pattern match
  end
  ```
- [ ] Fix unused variable warnings:
  - [ ] Add underscore prefix to unused vars
  - [ ] Remove unnecessary bindings
  - [ ] Document intentional unused vars
- [ ] Address type specification warnings:
  - [ ] Add missing type specs
  - [ ] Fix incorrect specs
  - [ ] Document complex types

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

### 4.3 Error Handling Tests ✅
- [x] Test error translation:
  - [x] EventStore errors
  - [x] Ecto errors
  - [x] Custom errors
  - [x] Exception handling
- [x] Test retry mechanisms:
  - [x] Connection errors
  - [x] Timeout handling
  - [x] Retry limits
  - [x] Exponential backoff
  - [x] Jitter implementation
- [x] Test context propagation:
  - [x] Error sources
  - [x] Error details
  - [x] Error tracking

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

1. Continue with layer separation ✅
2. Complete error handling consolidation ✅
3. Finish function signature cleanup 🚧
4. Complete compiler warning resolution 🚧
5. Update documentation with error handling examples ✅ 