# Event Store Adapter Standardization

This document outlines standardization recommendations for the Event Store adapter implementation to ensure consistency, maintainability, and reliability across the codebase.

## Return Value Consistency

- [ ] Ensure `delete_stream/3` consistently returns `:ok | {:error, Error.t()}` as specified in the Behaviour
- [ ] Verify that `Base.ex` correctly converts `{:ok, :ok}` to `:ok` for all relevant functions
- [ ] Audit all adapter implementations to ensure they return values compatible with the Base adapter's expectations
- [ ] Add explicit documentation for expected return values in each function's documentation

## Behaviour Implementation Annotations

- [ ] Add `@impl` annotations to all functions in `Postgres.ex` that implement the Behaviour
- [ ] Remove `@impl` annotations from functions that are not part of the Behaviour
- [ ] Ensure all required callbacks from the Behaviour are implemented
- [ ] Verify that optional callbacks are properly marked as such in the Behaviour

## Error Handling Standardization

- [ ] Standardize error handling patterns across all functions (prefer `with` expressions)
- [ ] Ensure consistent error types are used for similar error conditions
- [ ] Create helper functions for common error handling patterns
- [ ] Document expected error types and their meanings

## Function Arity and Parameter Handling

- [ ] Remove default parameter values from behaviour implementation functions
- [ ] Create separate function heads for different arities instead of using default parameters
- [ ] Standardize parameter handling (e.g., consistent conversion of maps/keyword lists)
- [ ] Document parameter requirements and transformations

## Adapter Resolution and Configuration

- [ ] Add compile-time verification that configured adapters implement the Behaviour
- [ ] Create a startup check to validate adapter configuration
- [ ] Document the adapter resolution strategy clearly
- [ ] Add tests for adapter resolution edge cases

## Dependency Management

- [ ] Audit for potential circular dependencies between adapter modules
- [ ] Ensure clear separation of concerns between modules
- [ ] Document the dependency hierarchy
- [ ] Consider using protocols for polymorphic behavior where appropriate

## Transaction Handling

- [ ] Standardize transaction handling across all database operations
- [ ] Create helper functions for common transaction patterns
- [ ] Ensure consistent error handling within transactions
- [ ] Document transaction isolation levels and expectations

## Code Organization

- [ ] Group related functions together within each module
- [ ] Ensure private helper functions are clearly separated from public API
- [ ] Consider extracting common functionality into separate modules
- [ ] Document the purpose and responsibility of each module

## Testing

- [ ] Create comprehensive tests for each adapter implementation
- [ ] Test error conditions and edge cases
- [ ] Ensure tests run with the correct adapter configuration
- [ ] Add property-based tests for complex behavior

## Documentation

- [ ] Add detailed documentation for each public function
- [ ] Document the adapter selection process
- [ ] Create examples for common usage patterns
- [ ] Document performance characteristics and limitations

## Logging and Telemetry

- [ ] Ensure consistent logging across all adapter implementations
- [ ] Standardize telemetry event names and metadata
- [ ] Document available telemetry events
- [ ] Add structured logging for important operations

## Implementation-Specific Concerns

### PostgreSQL Adapter

- [ ] Standardize SQL query construction
- [ ] Ensure proper parameter escaping in all queries
- [ ] Optimize batch operations
- [ ] Document database schema requirements

### In-Memory/Test Adapter

- [ ] Ensure test adapter behavior matches production adapters
- [ ] Document differences between test and production adapters
- [ ] Optimize for test performance
- [ ] Add tools for test state inspection and manipulation 