# Serializer Implementation Squashing Guide

## Current Implementation Analysis

The current serialization system consists of multiple modules handling event serialization in the GameBot system:

### 1. Primary Implementation
**Module**: `GameBot.Infrastructure.Persistence.EventStore.Serialization.JsonSerializer`

This is the full implementation with comprehensive functionality:
- Implements the `GameBot.Infrastructure.Persistence.EventStore.Serialization.Behaviour` interface
- Provides JSON serialization with version tracking
- Handles type validation and error handling
- Preserves metadata
- Supports optional migration
- Integrates with an event registry
- Contains numerous helper functions for handling different event types:
  - `validate_event/1` - Validates that events have the required type and version
  - `get_event_type_if_available/1` - Extracts type from various event formats
  - `get_event_version_if_available/1` - Extracts version from various event formats
  - `get_event_type/1` - Gets type or raises error
  - `get_event_version/1` - Gets version or uses default
  - `encode_event/1` - Converts event to serializable format
  - `encode_timestamps/1` - Converts DateTime objects to ISO-8601 strings
  - `lookup_event_module/1` - Finds module for event type
  - `decode_event/1` - Converts serialized data back to event format
  - `decode_timestamps/1` - Converts ISO-8601 strings back to DateTime objects
  - `create_event/3` - Creates an event struct from data and metadata
  - `get_registry/0` - Gets the event registry to use

### 2. Alias Module
**Module**: `GameBot.Infrastructure.Persistence.EventStore.JsonSerializer`

This module delegates to the primary implementation while providing a simplified interface:
- Maintains compatibility with the original Serializer module
- Contains only basic functionality (serialize/deserialize/event_version)
- Wraps error types with simplified PersistenceError
- Handles the second parameter in deserialize/2 but doesn't use it
- Delegates other functions directly to the implementation

Key functions:
- `serialize/1` - Calls Implementation.serialize/1 but simplifies errors
- `deserialize/2` - Adds an unused event_module parameter for compatibility
- `event_version/1` - Hardcoded support for specific event types

### 3. Legacy Module
**Module**: `GameBot.Infrastructure.Persistence.EventStore.Serializer`

This is a deprecated module that now forwards to the JsonSerializer alias:
- Marked as deprecated in documentation
- Simple delegation of all functions to JsonSerializer
- No additional functionality

### 4. Second Alias Module (Redundant)
**Module**: `GameBot.Infrastructure.Persistence.EventStore.Serializer.Alias`

This module is redundant, mirroring what the Legacy Module already does:
- Has almost identical functionality to the Serializer module
- Both delegate to JsonSerializer
- Creates unnecessary confusion about which module to use

### 5. Behaviour Definition
**Module**: `GameBot.Infrastructure.Persistence.EventStore.Serialization.Behaviour`

This module defines the contract that serializers must implement:
- `serialize/2` - Converts events to storage format
- `deserialize/2` - Converts storage format back to events
- `version/0` - Returns the serializer version
- `validate/2` - Validates serialized data
- `migrate/4` - Migrates between versions (optional)

## Current Issues

1. **Namespace Confusion**: Multiple modules with similar names in different namespaces
2. **Redundancy**: Some modules only forward to others with no added functionality
3. **Inconsistent Parameter Handling**: 
   - `deserialize/1` vs. `deserialize/2`
   - Options parameters not fully utilized
4. **Error Context Loss**: Detailed error information gets simplified in the delegation chain
5. **Underutilization of Options**: Some functions accept options but don't pass them through
6. **Special Case Handling**: Hardcoded handling for specific event types across modules
7. **Testing Complexity**: Multiple modules make testing more complicated

## Squashing Implementation

### Approach

We will create a single module that combines all functionality while maintaining backward compatibility.

### Step 1: Create Unified Module

Replace the existing modules with a single module at:
`GameBot.Infrastructure.Persistence.EventStore.Serializer`

### Step 2: Implement Public API with Feature Flags

```elixir
defmodule GameBot.Infrastructure.Persistence.EventStore.Serializer do
  @moduledoc """
  Unified JSON serializer for domain events.
  
  This module provides a single entry point for event serialization in the GameBot system,
  combining functionality from previous implementations while maintaining compatibility.
  
  ## Features
  - JSON serialization with version tracking
  - Type validation and error handling
  - Metadata preservation
  - Optional migration support
  - Event registry integration
  
  ## Backwards Compatibility
  This module replaces:
  - GameBot.Infrastructure.Persistence.EventStore.Serialization.JsonSerializer
  - GameBot.Infrastructure.Persistence.EventStore.JsonSerializer
  - GameBot.Infrastructure.Persistence.EventStore.Serializer
  - GameBot.Infrastructure.Persistence.EventStore.Serializer.Alias
  """
  
  alias GameBot.Infrastructure.Error
  alias GameBot.Infrastructure.ErrorHelpers
  alias GameBot.Domain.Events.EventRegistry
  alias GameBot.Infrastructure.Persistence.Error, as: PersistenceError
  
  @behaviour GameBot.Infrastructure.Persistence.EventStore.Serialization.Behaviour
  
  @current_version 1
  require Logger
  
  @type event_type :: String.t()
  @type event_version :: pos_integer()
  
  #
  # Public API
  #
  
  @doc """
  Serializes an event into a format suitable for storage.
  
  ## Parameters
    * `event` - The event to serialize
    * `opts` - Optional parameters:
      * `:preserve_error_context` - When true, maintains original error details (default: false)
      * Any other options are passed to the implementation
  
  ## Returns
    * `{:ok, serialized}` - Successfully serialized event
    * `{:error, reason}` - Failed to serialize event
  
  ## Examples
      iex> Serializer.serialize(%MyEvent{field: "value"})
      {:ok, %{"type" => "my_event", "version" => 1, "data" => %{"field" => "value"}, "metadata" => %{}}}
  """
  @spec serialize(map() | struct(), keyword()) :: {:ok, map()} | {:error, term()}
  def serialize(event, opts \\ []) do
    preserve_error_context = Keyword.get(opts, :preserve_error_context, false)
    
    result = do_serialize(event, opts)
    
    if preserve_error_context do
      result
    else
      # For backward compatibility, simplify error
      case result do
        {:ok, data} -> {:ok, data}
        {:error, _} -> {:error, %PersistenceError{type: :validation}}
      end
    end
  end
  
  @doc """
  Deserializes an event from storage format.
  
  ## Parameters
    * `data` - The serialized event data
    * `event_module` - Optional module to deserialize into (ignored in favor of lookup)
    * `opts` - Optional parameters:
      * `:preserve_error_context` - When true, maintains original error details (default: false)
      * Any other options are passed to the implementation
  
  ## Returns
    * `{:ok, event}` - Successfully deserialized event
    * `{:error, reason}` - Failed to deserialize event
  
  ## Examples
      iex> Serializer.deserialize(%{"type" => "my_event", "version" => 1, "data" => %{"field" => "value"}, "metadata" => %{}})
      {:ok, %MyEvent{field: "value", metadata: %{}}}
  """
  @spec deserialize(map(), module() | nil, keyword()) :: {:ok, struct() | map()} | {:error, term()}
  def deserialize(data, event_module \\ nil, opts \\ []) do
    preserve_error_context = Keyword.get(opts, :preserve_error_context, false)
    
    # Pass event_module in opts if provided (for potential future use)
    opts = if event_module, do: Keyword.put(opts, :event_module, event_module), else: opts
    
    result = do_deserialize(data, opts)
    
    if preserve_error_context do
      result
    else
      # For backward compatibility, simplify error
      case result do
        {:ok, deserialized} -> {:ok, deserialized}
        {:error, _} -> {:error, %PersistenceError{type: :validation}}
      end
    end
  end
  
  @doc """
  Gets the current version for an event type.
  
  This is a legacy function that provides compatibility with older code.
  
  ## Parameters
    * `event_type` - The string identifying the event type
  
  ## Returns
    * `{:ok, version}` - Successfully retrieved version
    * `{:error, reason}` - Failed to retrieve version
  """
  @spec event_version(String.t()) :: {:ok, integer()} | {:error, PersistenceError.t()}
  def event_version(event_type) do
    # Special cases for backward compatibility
    if event_type in ["game_started", "test_event"] do
      {:ok, 1}
    else
      {:error, %PersistenceError{type: :validation}}
    end
  end
  
  @impl true
  def version, do: @current_version
  
  @impl true
  def validate(data, opts \\ []) do
    cond do
      not is_map(data) ->
        {:error, Error.validation_error(__MODULE__, "Data must be a map", data)}
      is_nil(data["type"]) ->
        {:error, Error.validation_error(__MODULE__, "Missing event type", data)}
      is_nil(data["version"]) ->
        {:error, Error.validation_error(__MODULE__, "Missing event version", data)}
      is_nil(data["data"]) ->
        {:error, Error.validation_error(__MODULE__, "Missing event data", data)}
      not is_map(data["metadata"]) ->
        {:error, Error.validation_error(__MODULE__, "Metadata must be a map", data)}
      true ->
        :ok
    end
  end
  
  @impl true
  def migrate(data, from_version, to_version, opts \\ []) do
    cond do
      from_version == to_version ->
        {:ok, data}
      from_version > to_version ->
        {:error, Error.validation_error(__MODULE__, "Cannot migrate to older version", %{
          from: from_version,
          to: to_version
        })}
      true ->
        case get_registry().migrate_event(data["type"], data, from_version, to_version) do
          {:ok, migrated} -> {:ok, migrated}
          {:error, reason} ->
            {:error, Error.validation_error(__MODULE__, "Version migration failed", %{
              from: from_version,
              to: to_version,
              reason: reason
            })}
        end
    end
  end
  
  # Legacy compatibility aliases
  defdelegate from_map(data), to: __MODULE__, as: :deserialize
  defdelegate to_map(event), to: __MODULE__, as: :serialize
  
  #
  # Implementation Functions
  #
  
  # The actual implementation of serialize, now a private function
  defp do_serialize(event, opts) do
    ErrorHelpers.wrap_error(
      fn ->
        with :ok <- validate_event(event),
             {:ok, data} <- encode_event(event) do
          # Create result map with string keys for better compatibility
          result = %{
            "type" => get_event_type(event),
            "version" => get_event_version(event),
            "data" => data,
            "metadata" => Map.get(event, :metadata, %{})
          }

          # Preserve stream_id if it exists (primarily for testing)
          result = if Map.has_key?(event, :stream_id) do
            Map.put(result, "stream_id", Map.get(event, :stream_id))
          else
            result
          end

          {:ok, result}
        end
      end,
      __MODULE__
    )
  end
  
  # The actual implementation of deserialize, now a private function
  defp do_deserialize(data, opts) do
    ErrorHelpers.wrap_error(
      fn ->
        with :ok <- validate(data),
             {:ok, event_module} <- lookup_event_module(data["type"]),
             {:ok, event_data} <- decode_event(data["data"]) do
          if event_module == nil do
            # For test events, return the original data with decoded fields
            {:ok, Map.merge(data, %{"data" => event_data})}
          else
            # For regular events, create the event struct
            create_event(event_module, event_data, data["metadata"])
          end
        end
      end,
      __MODULE__
    )
  end
  
  # Implementation of private helpers - copied from JsonSerializer
  
  defp validate_event(event) do
    cond do
      # Support for plain maps with 'type' and 'version' keys (used primarily in tests)
      is_map(event) and not is_struct(event) and Map.has_key?(event, :type) and Map.has_key?(event, :version) ->
        :ok
      # Support for plain maps with event_type and event_version keys
      is_map(event) and not is_struct(event) and Map.has_key?(event, :event_type) and Map.has_key?(event, :event_version) ->
        :ok
      # Add support for string keys (primarily for tests)
      is_map(event) and not is_struct(event) and (
        (Map.has_key?(event, "type") and Map.has_key?(event, "version")) or
        (Map.has_key?(event, "event_type") and Map.has_key?(event, "event_version"))
      ) ->
        :ok
      # Original struct validation
      is_struct(event) ->
        if is_nil(get_event_type_if_available(event)) or is_nil(get_event_version_if_available(event)) do
          {:error, Error.validation_error(__MODULE__, "Event must implement event_type/0 and event_version/0", event)}
        else
          :ok
        end
      true ->
        {:error, Error.validation_error(__MODULE__, "Event must be a struct or a map with required type keys", event)}
    end
  end

  defp get_event_type_if_available(event) do
    cond do
      # For plain maps with :type
      is_map(event) and not is_struct(event) and Map.has_key?(event, :type) ->
        Map.get(event, :type)
      # For plain maps with event_type
      is_map(event) and not is_struct(event) and Map.has_key?(event, :event_type) ->
        Map.get(event, :event_type)
      # For plain maps with string keys (test events)
      is_map(event) and not is_struct(event) and Map.has_key?(event, "type") ->
        Map.get(event, "type")
      # For plain maps with string event_type
      is_map(event) and not is_struct(event) and Map.has_key?(event, "event_type") ->
        Map.get(event, "event_type")
      # For structs with event_type/0 function
      function_exported?(event.__struct__, :event_type, 0) ->
        event.__struct__.event_type()
      # For registry lookup
      function_exported?(get_registry(), :event_type_for, 1) ->
        get_registry().event_type_for(event)
      true ->
        nil
    end
  end

  defp get_event_version_if_available(event) do
    cond do
      # For plain maps with :version
      is_map(event) and not is_struct(event) and Map.has_key?(event, :version) ->
        Map.get(event, :version)
      # For plain maps with event_version
      is_map(event) and not is_struct(event) and Map.has_key?(event, :event_version) ->
        Map.get(event, :event_version)
      # For plain maps with string keys (test events)
      is_map(event) and not is_struct(event) and Map.has_key?(event, "version") ->
        Map.get(event, "version")
      # For plain maps with string event_version
      is_map(event) and not is_struct(event) and Map.has_key?(event, "event_version") ->
        Map.get(event, "event_version")
      # For structs with event_version/0 function
      function_exported?(event.__struct__, :event_version, 0) ->
        event.__struct__.event_version()
      # For registry lookup
      function_exported?(get_registry(), :event_version_for, 1) ->
        get_registry().event_version_for(event)
      true ->
        nil
    end
  end

  defp get_event_type(event) do
    case get_event_type_if_available(event) do
      nil ->
        if is_struct(event) do
          raise "Event type not found for struct: #{inspect(event.__struct__)}.  Implement event_type/0 or register the event."
        else
          raise "Event type not found for map. Include :event_type key."
        end
      type ->
        type
    end
  end

  defp get_event_version(event) do
    version = get_event_version_if_available(event)

    if is_nil(version), do: @current_version, else: version
  end

  defp encode_event(event) do
    try do
      data = cond do
        # For plain maps with 'data' field (test events)
        is_map(event) and not is_struct(event) and Map.has_key?(event, :data) ->
          Map.get(event, :data)
        # For structs with to_map/1
        function_exported?(event.__struct__, :to_map, 1) ->
          result = event.__struct__.to_map(event)
          if is_nil(result), do: raise("Event to_map returned nil for #{inspect(event.__struct__)}")
          result
        # For registry lookup
        function_exported?(get_registry(), :encode_event, 1) ->
          result = get_registry().encode_event(event)
          # Return error if registry encoder returns nil
          if is_nil(result) do
            raise "Registry encoder returned nil for event #{inspect(event.__struct__)}"
          end
          result
        # For structs, convert to map
        true ->
          event
          |> Map.from_struct()
          |> Map.drop([:__struct__, :metadata])
          |> encode_timestamps()
      end

      if is_nil(data) do
        {:error, Error.serialization_error(__MODULE__, "Event encoder returned nil data", event)}
      else
        {:ok, data}
      end
    rescue
      e ->
        {:error, Error.serialization_error(__MODULE__, "Failed to encode event: #{inspect(e)}", %{
          error: e,
          event: event
        })}
    end
  end

  defp encode_timestamps(data) when is_map(data) do
    Enum.map(data, fn
      {k, %DateTime{} = v} -> {k, DateTime.to_iso8601(v)}
      {k, v} when is_map(v) -> {k, encode_timestamps(v)}
      pair -> pair
    end)
    |> Map.new()
  end

  defp lookup_event_module(type) do
    # Special case for test_event - bypass the registry
    if type == "test_event" do
      {:ok, nil}  # Return nil for test events, which will be handled as plain maps
    else
      case get_registry().module_for_type(type) do
        {:ok, module} -> {:ok, module}
        {:error, _} -> {:error, Error.not_found_error(__MODULE__, "Unknown event type", type)}
      end
    end
  end

  defp decode_event(data) do
    if is_map(data) do
      {:ok, decode_timestamps(data)}
    else
      {:error, Error.validation_error(__MODULE__, "Event data must be a map", data)}
    end
  end

  defp decode_timestamps(data) when is_map(data) do
    Enum.map(data, fn
      {k, v} when is_binary(v) ->
        case DateTime.from_iso8601(v) do
          {:ok, datetime, _} -> {k, datetime}
          _ -> {k, v}
        end
      {k, v} when is_map(v) -> {k, decode_timestamps(v)}
      pair -> pair
    end)
    |> Map.new()
  end

  defp create_event(module, data, metadata) do
    try do
      event = cond do
        function_exported?(module, :from_map, 1) ->
          module.from_map(data)
        function_exported?(get_registry(), :decode_event, 2) ->
          get_registry().decode_event(module, data)
        true ->
          struct(module, data)
      end

      {:ok, Map.put(event, :metadata, metadata)}
    rescue
      e ->
        {:error, Error.serialization_error(__MODULE__, "Failed to create event", %{
          error: e,
          module: module,
          data: data
        })}
    end
  end

  # Get the event registry to use - allows for overriding in tests
  defp get_registry do
    Application.get_env(:game_bot, :event_registry, EventRegistry)
  end
end
```

### Step 3: Create a Module Alias for Backward Compatibility

Create a file at `lib/game_bot/infrastructure/persistence/event_store/serialization/json_serializer.ex` with:

```elixir
defmodule GameBot.Infrastructure.Persistence.EventStore.Serialization.JsonSerializer do
  @moduledoc """
  DEPRECATED: This module has been merged into GameBot.Infrastructure.Persistence.EventStore.Serializer.
  
  This alias exists for backward compatibility.
  All functionality now lives in GameBot.Infrastructure.Persistence.EventStore.Serializer.
  """
  
  @deprecated "Use GameBot.Infrastructure.Persistence.EventStore.Serializer instead"
  
  defdelegate serialize(event, opts \\ []), to: GameBot.Infrastructure.Persistence.EventStore.Serializer
  defdelegate deserialize(data, opts \\ []), to: GameBot.Infrastructure.Persistence.EventStore.Serializer
  defdelegate validate(data, opts \\ []), to: GameBot.Infrastructure.Persistence.EventStore.Serializer
  defdelegate migrate(data, from_version, to_version, opts \\ []), to: GameBot.Infrastructure.Persistence.EventStore.Serializer
  defdelegate version(), to: GameBot.Infrastructure.Persistence.EventStore.Serializer
end
```

### Step 4: Create a Module Alias for JsonSerializer

Create a file at `lib/game_bot/infrastructure/persistence/event_store/json_serializer.ex` with:

```elixir
defmodule GameBot.Infrastructure.Persistence.EventStore.JsonSerializer do
  @moduledoc """
  DEPRECATED: This module has been merged into GameBot.Infrastructure.Persistence.EventStore.Serializer.
  
  This alias exists for backward compatibility.
  All functionality now lives in GameBot.Infrastructure.Persistence.EventStore.Serializer.
  """
  
  @deprecated "Use GameBot.Infrastructure.Persistence.EventStore.Serializer instead"
  
  defdelegate serialize(event, opts \\ []), to: GameBot.Infrastructure.Persistence.EventStore.Serializer
  defdelegate deserialize(data, event_module \\ nil, opts \\ []), to: GameBot.Infrastructure.Persistence.EventStore.Serializer
  defdelegate event_version(event_type), to: GameBot.Infrastructure.Persistence.EventStore.Serializer
  defdelegate validate(data, opts \\ []), to: GameBot.Infrastructure.Persistence.EventStore.Serializer
  defdelegate migrate(data, from_version, to_version, opts \\ []), to: GameBot.Infrastructure.Persistence.EventStore.Serializer
  defdelegate version(), to: GameBot.Infrastructure.Persistence.EventStore.Serializer
end
```

## Migration Plan

### Phase 1: Implement Unified Serializer (2-3 hours)
1. Create the new unified `Serializer` module
2. Create the legacy alias modules
3. Run tests to ensure compatibility
4. Fix any test failures related to compatibility issues

### Phase 2: Update Tests (1-2 hours)
1. Update test files that use unqualified module names
2. Add aliases where needed
3. Run tests to ensure all pass
4. Add tests specifically for the new feature flags (preserve_error_context)

### Phase 3: Delete Redundant Module (30 minutes)
1. Delete the `Serializer.Alias` module
2. Update any code that directly references it
3. Update documentation to remove references to it

### Phase 4: Update Documentation (1 hour)
1. Update documentation to reference the new unified module
2. Add deprecation notes for the old modules
3. Create a migration guide for teams using the old modules

### Phase 5: Gradual Migration (2-4 weeks)
1. Update code that directly references the old modules
2. Use the new unified module in all new code
3. After a predetermined time, consider removing the alias modules

## Benefits of Unified Approach

1. **Simplicity**: One source of truth for serialization logic
2. **Maintainability**: Easier to update and maintain a single implementation
3. **Consistency**: All serialization follows the same patterns
4. **Performance**: Eliminates unnecessary delegation between modules
5. **Feature Completeness**: All functionality in one place with proper documentation
6. **Error Handling**: Improved error context preservation with opt-in feature
7. **Testing**: Easier to test with a single module

## Potential Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Breaking existing tests | Create comprehensive tests before implementation |
| Missing edge cases | Review all existing tests to identify edge cases |
| Performance impact | Measure performance before and after |
| Expanded module size | Organize with clear sections and documentation |
| Unexpected behavior changes | Use feature flags for compatibility |
| Import conflicts | Use fully qualified names in edge cases |

## Important Edge Cases to Consider

1. **Test Events**: The current implementation has special handling for `test_event` type events.
2. **Error Context**: The simplified error handling in aliases vs. detailed errors in implementation.
3. **Multiple Parameter Signatures**: `deserialize/1` vs `deserialize/2` with different parameter expectations.
4. **Timestamp Handling**: Special handling for DateTime objects in event data.
5. **Stream ID Preservation**: Special handling to preserve stream_id for testing.
6. **Registry Integration**: Various fallbacks to registry for handling events.

## Conclusion

By squashing the serializer implementations into a single file, we maintain all existing functionality while simplifying the codebase. The unified approach provides a clear path forward for maintaining and extending the serialization logic.

The solution preserves backward compatibility through:
1. Feature flags for detailed error handling
2. Support for all existing function signatures
3. Special case handling for test events
4. Temporary alias modules during migration

This approach gives us the benefits of simplified architecture without disrupting existing code. 