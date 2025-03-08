defmodule GameBot.Domain.Events.EventSerializerMapImpl do
  @moduledoc """
  Implementation of the EventSerializer protocol for Map type.
  This allows maps to be used with the from_map/1 function, which is useful for tests.
  """

  alias GameBot.Domain.Events.{EventSerializer, EventStructure}

  # Implement EventSerializer for Map
  defimpl EventSerializer, for: Map do
    @doc """
    When using from_map with a Map, we need this special implementation
    to handle it properly for tests.

    This is a passthrough implementation that simply returns the original map.
    """
    def to_map(map) do
      # For to_map, we just return the map itself since it's already a map
      map
    end

    @doc """
    When dealing with maps directly in from_map, this handles conversion.
    This is primarily used in testing when we want to validate error cases
    without creating an actual struct instance first.
    """
    def from_map(data) do
      # Check timestamp format if present
      if Map.has_key?(data, "timestamp") do
        case data["timestamp"] do
          timestamp when is_binary(timestamp) ->
            case DateTime.from_iso8601(timestamp) do
              {:ok, _, _} -> :ok
              _ -> raise RuntimeError, "Invalid timestamp format: #{timestamp}"
            end
          _ -> :ok
        end
      end

      # Check mode if present
      if Map.has_key?(data, "mode") do
        case data["mode"] do
          mode when is_binary(mode) ->
            try do
              String.to_existing_atom(mode)
            rescue
              ArgumentError -> raise ArgumentError, "Invalid mode: #{mode}"
            end
          _ -> :ok
        end
      end

      # Return the data itself
      data
    end
  end
end
