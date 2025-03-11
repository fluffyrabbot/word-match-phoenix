# Event Store Adapter Standardization

This document outlines standardization recommendations for the Event Store adapter implementation to ensure consistency, maintainability, and reliability across the codebase.

## Return Value Consistency

- [x] Ensure `delete_stream/3` consistently returns `:ok | {:error, Error.t()}` as specified in the Behaviour
- [x] Verify that `Base.ex` correctly converts `{:ok, :ok}` to `:ok` for all relevant functions
- [x] Audit all adapter implementations to ensure they return values compatible with the Base adapter's expectations
- [x] Add explicit documentation for expected return values in each function's documentation

## Behaviour Implementation Annotations

- [x] Add `@impl` annotations to all functions in `Postgres.ex` that implement the Behaviour
- [x] Remove `@impl` annotations from functions that are not part of the Behaviour
- [x] Ensure all required callbacks from the Behaviour are implemented
- [x] Verify that optional callbacks are properly marked as such in the Behaviour

## Error Handling Standardization

- [x] Standardize error handling patterns across all functions (prefer `with` expressions)
- [x] Ensure consistent error types are used for similar error conditions
- [x] Create helper functions for common error handling patterns
- [x] Document expected error types and their meanings

## Function Arity and Parameter Handling

- [x] Remove default parameter values from behaviour implementation functions
- [ ] Create separate function heads for different arities instead of using default parameters
- [x] Standardize parameter handling (e.g., consistent conversion of maps/keyword lists)
- [x] Document parameter requirements and transformations

## Adapter Resolution and Configuration

- [ ] Add compile-time verification that configured adapters implement the Behaviour
- [ ] Create a startup check to validate adapter configuration
- [x] Document the adapter resolution strategy clearly
- [ ] Add tests for adapter resolution edge cases

## Dependency Management

- [ ] Audit for potential circular dependencies between adapter modules
- [x] Ensure clear separation of concerns between modules
- [x] Document the dependency hierarchy
- [ ] Consider using protocols for polymorphic behavior where appropriate

## Transaction Handling

- [x] Standardize transaction handling across all database operations
- [x] Create helper functions for common transaction patterns
- [x] Ensure consistent error handling within transactions
- [x] Document transaction isolation levels and expectations

## Code Organization

- [x] Group related functions together within each module
- [x] Ensure private helper functions are clearly separated from public API
- [ ] Consider extracting common functionality into separate modules
- [x] Document the purpose and responsibility of each module

## Testing

- [ ] Create comprehensive tests for each adapter implementation
- [ ] Test error conditions and edge cases
- [ ] Ensure tests run with the correct adapter configuration
- [ ] Add property-based tests for complex behavior

## Documentation

- [x] Add detailed documentation for each public function
- [x] Document the adapter selection process
- [x] Create examples for common usage patterns
- [x] Document performance characteristics and limitations

## Logging and Telemetry

- [x] Ensure consistent logging across all adapter implementations
- [x] Standardize telemetry event names and metadata
- [x] Document available telemetry events
- [x] Add structured logging for important operations

## Implementation-Specific Concerns

### PostgreSQL Adapter

- [x] Standardize SQL query construction
- [x] Ensure proper parameter escaping in all queries
- [ ] Optimize batch operations
- [x] Document database schema requirements

### In-Memory/Test Adapter

- [ ] Ensure test adapter behavior matches production adapters
- [ ] Document differences between test and production adapters
- [ ] Optimize for test performance
- [ ] Add tools for test state inspection and manipulation

## Next Steps

1. Complete the remaining standardization tasks
2. Implement comprehensive tests for all adapters
3. Consider performance optimizations for batch operations
4. Develop a more robust In-Memory/Test adapter for testing purposes 