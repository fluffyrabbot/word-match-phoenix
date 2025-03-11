# Event Store Adapter Implementation Guide

This document provides guidelines for implementing event store adapters in the GameBot system.

## Architecture Overview

The event store adapter system consists of:

1. **Behaviour** (`GameBot.Infrastructure.Persistence.EventStore.Adapter.Behaviour`): Defines the contract that all adapters must implement.
2. **Base** (`GameBot.Infrastructure.Persistence.EventStore.Adapter.Base`): Provides common functionality like telemetry, retries, and error handling.
3. **Concrete Adapters**: Implementations for specific storage backends (e.g., PostgreSQL).
4. **Facade** (`GameBot.Infrastructure.Persistence.EventStore.Adapter`): Provides a unified interface to the configured adapter.

## Implementation Guidelines

### Return Value Consistency

All adapter implementations must follow these return value conventions:

- Public API functions must return values as specified in the `Behaviour` module:
  - Success: Varies by function (e.g., `{:ok, result}` or `:ok`)
  - Failure: `{:error, Error.t()}`
- Private implementation functions (`do_*`) must return values compatible with the Base adapter:
  - Success: `{:ok, result}`
  - Failure: `{:error, Error.t()}`
- For `delete_stream/3`, implementations should return `{:ok, :ok}` which will be converted to `:ok` by the Base adapter

### Behaviour Implementation

- Use `@impl true` annotations only on public functions that directly implement the Behaviour callbacks
  - These annotations should be in the Base module, not in concrete adapter implementations
  - Do not use `@impl` annotations on private helper functions (e.g., `defp do_*`)
- Implement all required callbacks from the Behaviour
- Optional callbacks should be properly marked as such in the Behaviour
- The Base module should define public functions that implement the Behaviour, which then delegate to private helper functions in concrete adapters

### Error Handling

- Use `with` expressions for sequential operations that might fail
- Return structured error types from the `Error` module
- Include relevant context in error metadata
- Use consistent error types for similar error conditions

### Function Arity and Parameter Handling

- Do not use default parameter values in functions that implement behaviour callbacks
- Create separate function heads for different arities instead of using default parameters
- Standardize parameter handling (e.g., consistent conversion of maps/keyword lists)
- Document parameter requirements and transformations

### Pattern Matching

- Favor pattern matching in function clauses over conditionals
- Use guard clauses with `when` instead of internal `if`/`case` statements where possible
- For data transformations, use pipeline operators `|>` instead of nested function calls

### Transaction Handling

- Use transactions for operations that require atomicity
- Ensure consistent error handling within transactions
- Document transaction isolation levels and expectations

### Code Organization

- Group related functions together within each module
- Ensure private helper functions are clearly separated from public API
- Consider extracting common functionality into separate modules
- Document the purpose and responsibility of each module

## PostgreSQL Adapter Specifics

- Use parameterized queries to prevent SQL injection
- Handle database-specific errors appropriately
- Use transactions for multi-step operations
- Document database schema requirements

## Testing Adapters

- Create comprehensive tests for each adapter implementation
- Test error conditions and edge cases
- Ensure tests run with the correct adapter configuration
- Consider using property-based tests for complex behavior

## Documentation

- Document the purpose and responsibility of each module
- Add detailed documentation for each public function
- Document the adapter selection process
- Create examples for common usage patterns
- Document performance characteristics and limitations

## Logging and Telemetry

- Use structured logging for important operations
- Ensure consistent logging across all adapter implementations
- Use telemetry for performance monitoring
- Document available telemetry events

## Implementation Notes

### Return Value Conversion

The Base adapter handles conversion of return values from the implementation functions to the format expected by the Behaviour. For example, for `delete_stream/3`:

```elixir
# In Base.ex
def delete_stream(stream_id, expected_version, opts \\ []) do
  with_telemetry(__MODULE__, :delete, stream_id, fn ->
    with_retries(
      fn ->
        do_delete_stream(stream_id, expected_version, opts)
      end,
      __MODULE__,
      max_retries: @max_retries,
      initial_delay: @initial_delay
    )
  end)
  |> case do
    {:ok, :ok} -> :ok  # Convert {:ok, :ok} to :ok for the Behaviour
    other -> other     # Pass through other return values
  end
end
```

### Error Handling with `with`

Use `with` expressions for sequential operations that might fail:

```elixir
with {:ok, actual_version} <- get_stream_version(stream_id),
     :ok <- validate_stream_exists(actual_version),
     :ok <- validate_expected_version(actual_version, expected_version),
     {:ok, :ok} <- delete_stream_data(stream_id) do
  {:ok, :ok}
end
```

### Pattern Matching for Validation

Use pattern matching for validation:

```elixir
# Pattern matching for different expected version scenarios
defp validate_expected_version(_, :any), do: :ok
defp validate_expected_version(0, :no_stream), do: :ok
defp validate_expected_version(actual, :stream_exists) when actual > 0, do: :ok
defp validate_expected_version(actual, expected) when actual == expected, do: :ok
defp validate_expected_version(actual, expected) do
  {:error, Error.concurrency_error(__MODULE__, "Wrong expected version", %{
    expected: expected,
    actual: actual
  })}
end
``` 