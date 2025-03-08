# Infrastructure Improvement Recommendations

## Implementation Checklist

- [ ] **High Priority**
  - [ ] 1. Separate Test Code from Production Code
  - [ ] 2. Reduce Code Duplication
  - [ ] 3. Refine Timeout Handling
- [ ] **Medium Priority**
  - [ ] 4. Improve ETS Table Management
  - [ ] 5. Use More Pattern Matching in Function Heads
  - [ ] 6. Improve Module Function Documentation
- [ ] **Low Priority**
  - [ ] 7. Improve Logging Strategy
  - [ ] 8. Make Transaction Atomicity Guarantees Explicit
  - [ ] 9. Add Telemetry Instrumentation

This document outlines recommendations for improving the infrastructure layer of GameBot, particularly focusing on the repository and persistence implementations. Recommendations are organized by priority and include an assessment of implementation difficulty.

## High Priority

### 1. Separate Test Code from Production Code
**Issue**: Test-specific logic is mixed with production code, making both harder to maintain and understand.

**Recommendation**: Use a behavior pattern with a mock repository implementation for tests.

**Difficulty**: Moderate

```elixir
# In your test setup
Mox.defmock(MockRepo, for: Repo.Behaviour)
Application.put_env(:game_bot, :repo_implementation, MockRepo)

# In your production code
@repo_implementation Application.compile_env(:game_bot, :repo_implementation, __MODULE__)
```

### 2. Reduce Code Duplication
**Issue**: The `try_insert`, `try_update`, and `try_delete` functions share very similar error handling patterns.

**Recommendation**: Extract common patterns into shared helper functions.

**Difficulty**: Easy

```elixir
defp execute_repo_operation(operation, args) do
  case apply(__MODULE__, operation, args) do
    {:ok, record} -> {:ok, record}
    {:error, changeset} -> handle_changeset_error(changeset)
  end
rescue
  e in Ecto.StaleEntryError ->
    {:error, %PersistenceError{type: :concurrency, message: "Stale entry", context: __MODULE__}}
  e in Ecto.ConstraintError ->
    {:error, %PersistenceError{type: :validation, message: "Constraint violation: #{e.message}", context: __MODULE__}}
  e ->
    {:error, %PersistenceError{type: :system, message: "Unexpected error: #{inspect(e)}", context: __MODULE__}}
end
```

### 3. Refine Timeout Handling
**Issue**: The current transaction timeout implementation works but generates noisy error messages in logs.

**Recommendation**: Implement a custom timeout mechanism that provides cleaner error handling.

**Difficulty**: Moderate

```elixir
def execute_transaction(fun, opts \\ []) when is_function(fun, 0) do
  timeout = Keyword.get(opts, :timeout, 5000)
  
  task = Task.async(fn -> 
    try do
      __MODULE__.transaction(fn -> 
        # Existing transaction logic
      end, Keyword.delete(opts, :timeout))
    catch
      kind, reason -> {kind, reason}
    end
  end)
  
  try do
    case Task.await(task, timeout) do
      {:exit, reason} -> {:error, format_error(reason)}
      result -> result
    end
  catch
    :exit, {:timeout, _} ->
      Task.shutdown(task, :brutal_kill)
      {:error, %PersistenceError{type: :timeout, message: "Transaction timed out", context: __MODULE__}}
  end
end
```

## Medium Priority

### 4. Improve ETS Table Management
**Issue**: ETS tables are created on-demand without proper lifecycle management.

**Recommendation**: Create ETS tables during process initialization and clean them up on termination.

**Difficulty**: Moderate

```elixir
# If using a GenServer or similar
def init(_) do
  Process.flag(:trap_exit, true)
  :ets.new(@test_names, [:set, :public, :named_table])
  :ets.new(@updated_records, [:set, :public, :named_table])
  :ets.new(@deleted_records, [:set, :public, :named_table])
  {:ok, %{}}
end

def terminate(_reason, _state) do
  :ets.delete(@test_names)
  :ets.delete(@updated_records)
  :ets.delete(@deleted_records)
  :ok
end
```

### 5. Use More Pattern Matching in Function Heads
**Issue**: Some functions use conditionals inside the function body instead of pattern matching.

**Recommendation**: Refactor to use pattern matching in function heads where appropriate.

**Difficulty**: Easy

```elixir
# Instead of:
def format_error(error) do
  if is_struct(error, PersistenceError) do
    error
  else
    # transform error
  end
end

# Prefer:
def format_error(%PersistenceError{} = error), do: error
def format_error(:rollback), do: %PersistenceError{type: :cancelled, message: "Transaction rolled back", context: __MODULE__}
def format_error(error), do: %PersistenceError{type: :system, message: "Error in transaction: #{inspect(error)}", context: __MODULE__}
```

### 6. Improve Module Function Documentation
**Issue**: Function documentation lacks comprehensive `@spec` annotations.

**Recommendation**: Add detailed type specifications for all public functions.

**Difficulty**: Easy

```elixir
@spec fetch(Ecto.Queryable.t(), integer(), Keyword.t()) :: {:ok, struct()} | {:error, PersistenceError.t()}
def fetch(queryable, id, opts \\ []) do
  # ...
end
```

## Low Priority

### 7. Improve Logging Strategy
**Issue**: Logging could be more structured for better analysis.

**Recommendation**: Use structured logging with metadata.

**Difficulty**: Easy

```elixir
def execute(fun, guild_id \\ nil, opts \\ []) when is_function(fun, 0) do
  metadata = if guild_id, do: [guild_id: guild_id], else: []
  Logger.debug("Starting transaction", metadata)
  
  # Existing transaction logic...
  
  case result do
    {:ok, value} ->
      Logger.debug("Transaction completed successfully", metadata)
      {:ok, value}
    {:error, error} ->
      Logger.warning("Transaction failed: #{inspect(error)}", metadata ++ [error_type: error.type])
      {:error, error}
  end
end
```

### 8. Make Transaction Atomicity Guarantees Explicit
**Issue**: The `execute_steps` function manages step sequencing but could be more explicit about atomicity.

**Recommendation**: Make rollback decisions more explicit in the code.

**Difficulty**: Easy

```elixir
def execute_steps(steps, guild_id \\ nil, opts \\ []) when is_list(steps) do
  execute(
    fn ->
      result = Enum.reduce_while(steps, nil, fn step, acc ->
        # Your step execution logic
      end)
      
      # Make the rollback decision explicit
      case result do
        {:error, reason} -> 
          Logger.debug("Rolling back transaction due to step failure: #{inspect(reason)}")
          {:error, reason}
        success -> 
          success
      end
    end,
    guild_id,
    opts
  )
end
```

### 9. Add Telemetry Instrumentation
**Issue**: No instrumentation for operational visibility.

**Recommendation**: Add telemetry events for monitoring and tracing.

**Difficulty**: Moderate

```elixir
def execute_transaction(fun, opts \\ []) when is_function(fun, 0) do
  start_time = System.monotonic_time()
  metadata = %{opts: opts}
  
  :telemetry.span([:game_bot, :repo, :transaction], metadata, fn ->
    result = try do
      # Your transaction code
    catch
      # Your error handling
    end
    
    {result, Map.put(metadata, :result, result)}
  end)
end
```

## Implementation Roadmap

To implement these recommendations in a structured way, consider the following approach:

1. **Week 1**: Implement high priority items
   - Separate test code from production code
   - Reduce code duplication
   - Refine timeout handling

2. **Week 2**: Implement medium priority items
   - Improve ETS table management
   - Use more pattern matching
   - Improve function documentation

3. **Week 3**: Implement low priority items
   - Improve logging strategy
   - Make transaction atomicity explicit
   - Add telemetry instrumentation

## Additional Considerations

- **Test coverage**: Ensure any changes are covered by tests
- **Performance impact**: Monitor performance metrics before and after changes
- **Documentation**: Update documentation to reflect architectural changes
- **Code review**: Have changes reviewed by team members familiar with the codebase

By implementing these recommendations, the codebase will become more maintainable, robust, and aligned with Elixir best practices. 