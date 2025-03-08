defmodule GameBot.Infrastructure.EventStore.Serializer do
  @moduledoc """
  Event serializer for GameBot.
  Handles serialization, deserialization, and validation of game events.

  ## Features
  - Event validation before serialization
  - Schema version validation
  - Error handling with detailed messages
  - Support for all game event types
  """

  alias GameBot.Domain.Events.GameEvents
  alias GameBot.Infrastructure.Error
  alias GameBot.Infrastructure.ErrorHelpers

  @required_stored_fields ~w(event_type event_version data stored_at)
  @current_schema_version 1

  @typedoc """
  Result of serialization/deserialization operations.
  """
  @type result :: {:ok, term()} | {:error, Error.t()}

  @doc """
  Serializes an event to the format expected by the event store.
  Includes validation and error handling.

  ## Parameters
    * `event` - The event struct to serialize

  ## Returns
    * `{:ok, map}` - Successfully serialized event
    * `{:error, Error.t()}` - Serialization failed
  """
  @spec serialize(struct()) :: result()
  def serialize(event) do
    try do
      with :ok <- validate_event(event),
           serialized <- GameEvents.serialize(event) do
        {:ok, serialized}
      end
    rescue
      e in Protocol.UndefinedError ->
        {:error, %Error{
          type: :serialization,
          message: "Event type not serializable",
          details: %{
            module: event.__struct__,
            error: e
          }
        }}
      e in FunctionClauseError ->
        {:error, %Error{
          type: :serialization,
          message: "Invalid event structure",
          details: %{
            module: event.__struct__,
            error: e
          }
        }}
      e ->
        {:error, %Error{
          type: :serialization,
          message: "Serialization failed",
          details: e
        }}
    end
  end

  @doc """
  Deserializes stored event data back into an event struct.
  Includes validation and error handling.

  ## Parameters
    * `event_data` - The stored event data to deserialize

  ## Returns
    * `{:ok, struct}` - Successfully deserialized event
    * `{:error, Error.t()}` - Deserialization failed
  """
  @spec deserialize(map()) :: result()
  def deserialize(event_data) do
    try do
      with :ok <- validate_stored_data(event_data),
           {:ok, event} <- do_deserialize(event_data),
           :ok <- validate_event(event) do
        {:ok, event}
      end
    rescue
      e in KeyError ->
        {:error, %Error{
          type: :serialization,
          message: "Missing required event data",
          details: %{
            missing_key: e.key,
            available_keys: Map.keys(event_data)
          }
        }}
      e ->
        {:error, %Error{
          type: :serialization,
          message: "Deserialization failed",
          details: e
        }}
    end
  end

  @doc """
  Returns the current version of an event type.
  Used for schema evolution and migration.

  ## Parameters
    * `event_type` - String identifier of the event type

  ## Returns
    * `{:ok, version}` - Current version number
    * `{:error, Error.t()}` - Invalid event type
  """
  @spec event_version(String.t()) :: {:ok, pos_integer()} | {:error, Error.t()}
  def event_version(event_type) do
    try do
      version = case event_type do
        "game_started" -> @current_schema_version
        "round_started" -> @current_schema_version
        "guess_processed" -> @current_schema_version
        "guess_abandoned" -> @current_schema_version
        "team_eliminated" -> @current_schema_version
        "game_completed" -> @current_schema_version
        "knockout_round_completed" -> @current_schema_version
        "race_mode_time_expired" -> @current_schema_version
        "longform_day_ended" -> @current_schema_version
        _ ->
          raise "Unknown event type: #{event_type}"
      end
      {:ok, version}
    rescue
      e in RuntimeError ->
        {:error, %Error{
          type: :validation,
          message: "Invalid event type",
          details: e.message
        }}
    end
  end

  # Private Functions

  defp validate_event(event) do
    module = event.__struct__

    if function_exported?(module, :validate, 1) do
      module.validate(event)
    else
      {:error, %Error{
        type: :validation,
        message: "Event module missing validate/1",
        details: module
      }}
    end
  end

  defp validate_stored_data(data) when is_map(data) do
    case Enum.find(@required_stored_fields, &(not Map.has_key?(data, &1))) do
      nil -> :ok
      missing ->
        {:error, %Error{
          type: :validation,
          message: "Missing required field in stored data",
          details: %{
            missing_field: missing,
            available_fields: Map.keys(data)
          }
        }}
    end
  end

  defp validate_stored_data(data) do
    {:error, %Error{
      type: :validation,
      message: "Invalid stored data format",
      details: %{
        expected: "map",
        got: inspect(data)
      }
    }}
  end

  defp do_deserialize(%{"event_type" => type, "event_version" => version, "data" => data}) do
    with {:ok, expected_version} <- event_version(type),
         :ok <- validate_version(version, expected_version) do
      try do
        event = GameEvents.deserialize(%{
          "event_type" => type,
          "data" => data
        })
        {:ok, event}
      rescue
        e -> {:error, %Error{
          type: :serialization,
          message: "Failed to construct event",
          details: %{
            event_type: type,
            error: e
          }
        }}
      end
    end
  end

  defp validate_version(actual, expected) when actual == expected, do: :ok
  defp validate_version(actual, expected) do
    {:error, %Error{
      type: :validation,
      message: "Event version mismatch",
      details: %{
        actual: actual,
        expected: expected
      }
    }}
  end
end
