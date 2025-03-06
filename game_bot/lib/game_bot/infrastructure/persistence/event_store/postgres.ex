defmodule GameBot.Infrastructure.Persistence.EventStore.Postgres do
  @moduledoc """
  PostgreSQL-based event store implementation.
  """

  use EventStore, otp_app: :game_bot
  @behaviour GameBot.Infrastructure.Persistence.EventStore.Behaviour

  alias GameBot.Infrastructure.Persistence.Error
  alias GameBot.Infrastructure.Persistence.EventStore.Serializer
  alias EventStore.{EventData, Stream}
  alias EventStore.RecordedEvent, as: Message
  alias GameBot.Infrastructure.EventStore.Config

  # Configuration
  @telemetry_prefix [:game_bot, :event_store]

  # Connection configuration
  @event_store GameBot.EventStore

  @impl true
  def init(config) do
    :telemetry.attach(
      "event-store-handler",
      @telemetry_prefix ++ [:event],
      &handle_telemetry_event/4,
      nil
    )

    {:ok, config}
  end

  # ONLY implement the full behavior functions - no defaults, no convenience functions
  @impl GameBot.Infrastructure.Persistence.EventStore.Behaviour
  def append_to_stream(stream_id, expected_version, events, opts) do
    try do
      # Convert our events to EventStore library format
      event_data = Enum.map(events, fn event ->
        %EventData{
          event_type: to_string(event.event_type),
          data: event,
          metadata: %{}
        }
      end)

      # Use the EventStore library directly
      case Stream.append_to_stream(@event_store, stream_id, expected_version, event_data) do
        :ok -> {:ok, events}
        {:error, :wrong_expected_version} -> {:error, concurrency_error(expected_version)}
        {:error, reason} -> {:error, system_error("Append failed", reason)}
      end
    rescue
      e in DBConnection.ConnectionError ->
        {:error, connection_error(e)}
      e ->
        {:error, system_error("Append failed", e)}
    end
  end

  @impl GameBot.Infrastructure.Persistence.EventStore.Behaviour
  def read_stream_forward(stream_id, start_version, count, opts) do
    # Extract guild_id from opts if present
    guild_id = Keyword.get(opts, :guild_id)

    try do
      case Stream.read_stream_forward(@event_store, stream_id, start_version, count) do
        {:ok, []} when start_version == 0 ->
          {:error, not_found_error(stream_id)}
        {:ok, events} ->
          # Filter events by guild_id if provided
          events = if guild_id do
            Enum.filter(events, fn event ->
              data = extract_event_data(event)
              data.guild_id == guild_id || get_in(data, [:metadata, "guild_id"]) == guild_id
            end)
          else
            events
          end

          {:ok, Enum.map(events, &extract_event_data/1)}
        {:error, :stream_not_found} ->
          {:error, not_found_error(stream_id)}
        {:error, reason} ->
          {:error, system_error("Read failed", reason)}
      end
    rescue
      e in DBConnection.ConnectionError ->
        {:error, connection_error(e)}
      e ->
        {:error, system_error("Read failed", e)}
    end
  end

  @impl GameBot.Infrastructure.Persistence.EventStore.Behaviour
  def subscribe_to_stream(stream_id, subscriber, subscription_options, opts) do
    try do
      options = process_subscription_options(subscription_options)

      case Stream.subscribe_to_stream(@event_store, stream_id, subscriber, options) do
        {:ok, subscription} ->
          {:ok, subscription}
        {:error, :stream_not_found} ->
          {:error, not_found_error(stream_id)}
        {:error, reason} ->
          {:error, system_error("Subscribe failed", reason)}
      end
    rescue
      e in DBConnection.ConnectionError ->
        {:error, connection_error(e)}
      e ->
        {:error, system_error("Subscribe failed", e)}
    end
  end

  @impl GameBot.Infrastructure.Persistence.EventStore.Behaviour
  def stream_version(stream_id) do
    try do
      case Stream.stream_version(@event_store, stream_id) do
        {:ok, version} ->
          {:ok, version}
        {:error, :stream_not_found} ->
          {:ok, 0}  # Non-existent streams have version 0
        {:error, reason} ->
          {:error, system_error("Get version failed", reason)}
      end
    rescue
      e in DBConnection.ConnectionError ->
        {:error, connection_error(e)}
      e ->
        {:error, system_error("Get version failed", e)}
    end
  end

  # Private Functions

  defp handle_telemetry_event(@telemetry_prefix ++ [:event], measurements, metadata, _config) do
    require Logger
    Logger.debug(fn ->
      "EventStore event: #{inspect(metadata)}\nMeasurements: #{inspect(measurements)}"
    end)
  end

  defp extract_event_data(%Message{data: data}) do
    data
  end

  defp process_subscription_options(options) do
    Enum.reduce(options, [], fn
      {:start_from, :origin}, acc -> [{:start_from, :origin} | acc]
      {:start_from, version}, acc when is_integer(version) -> [{:start_from, version} | acc]
      {:include_existing, value}, acc when is_boolean(value) -> [{:include_existing, value} | acc]
      _, acc -> acc
    end)
  end

  # Error helpers

  defp concurrency_error(expected_version) do
    %Error{
      type: :concurrency,
      context: __MODULE__,
      message: "Wrong expected version",
      details: %{expected: expected_version}
    }
  end

  defp not_found_error(stream_id) do
    %Error{
      type: :not_found,
      context: __MODULE__,
      message: "Stream not found",
      details: %{stream_id: stream_id}
    }
  end

  defp connection_error(error) do
    %Error{
      type: :connection,
      context: __MODULE__,
      message: "Database connection error",
      details: %{error: error, retryable: true}
    }
  end

  defp system_error(message, error) do
    %Error{
      type: :system,
      context: __MODULE__,
      message: message,
      details: error
    }
  end
end
