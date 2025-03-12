defmodule GameBot.Domain.Events.EventStructure do
  @moduledoc """
  Defines standard structure and requirements for all events in the GameBot system.

  This module provides:
  - Base field definitions that should be present in all events
  - Type specifications for common event structures
  - Validation functions to ensure event consistency
  - Helper functions for creating and manipulating events
  - Serialization and deserialization of event data with support for complex types

  All events must include base fields and follow type specifications defined here.
  See type_specifications.md for comprehensive documentation.
  """

  alias GameBot.Domain.Events.Metadata

  # Base fields that should be present in all events
  @base_fields [:game_id, :guild_id, :mode, :timestamp, :metadata]

  @doc """
  When used, imports common event functionality and sets up the event structure.

  This macro:
  1. Implements the GameEvents behaviour
  2. Imports common validation functions
  3. Sets up base field definitions
  4. Provides default implementations
  5. Imports common types
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour GameBot.Domain.Events.GameEvents

      alias GameBot.Domain.Events.{EventStructure, Metadata}

      # Import functions
      import GameBot.Domain.Events.EventStructure,
        only: [
          validate_base_fields: 1,
          validate_metadata: 1,
          validate_types: 2,
          parse_timestamp: 1,
          create_timestamp: 0,
          create_event_map: 5
        ]

      # Define types
      @type metadata :: Metadata.t()
      @type player_info :: {integer(), String.t(), String.t() | nil}  # {discord_id, username, nickname}
      @type team_info :: %{
        team_id: String.t(),
        player_ids: [String.t()],
        score: integer(),
        matches: non_neg_integer(),
        total_guesses: pos_integer()
      }
      @type player_stats :: %{
        total_guesses: pos_integer(),
        successful_matches: non_neg_integer(),
        abandoned_guesses: non_neg_integer(),
        average_guess_count: float()
      }

      # Default implementations that can be overridden
      @impl true
      def validate(event) do
        with :ok <- validate_base_fields(event),
             :ok <- validate_metadata(event) do
          :ok
        end
      end

      @impl true
      def event_version, do: 1

      defoverridable validate: 1, event_version: 0
    end
  end

  @typedoc """
  Metadata structure for events to ensure proper tracking and correlation.
  Must include either guild_id or source_id for tracking purposes.
  See GameBot.Domain.Events.Metadata for detailed field specifications.
  """
  @type metadata :: Metadata.t()

  @typedoc """
  Standard structure for player information in events.
  Used consistently across all events that reference players.
  """
  @type player_info :: {integer(), String.t(), String.t() | nil}  # {discord_id, username, nickname}

  @typedoc """
  Standard structure for team information in events.
  Used consistently across all events that reference teams.
  """
  @type team_info :: %{
    team_id: String.t(),
    player_ids: [String.t()],
    score: integer(),
    matches: non_neg_integer(),
    total_guesses: pos_integer()
  }

  @typedoc """
  Standard structure for player statistics in events.
  Used in game completion and team elimination events.
  """
  @type player_stats :: %{
    total_guesses: pos_integer(),
    successful_matches: non_neg_integer(),
    abandoned_guesses: non_neg_integer(),
    average_guess_count: float()
  }

  @doc """
  Returns the list of base fields required for all events.
  """
  @spec base_fields() :: [atom()]
  def base_fields, do: @base_fields

  @doc """
  Validates that an event contains all required base fields.
  """
  @spec validate_base_fields(struct()) :: :ok | {:error, String.t()}
  def validate_base_fields(event) do
    with :ok <- validate_required_fields(event, @base_fields),
         :ok <- validate_id_fields(event),
         :ok <- validate_timestamp(event.timestamp),
         :ok <- validate_mode(event.mode) do
      :ok
    end
  end

  @doc """
  Validates that an event's metadata is valid.
  Uses Metadata.validate/1 for validation.
  """
  @spec validate_metadata(struct()) :: :ok | {:error, String.t()}
  def validate_metadata(%{metadata: metadata}) when is_map(metadata) do
    Metadata.validate(metadata)
  end
  def validate_metadata(%{metadata: _}) do
    {:error, "metadata must be a map"}
  end
  def validate_metadata(_) do
    {:error, "metadata is required"}
  end

  @doc """
  Validates an event has all required base fields and a valid metadata structure.
  Used to standardize validation across all event types.
  """
  @spec validate(struct()) :: :ok | {:error, String.t()}
  def validate(event) do
    with :ok <- validate_base_fields(event),
         :ok <- validate_metadata(event) do
      :ok
    end
  end

  @doc """
  Creates a timestamp for an event, defaulting to current UTC time.
  """
  @spec create_timestamp() :: DateTime.t()
  def create_timestamp, do: DateTime.utc_now()

  @doc """
  Creates a base event map with all required fields.

  ## Parameters
  - game_id: Unique identifier for the game
  - guild_id: Discord guild ID
  - mode: Game mode (atom)
  - metadata: Event metadata (must be valid Metadata.t())
  - opts: Optional parameters
    - timestamp: Event timestamp (defaults to current time)
  """
  @spec create_event_map(String.t(), String.t(), atom(), metadata(), keyword()) :: map()
  def create_event_map(game_id, guild_id, mode, metadata, opts \\ []) do
    timestamp = Keyword.get(opts, :timestamp, create_timestamp())

    %{
      game_id: game_id,
      guild_id: guild_id,
      mode: mode,
      timestamp: timestamp,
      metadata: metadata
    }
  end

  @doc """
  Validates that field values have the correct types.
  Takes a map of field names to type-checking functions.
  """
  @spec validate_types(struct(), %{atom() => (term() -> boolean())}) :: :ok | {:error, String.t()}
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
  @spec parse_timestamp(String.t()) :: DateTime.t()
  def parse_timestamp(nil), do: nil
  def parse_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, datetime, _} -> datetime
      {:error, reason} -> raise "Invalid timestamp format: #{timestamp}, error: #{inspect(reason)}"
    end
  end
  def parse_timestamp(%DateTime{} = timestamp), do: timestamp

  @doc """
  Serializes a DateTime struct to an ISO8601 string.

  ## Parameters
    * `datetime` - DateTime struct to serialize

  ## Returns
    * `String.t()` - ISO8601 formatted timestamp string
    * nil - If input is nil

  ## Examples

      iex> EventStructure.to_iso8601(~U[2023-01-01 12:00:00Z])
      "2023-01-01T12:00:00Z"

      iex> EventStructure.to_iso8601(nil)
      nil
  """
  @spec to_iso8601(DateTime.t() | nil) :: String.t() | nil
  def to_iso8601(nil), do: nil
  def to_iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)

  # Private Functions

  defp validate_required_fields(event, fields) do
    Enum.find_value(fields, :ok, fn field ->
      if Map.get(event, field) == nil do
        {:error, "#{field} is required"}
      else
        false
      end
    end)
  end

  defp validate_id_fields(event) do
    with true <- is_binary(event.game_id) and byte_size(event.game_id) > 0,
         true <- is_binary(event.guild_id) and byte_size(event.guild_id) > 0 do
      :ok
    else
      false -> {:error, "game_id and guild_id must be non-empty strings"}
    end
  end

  defp validate_timestamp(%DateTime{} = timestamp) do
    case DateTime.compare(timestamp, DateTime.utc_now()) do
      :gt -> {:error, "timestamp cannot be in the future"}
      _ -> :ok
    end
  end
  defp validate_timestamp(_), do: {:error, "timestamp must be a DateTime"}

  defp validate_mode(mode) when is_atom(mode), do: :ok
  defp validate_mode(_), do: {:error, "mode must be an atom"}

  # Serialization Functions

  @doc """
  Serializes a map or struct for storage by converting complex types to serializable formats.
  """
  @spec serialize(term()) :: term()
  def serialize(data)

  def serialize(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  def serialize(%MapSet{} = set) do
    %{
      "__mapset__" => true,
      "items" => MapSet.to_list(set) |> Enum.map(&serialize/1)
    }
  end

  def serialize(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> serialize()
  end

  def serialize(data) when is_map(data) do
    data
    |> Enum.map(fn {k, v} -> {to_string(k), serialize(v)} end)
    |> Map.new()
  end

  def serialize(data) when is_list(data) do
    Enum.map(data, &serialize/1)
  end

  def serialize(data), do: data

  @doc """
  Deserializes data from storage format back into rich types.
  """
  @spec deserialize(term()) :: term()
  def deserialize(data)

  def deserialize(%{"__mapset__" => true, "items" => items}) do
    items
    |> Enum.map(&deserialize/1)
    |> MapSet.new()
  end

  def deserialize(data) when is_map(data) do
    data
    |> Enum.map(fn {k, v} -> {k, deserialize(v)} end)
    |> Map.new()
  end

  def deserialize(data) when is_list(data) do
    Enum.map(data, &deserialize/1)
  end

  def deserialize(data) when is_binary(data) do
    case DateTime.from_iso8601(data) do
      {:ok, datetime, _} -> datetime
      _ -> data
    end
  end

  def deserialize(data), do: data
end
