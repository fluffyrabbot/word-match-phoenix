# Process Termination Issues in Test Suite

This document analyzes the process termination issues that occur during test execution and provides recommended solutions.

## Issue 1: `GameBot.Domain.Events.Cache` KeyError

### Problem Description
The `GameBot.Domain.Events.Cache` GenServer is terminating with a `KeyError` (key `:id` not found) during tests.

### Root Cause Analysis
From examining the code:

1. The `Events.Cache` module expects events to have an `id` field:
   ```elixir
   @impl true
   def handle_cast({:cache, event}, state) do
     expires_at = System.system_time(:millisecond) + @ttl
     :ets.insert(@table_name, {event.id, {event, expires_at}})
     {:noreply, state}
   end
   ```

2. When an event without an `id` field is passed to `cache_event/1`, the process crashes with a `KeyError`.

3. The most likely scenarios causing this:
   - Test events are being created without proper ID fields
   - Schemas for some event types don't have mandatory ID fields
   - Test setup is trying to cache incompatible objects

### Solution Recommendations

1. **Defensive Coding in Cache Module**:
   ```elixir
   def handle_cast({:cache, event}, state) do
     case get_event_id(event) do
       {:ok, id} ->
         expires_at = System.system_time(:millisecond) + @ttl
         :ets.insert(@table_name, {id, {event, expires_at}})
         {:noreply, state}
       {:error, reason} ->
         Logger.warning("Failed to cache event: #{inspect(reason)}")
         {:noreply, state}
     end
   end
   
   defp get_event_id(event) do
     cond do
       is_map(event) && Map.has_key?(event, :id) -> {:ok, event.id}
       is_map(event) && Map.has_key?(event, "id") -> {:ok, event["id"]}
       is_map(event) && Map.has_key?(event, :event_id) -> {:ok, event.event_id}
       true -> {:error, {:missing_id, event}}
     end
   end
   ```

2. **Ensure Consistent Event Structures**:
   - Review all event modules to ensure they have consistent ID fields
   - Add validation to event creation to prevent ID-less events

3. **Test Environment Setup**:
   - In test setups, skip caching or mock the cache service
   - Ensure all test events have valid ID fields

## Issue 2: `GameBot.TestEventStore.append_to_stream/3` Undefined Function

### Problem Description
Tests are failing with "undefined function" errors for `GameBot.TestEventStore.append_to_stream/3`.

### Root Cause Analysis

1. Examining the `TestEventStore` module shows that it implements `append_to_stream/4` and `append_to_stream/5`, but not `append_to_stream/3`:
   ```elixir
   @impl EventStore
   def append_to_stream(server, stream_id, expected_version, events, opts \\ []) do
     EventStoreCore.append_to_stream(server, stream_id, expected_version, events)
   end
   ```

2. The underlying `EventStoreCore.append_to_stream/4` expects four arguments:
   ```elixir
   def append_to_stream(server \\ __MODULE__, stream_id, expected_version, events) do
     GenServer.call(server, {:append_to_stream, stream_id, expected_version, events, []})
   end
   ```

3. Some tests appear to be calling a 3-parameter version that doesn't exist.

### Solution Recommendations

1. **Add Compatibility Function**:
   ```elixir
   # For backward compatibility with code using the 3-argument version
   def append_to_stream(stream_id, expected_version, events) do
     append_to_stream(__MODULE__, stream_id, expected_version, events)
   end
   ```

2. **Update Test Cases**:
   - Identify and update tests calling the 3-argument version
   - Modify test cases to use the proper 4-argument signature
   - Consider adding a function to the test helpers to standardize event store calls

3. **Consistent Interface Design**:
   - Ensure all event store adapters have consistent function signatures
   - Document the expected parameter order and meaning

## General Testing Recommendations

1. **Mock Service for Tests**:
   - Create separate mock versions of `Events.Cache` and `TestEventStore` specifically for tests
   - These versions should be more tolerant of test data

2. **Test Setup Improvements**:
   - Add explicit cache and event store reset steps to test setup
   - Implement better isolation between test cases

3. **Process Supervision in Tests**:
   - Modify the test supervision tree to restart crashed processes
   - Add process monitoring to detect and report terminations during tests

4. **Improved Error Reporting**:
   - Add specific test assertions to check process aliveness
   - Include detailed crash reports in test output

By addressing these issues, the test suite will become more reliable and easier to maintain. 