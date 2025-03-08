defmodule GameBot.Infrastructure.Persistence.EventStore.Serialization.JsonSerializer do
  @moduledoc """
  JSON-based implementation of the event serialization behaviour.

  This module handles serialization and deserialization of domain events to/from JSON,
  with support for versioning and validation.

  Features:
  - JSON serialization with version tracking
  - Type validation and error handling
  - Metadata preservation
  - Optional migration support
  - Event registry integration
  """

  @behaviour GameBot.Infrastructure.Persistence.EventStore.Serialization.Behaviour

  alias GameBot.Infrastructure.Error
  alias GameBot.Infrastructure.ErrorHelpers
  alias GameBot.Domain.Events.{EventRegistry, BaseEvent, EventStructure}

  @current_version 1
  require Logger

  @type event_type :: String.t()
  @type event_version :: pos_integer()

  @impl true
  def serialize(event, opts \\ []) do
    ErrorHelpers.wrap_error(
      fn ->
        with :ok <- validate_event(event),
             {:ok, data} <- encode_event(event) do
          {:ok, %{
            "type" => get_event_type(event),
            "version" => get_event_version(event),
            "data" => data,
            "metadata" => Map.get(event, :metadata, %{})
          }}
        end
      end,
      __MODULE__
    )
  end

  @impl true
  def deserialize(data, opts \\ []) do
    ErrorHelpers.wrap_error(
      fn ->
        with :ok <- validate(data),
             {:ok, event_module} <- lookup_event_module(data["type"]),
             {:ok, event_data} <- decode_event(data["data"]),
             {:ok, event} <- create_event(event_module, event_data, data["metadata"]) do
          {:ok, event}
        end
      end,
      __MODULE__
    )
  end

  @impl true
  def version, do: @current_version

  @impl true
  def validate(data, _opts \\ []) do
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
  def migrate(data, from_version, to_version, _opts \\ []) do
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

  # Private Functions

  defp validate_event(event) do
    cond do
      not is_struct(event) ->
        {:error, Error.validation_error(__MODULE__, "Event must be a struct", event)}
      is_nil(get_event_type_if_available(event)) ->
        {:error, Error.validation_error(__MODULE__, "Event must implement event_type/0 or be registered with a valid type", event)}
      is_nil(get_event_version_if_available(event)) ->
        {:error, Error.validation_error(__MODULE__, "Event must implement event_version/0 or be registered with a valid version", event)}
      true ->
        :ok
    end
  end

  defp get_event_type_if_available(event) do
    cond do
      function_exported?(event.__struct__, :event_type, 0) ->
        event.__struct__.event_type()
      function_exported?(get_registry(), :event_type_for, 1) ->
        get_registry().event_type_for(event)
      true ->
        nil
    end
  end

  defp get_event_version_if_available(event) do
    cond do
      function_exported?(event.__struct__, :event_version, 0) ->
        event.__struct__.event_version()
      function_exported?(get_registry(), :event_version_for, 1) ->
        get_registry().event_version_for(event)
      true ->
        nil
    end
  end

  defp get_event_type(event) do
    case get_event_type_if_available(event) do
      nil ->
        raise "Event type not found for struct: #{inspect(event.__struct__)}.  Implement event_type/0 or register the event."
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
        function_exported?(event.__struct__, :to_map, 1) ->
          result = event.__struct__.to_map(event)
          if is_nil(result), do: raise("Event to_map returned nil for #{inspect(event.__struct__)}")
          result
        function_exported?(get_registry(), :encode_event, 1) ->
          result = get_registry().encode_event(event)
          # Return error if registry encoder returns nil
          if is_nil(result) do
            raise "Registry encoder returned nil for event #{inspect(event.__struct__)}"
          end
          result
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
    case get_registry().module_for_type(type) do
      {:ok, module} -> {:ok, module}
      {:error, _} -> {:error, Error.not_found_error(__MODULE__, "Unknown event type", type)}
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
