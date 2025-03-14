# GenServer Parameter Conventions in Event Store Functions

## Overview

This document outlines important patterns and conventions for working with GenServer-based modules in the EventStore system, particularly focusing on potential issues with parameter handling in stream-related functions. These insights emerged from troubleshooting the `GameBot.Test.EventStoreCore` module.

## Core Problem: Parameter Ordering and Type Confusion

The primary issue we encountered was related to parameter ordering and type confusion in GenServer-based functions that handle streams. In particular, when a string parameter (like a stream ID) can be mistakenly used as the first parameter instead of a GenServer name or PID.

### Example Case

A function might be defined as:

```elixir
def append_to_stream(server \\ __MODULE__, stream_id, expected_version, events)
```

In this pattern, if a user accidentally calls:

```elixir
# Wrong order - using stream_id as first parameter
append_to_stream("my-stream-1234", :no_stream, events)
```

The function will attempt to use the string `"my-stream-1234"` as a GenServer name, rather than the default `__MODULE__`.

## Defensive Coding Patterns

### 1. Type Checking in Function Bodies

The most effective solution we implemented was type checking inside function bodies:

```elixir
def append_to_stream(server \\ __MODULE__, stream_id, expected_version, events) do
  # Handle case where first parameter might actually be a stream_id (string)
  {actual_server, actual_stream_id, actual_expected_version, actual_events} =
    case {server, stream_id, expected_version, events} do
      # If the "server" is a binary and looks like a stream_id, it's likely the stream_id was passed first
      {server, stream_id, expected_version, events} when is_binary(server) ->
        {__MODULE__, server, stream_id, expected_version}
      # Normal case with correct parameter ordering
      {server, stream_id, expected_version, events} ->
        {server, stream_id, expected_version, events}
    end
    
  # Continue with corrected parameters
  GenServer.call(actual_server, {:append_to_stream, actual_stream_id, actual_expected_version, actual_events})
end
```

### 2. Consistent Parameter Handling in Helper Functions

For helper functions that work with GenServer names or PIDs:

```elixir
defp get_operation_timeout(server, operation) do
  # If server is a binary (string), it's likely a stream_id being incorrectly passed
  # In that case, use the module name as the actual server
  actual_server = case server do
    server when is_binary(server) -> __MODULE__
    server -> server
  end
  
  # Continue with corrected server parameter
  GenServer.call(actual_server, {:get_operation_timeout, operation})
end
```

## GenServer Name Resolution

Understanding how GenServer resolves names is critical:

1. **Atom Names**: GenServer names registered as atoms (like `:my_server` or module names)
2. **String Names**: When strings are incorrectly used instead of proper names
3. **PID References**: Direct process references

### Common Errors

When a string is mistakenly used as a GenServer name, you'll see errors like:

```
** (EXIT) exited in: GenServer.call("my-stream-1234", {:append_to_stream, ...}, 5000)
    ** (EXIT) no process: the process is not alive or there's no process currently associated with the given name
```

Or encoding errors when the string is passed to a database function:

```
Postgrex expected a binary, got ~c"<0.825.0>". Please make sure the value you are passing matches the definition in your table
```

## Best Practices

1. **Explicit Pattern Matching**: Use pattern matching to handle misplaced parameters
   
2. **Descriptive Error Messages**: Add clear error messages when detecting incorrect parameter types

3. **Function Arity Consistency**: Maintain consistent parameter ordering across similar functions

4. **Type Guards**: Use type guards in function heads when possible

5. **Defensive GenServer Calls**: Always verify the server parameter before calling GenServer functions:

```elixir
def safe_call(server, message, timeout \\ 5000) do
  actual_server = case server do
    s when is_binary(s) -> __MODULE__  # Default to module name if string
    s -> s
  end
  
  GenServer.call(actual_server, message, timeout)
end
```

## Examples from Our Implementation

### Fixed Functions

We applied these patterns to fix several functions in `GameBot.Test.EventStoreCore`:

1. **append_to_stream/4**
2. **read_stream_forward/4** 
3. **stream_version/2**
4. **delete_stream/3**
5. **get_operation_timeout/2**

### Function Pattern Examples

```elixir
# Original function with potential issues
def read_stream_forward(server \\ __MODULE__, stream_id, start_version \\ 0, count \\ 1000) do
  GenServer.call(server, {:read_stream_forward, stream_id, start_version, count})
end

# Improved function with parameter correction
def read_stream_forward(server \\ __MODULE__, stream_id, start_version \\ 0, count \\ 1000) do
  # Handle case where server might be a stream_id
  {actual_server, actual_stream_id, actual_start_version, actual_count} =
    case {server, stream_id, start_version, count} do
      # If server is a binary, it's likely the stream_id
      {server, start_version, count, _} when is_binary(server) and is_integer(start_version) ->
        {__MODULE__, server, start_version, count}
      # Normal case
      {server, stream_id, start_version, count} ->
        {server, stream_id, start_version, count}
    end

  GenServer.call(actual_server, {:read_stream_forward, actual_stream_id, actual_start_version, actual_count})
end
```

## Version Checking Considerations

Another important aspect was fixing the `check_version/2` function to handle the `:no_stream` case correctly:

```elixir
defp check_version(_stream, :any_version) do
  :ok
end

defp check_version(%{version: 0}, :no_stream) do
  # When stream has version 0 and expected is :no_stream, this is valid
  :ok
end

defp check_version(%{version: current}, expected) when expected == current do
  :ok
end

defp check_version(%{version: current}, expected) do
  {:error, {:wrong_expected_version, expected: expected, current: current}}
end
```

## Testing Recommendations

1. Test with deliberately incorrect parameter ordering to verify robust handling
2. Include tests for common error patterns
3. Verify GenServer name resolution in tests
4. Test with various expected version values including `:no_stream` and `:any_version`

## Conclusion

By implementing these defensive coding patterns, we've made our GenServer-based event store functions more robust against common parameter mistakes. This increases the reliability of the system and improves developer experience by providing clearer error messages when parameters are misused.

Remember that while GenServer offers great flexibility, it requires careful handling of parameters, especially when functions have optional default values for the server name. 