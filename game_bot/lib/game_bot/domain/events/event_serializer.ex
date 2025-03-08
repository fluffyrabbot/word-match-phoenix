defprotocol GameBot.Domain.Events.EventSerializer do
  @moduledoc """
  Protocol for serializing and deserializing events in the GameBot system.

  This protocol provides a standard interface for converting events to and from maps
  for storage, ensuring that:
  1. All events can be safely serialized to JSON-compatible maps
  2. All events can be correctly reconstructed from stored data
  3. Complex types (DateTime, MapSet, etc.) are handled properly
  4. Type information is preserved during serialization
  5. Optional fields are handled correctly

  ## Implementation Requirements

  Implementing modules must provide:
  - to_map/1: Convert event struct to a serializable map
  - from_map/1: Reconstruct event struct from a map

  ## Serialization Rules

  1. DateTime fields must be converted to ISO8601 strings
  2. Atoms must be converted to strings
  3. MapSets must be converted to lists
  4. Nested structs must be recursively serialized
  5. Optional fields should be preserved as nil
  6. Type information should be included for proper reconstruction

  ## Example Implementation

  ```elixir
  defimpl EventSerializer, for: MyEvent do
    def to_map(event) do
      %{
        "game_id" => event.game_id,
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "metadata" => event.metadata,
        "score" => event.score,
        "players" => Enum.map(event.players, &to_string/1)
      }
    end

    def from_map(data) do
      %MyEvent{
        game_id: data["game_id"],
        timestamp: EventStructure.parse_timestamp(data["timestamp"]),
        metadata: data["metadata"],
        score: data["score"],
        players: Enum.map(data["players"], &String.to_existing_atom/1)
      }
    end
  end
  ```
  """

  @typedoc """
  Type for serialized event data.
  Must be JSON-compatible and contain all necessary information for reconstruction.
  """
  @type serialized_event :: %{required(String.t()) => term()}

  @doc """
  Converts an event struct to a serializable map.

  This function should:
  1. Convert all fields to JSON-compatible types
  2. Handle complex types appropriately (DateTime, MapSet, etc.)
  3. Preserve type information for reconstruction
  4. Handle optional fields correctly
  5. Maintain field names as strings

  ## Parameters
  - event: The event struct to serialize

  ## Returns
  A map with string keys and JSON-compatible values

  ## Example
  ```elixir
  event = %MyEvent{game_id: "123", timestamp: DateTime.utc_now()}
  serialized = EventSerializer.to_map(event)
  # => %{
  #   "game_id" => "123",
  #   "timestamp" => "2024-03-20T12:34:56Z",
  #   ...
  # }
  ```
  """
  @spec to_map(t) :: serialized_event
  def to_map(event)

  @doc """
  Reconstructs an event struct from a serialized map.

  This function should:
  1. Convert stored data back to appropriate types
  2. Reconstruct complex types (DateTime, MapSet, etc.)
  3. Handle missing optional fields gracefully
  4. Validate data during reconstruction
  5. Preserve field types according to struct definition

  ## Parameters
  - data: The serialized map data

  ## Returns
  The reconstructed event struct

  ## Example
  ```elixir
  data = %{
    "game_id" => "123",
    "timestamp" => "2024-03-20T12:34:56Z",
    ...
  }
  event = EventSerializer.from_map(MyEvent, data)
  # => %MyEvent{game_id: "123", timestamp: ~U[2024-03-20 12:34:56Z], ...}
  ```

  ## Error Handling
  Should raise ArgumentError for invalid data that cannot be properly deserialized.
  """
  @spec from_map(serialized_event()) :: t
  def from_map(data)
end
