defmodule GameBot.Infrastructure.Persistence.EventStore.Serializer do
  @moduledoc """
  Event serializer for GameBot.
  Handles serialization, deserialization, and validation of game events.
  """

  alias GameBot.Domain.Events.{EventRegistry, BaseEvent, EventStructure}
  alias GameBot.Infrastructure.Persistence.Error

  @required_stored_fields ~w(event_type event_version data stored_at)
  @current_schema_version 1

  @type result :: {:ok, term()} | {:error, Error.t()}

  @doc """
  Serializes an event to the format expected by the event store.
  """
  @spec serialize(struct()) :: result()
  def serialize(event) do
    try do
      with :ok <- validate_event(event),
           serialized_data <- do_serialize(event) do
        {:ok, serialized_data}
      end
    rescue
      e in Protocol.UndefinedError ->
        {:error, %Error{
          type: :serialization,
          context: __MODULE__,
          message: "Event type not serializable",
          details: %{module: event.__struct__, error: e}
        }}
      e in FunctionClauseError ->
        {:error, %Error{
          type: :serialization,
          context: __MODULE__,
          message: "Invalid event structure",
          details: %{module: event.__struct__, error: e}
        }}
      e ->
        {:error, %Error{
          type: :serialization,
          context: __MODULE__,
          message: "Serialization failed",
          details: e
        }}
    end
  end

  @doc """
  Serializes a list of events to the format expected by the event store.
  """
  @spec serialize_events([struct()]) :: {:ok, [map()]} | {:error, Error.t()}
  def serialize_events(events) when is_list(events) do
    events
    |> Enum.reduce_while({:ok, []}, fn event, {:ok, acc} ->
      case serialize(event) do
        {:ok, serialized} -> {:cont, {:ok, [serialized | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, serialized_events} -> {:ok, Enum.reverse(serialized_events)}
      error -> error
    end
  end
  def serialize_events(_), do: {:error, %Error{
    type: :validation,
    context: __MODULE__,
    message: "Events must be a list",
    details: nil
  }}

  @doc """
  Deserializes stored event data back into an event struct.
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
          context: __MODULE__,
          message: "Missing required event data",
          details: %{missing_key: e.key, available_keys: Map.keys(event_data)}
        }}
      e ->
        {:error, %Error{
          type: :serialization,
          context: __MODULE__,
          message: "Deserialization failed",
          details: e
        }}
    end
  end

  @doc """
  Returns the current version of an event type.
  """
  @spec event_version(String.t()) :: {:ok, pos_integer()} | {:error, Error.t()}
  def event_version(event_type) do
    case EventRegistry.module_for_type(event_type) do
      {:ok, module} ->
        if function_exported?(module, :event_version, 0) do
          {:ok, module.event_version()}
        else
          {:ok, @current_schema_version}
        end
      {:error, _reason} ->
        {:error, %Error{
          type: :validation,
          context: __MODULE__,
          message: "Invalid event type",
          details: "Unknown event type: #{event_type}"
        }}
    end
  end

  # Private Functions

  defp validate_event(event) do
    # Try the event module's validate function first
    module = event.__struct__

    cond do
      # If the event module implements validate/1, call it
      function_exported?(module, :validate, 1) ->
        case module.validate(event) do
          :ok -> :ok
          error -> error
        end

      # For events without a validate function, fall back to EventStructure validation
      true ->
        case EventStructure.validate(event) do
          :ok -> :ok
          error ->
            {:error, %Error{
              type: :validation,
              context: __MODULE__,
              message: "Event structure validation failed",
              details: error
            }}
        end
    end
  end

  defp validate_stored_data(data) when is_map(data) do
    case Enum.find(@required_stored_fields, &(not Map.has_key?(data, &1))) do
      nil -> :ok
      missing ->
        {:error, %Error{
          type: :validation,
          context: __MODULE__,
          message: "Missing required field in stored data",
          details: %{missing_field: missing, available_fields: Map.keys(data)}
        }}
    end
  end

  defp validate_stored_data(data) do
    {:error, %Error{
      type: :validation,
      context: __MODULE__,
      message: "Invalid stored data format",
      details: %{expected: "map", got: inspect(data)}
    }}
  end

  defp do_serialize(event) do
    module = event.__struct__

    # Try to use the module's serialize function if it exists
    serialized_data = if function_exported?(module, :serialize, 1) do
      module.serialize(event)
    else
      # Fall back to older to_map approach if needed
      event_data = if function_exported?(module, :to_map, 1) do
        module.to_map(event)
      else
        # Convert struct to map and remove __struct__ field
        event |> Map.from_struct() |> Map.drop([:__struct__])
      end

      # Convert timestamps to ISO8601 strings
      event_data = event_data
      |> Enum.map(fn
        {k, %DateTime{} = v} -> {k, DateTime.to_iso8601(v)}
        pair -> pair
      end)
      |> Map.new()

      event_data
    end

    event_type = if function_exported?(module, :event_type, 0) do
      module.event_type()
    else
      module
      |> to_string()
      |> String.split(".")
      |> List.last()
      |> Macro.underscore()
    end

    event_version = if function_exported?(module, :event_version, 0) do
      module.event_version()
    else
      @current_schema_version
    end

    %{
      "event_type" => event_type,
      "event_version" => event_version,
      "data" => serialized_data,
      "stored_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp do_deserialize(%{"event_type" => type, "event_version" => version, "data" => data}) do
    with {:ok, expected_version} <- event_version(type),
         :ok <- validate_version(version, expected_version) do
      try do
        case EventRegistry.deserialize(%{
          "event_type" => type,
          "event_version" => version,
          "data" => data
        }) do
          {:ok, event} -> {:ok, event}
          {:error, reason} -> {:error, %Error{
            type: :serialization,
            context: __MODULE__,
            message: "Failed to deserialize event",
            details: %{event_type: type, reason: reason}
          }}
        end
      rescue
        e -> {:error, %Error{
          type: :serialization,
          context: __MODULE__,
          message: "Failed to construct event",
          details: %{event_type: type, error: e}
        }}
      end
    end
  end

  defp validate_version(actual, expected) when actual == expected, do: :ok
  defp validate_version(actual, expected) do
    {:error, %Error{
      type: :validation,
      context: __MODULE__,
      message: "Event version mismatch",
      details: %{actual: actual, expected: expected}
    }}
  end
end
