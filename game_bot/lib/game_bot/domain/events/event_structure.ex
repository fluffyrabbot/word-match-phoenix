defmodule GameBot.Domain.Events.EventStructure do
  @moduledoc """
  Defines standard structure and requirements for all events in the GameBot system.

  This module provides:
  - Base field definitions that should be present in all events
  - Type specifications for common event structures
  - Validation functions to ensure event consistency
  - Helper functions for creating and manipulating events
  - Serialization and deserialization of event data with support for complex types
  """

  alias GameBot.Domain.Events.Metadata

  # Base fields that should be present in all events
  @base_fields [:game_id, :guild_id, :mode, :round_number, :timestamp, :metadata]

  @typedoc """
  Metadata structure for events to ensure proper tracking and correlation.
  """
  @type metadata :: Metadata.t()

  @typedoc """
  Standard structure for team information in events.
  """
  @type team_info :: %{
    required(:team_id) => String.t(),
    required(:name) => String.t(),
    required(:players) => [String.t()]
  }

  @typedoc """
  Standard structure for player information in events.
  """
  @type player_info :: %{
    required(:player_id) => String.t(),
    optional(:name) => String.t(),
    optional(:role) => atom()
  }

  @doc """
  Returns the list of base fields required for all events.
  """
  def base_fields, do: @base_fields

  @doc """
  Validates that an event contains all required base fields.
  """
  def validate_base_fields(event) do
    Enum.find_value(@base_fields, :ok, fn field ->
      if Map.get(event, field) == nil do
        {:error, "#{field} is required"}
      else
        false
      end
    end)
  end

  @doc """
  Validates that an event's metadata is valid.
  """
  def validate_metadata(event) do
    with %{metadata: metadata} <- event,
         true <- is_map(metadata) do
      if Map.has_key?(metadata, "guild_id") or Map.has_key?(metadata, :guild_id) or
         Map.has_key?(metadata, "source_id") or Map.has_key?(metadata, :source_id) do
        :ok
      else
        {:error, "guild_id or source_id is required in metadata"}
      end
    else
      _ -> {:error, "invalid metadata format"}
    end
  end

  @doc """
  Creates a timestamp for an event, defaulting to current UTC time.
  """
  def create_timestamp, do: DateTime.utc_now()

  @doc """
  Creates a base event map with all required fields.

  ## Parameters
  - game_id: Unique identifier for the game
  - guild_id: Discord guild ID
  - mode: Game mode (atom)
  - metadata: Event metadata
  - opts: Optional parameters
    - round_number: Round number (defaults to 1)
    - timestamp: Event timestamp (defaults to current time)
  """
  def create_event_map(game_id, guild_id, mode, metadata, opts \\ []) do
    round_number = Keyword.get(opts, :round_number, 1)
    timestamp = Keyword.get(opts, :timestamp, create_timestamp())

    %{
      game_id: game_id,
      guild_id: guild_id,
      mode: mode,
      round_number: round_number,
      timestamp: timestamp,
      metadata: metadata
    }
  end

  @doc """
  Creates a base event map with all required fields, including optional fields.

  More flexible version of create_event_map that allows for additional fields.
  """
  def create_base_event(fields, metadata) do
    fields
    |> Map.put(:timestamp, create_timestamp())
    |> Map.put(:metadata, metadata)
  end

  @doc """
  Validates an event to ensure it meets the standard requirements.

  Performs both base field validation and metadata validation.
  Also performs mode-specific validation when applicable.
  """
  def validate(event) do
    with :ok <- validate_base_fields(event),
         :ok <- validate_metadata(event),
         :ok <- validate_mode_specific(event) do
      :ok
    end
  end

  @doc """
  Validates the required fields of an event against a list.

  Returns :ok if all fields are present, or an error with the missing field.
  """
  def validate_fields(event, required_fields) do
    Enum.find_value(required_fields, :ok, fn field ->
      if Map.get(event, field) == nil do
        {:error, "#{field} is required"}
      else
        false
      end
    end)
  end

  @doc """
  Validates that field values have the correct types.

  Takes a map of field names to type-checking functions.
  """
  def validate_types(event, field_types) do
    Enum.find_value(field_types, :ok, fn {field, type_check} ->
      value = Map.get(event, field)
      if value != nil and not type_check.(value) do
        {:error, "#{field} has invalid type"}
      else
        false
      end
    end)
  end

  @doc """
  Parses a timestamp string into a DateTime struct.

  Raises an error if the timestamp is invalid.
  """
  def parse_timestamp(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, datetime, _offset} -> datetime
      {:error, reason} -> raise "Invalid timestamp format: #{reason}"
    end
  end

  @doc """
  Serializes a map or struct for storage by converting complex types to serializable formats.

  Handles:
  - DateTime objects (converts to ISO8601 strings)
  - MapSet objects (converts to maps with special markers)
  - Nested maps (recursively processes all values)
  - Lists (recursively processes all items)
  - Structs (converts to maps with type information)

  ## Parameters
  - data: The data to serialize (map, struct, or other value)

  ## Returns
  - The serialized data suitable for storage
  """
  @spec serialize(any()) :: any()
  def serialize(data) when is_struct(data, DateTime) do
    DateTime.to_iso8601(data)
  end

  def serialize(data) when is_struct(data, MapSet) do
    %{
      "__mapset__" => true,
      "items" => MapSet.to_list(data)
    }
  end

  def serialize(data) when is_struct(data) do
    # Convert struct to a map, stringify keys, and add type information
    data
    |> Map.from_struct()
    |> Enum.map(fn {k, v} -> {to_string(k), serialize(v)} end)
    |> Map.new()
    |> Map.put("__struct__", data.__struct__ |> to_string())
  end

  def serialize(data) when is_map(data) do
    # Process each key-value pair recursively
    Enum.map(data, fn {k, v} -> {k, serialize(v)} end)
    |> Map.new()
  end

  def serialize(data) when is_list(data) do
    # Process each item in the list recursively
    Enum.map(data, &serialize/1)
  end

  def serialize(data), do: data

  @doc """
  Deserializes data from storage format back to its original format.

  Handles:
  - ISO8601 strings (converts to DateTime objects)
  - MapSet markers (converts back to MapSet)
  - Nested maps (recursively processes all values)
  - Lists (recursively processes all items)
  - Structs (attempts to restore original struct type)

  ## Parameters
  - data: The serialized data to deserialize

  ## Returns
  - The deserialized data with complex types restored
  """
  @spec deserialize(any()) :: any()
  def deserialize(%{"__mapset__" => true, "items" => items}) when is_list(items) do
    MapSet.new(deserialize(items))
  end

  def deserialize(%{"__struct__" => struct_name} = data) when is_binary(struct_name) do
    # Try to convert back to the original struct
    try do
      module = String.to_existing_atom(struct_name)

      # Remove the struct marker and deserialize values
      data = Map.delete(data, "__struct__")
      deserialized_data = deserialize(data)

      # Create struct from deserialized data
      struct(module, deserialized_data)
    rescue
      # If module doesn't exist or any other error, return as map
      _ ->
        data
        |> Map.delete("__struct__")
        |> deserialize()
    end
  end

  def deserialize(data) when is_map(data) do
    # Process each key-value pair recursively
    Enum.map(data, fn {k, v} -> {k, deserialize(v)} end)
    |> Map.new()
  end

  def deserialize(data) when is_list(data) do
    # Process each item in the list recursively
    Enum.map(data, &deserialize/1)
  end

  def deserialize(data) when is_binary(data) do
    # Try to parse ISO8601 datetime strings
    if Regex.match?(~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, data) do
      try do
        case DateTime.from_iso8601(data) do
          {:ok, datetime, _} -> datetime
          _ -> data
        end
      rescue
        _ -> data
      end
    else
      data
    end
  end

  def deserialize(data), do: data

  # Private functions for mode-specific validation

  defp validate_mode_specific(%{mode: :two_player} = event) do
    case Code.ensure_loaded?(GameBot.Domain.GameModes.TwoPlayerMode) and
         function_exported?(GameBot.Domain.GameModes.TwoPlayerMode, :validate_event, 1) do
      true -> GameBot.Domain.GameModes.TwoPlayerMode.validate_event(event)
      false -> :ok
    end
  end

  defp validate_mode_specific(%{mode: :knockout} = event) do
    case Code.ensure_loaded?(GameBot.Domain.GameModes.KnockoutMode) and
         function_exported?(GameBot.Domain.GameModes.KnockoutMode, :validate_event, 1) do
      true -> GameBot.Domain.GameModes.KnockoutMode.validate_event(event)
      false -> :ok
    end
  end

  defp validate_mode_specific(%{mode: :race} = event) do
    case Code.ensure_loaded?(GameBot.Domain.GameModes.RaceMode) and
         function_exported?(GameBot.Domain.GameModes.RaceMode, :validate_event, 1) do
      true -> GameBot.Domain.GameModes.RaceMode.validate_event(event)
      false -> :ok
    end
  end

  defp validate_mode_specific(_event), do: :ok
end
