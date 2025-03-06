defmodule GameBot.Infrastructure.Persistence.EventStore.Postgres do
  @moduledoc """
  PostgreSQL-based event store implementation.
  Implements EventStore behaviour through macro and provides additional functionality.
  """

  use EventStore, otp_app: :game_bot

  alias GameBot.Infrastructure.Persistence.Error
  alias EventStore.{EventData, Stream}
  alias EventStore.RecordedEvent, as: Message

  # Configuration
  @telemetry_prefix [:game_bot, :event_store]

  @type stream_error ::
    {:error, :not_found | :wrong_expected_version | :connection | :system}

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

  #
  # Public API - Convenience functions with custom names to avoid conflicts
  #

  def append_events(stream_id, events) do
    do_append_to_stream(stream_id, :any, events, [])
  end

  def read_events(stream_id) do
    do_read_stream_forward(stream_id, 0, 1000, [])
  end

  def subscribe_to_events(stream_id, subscriber) do
    do_subscribe_to_stream(stream_id, subscriber, [], [])
  end

  #
  # EventStore Behaviour Implementation
  #

  @impl EventStore
  def append_to_stream(stream_id, expected_version, events, opts) do
    with {:ok, event_data} <- prepare_events(events),
         {:ok, _} <- do_append(stream_id, expected_version, event_data) do
      {:ok, events}
    end
  end

  @impl EventStore
  def read_stream_forward(stream_id, start_version, count, opts) do
    guild_id = Keyword.get(opts, :guild_id)

    with {:ok, events} <- do_read_forward(stream_id, start_version, count),
         {:ok, filtered} <- maybe_filter_by_guild(events, guild_id) do
      {:ok, Enum.map(filtered, &extract_event_data/1)}
    end
  end

  @impl EventStore
  def subscribe_to_stream(stream_id, subscriber, subscription_options, opts) do
    options = process_subscription_options(subscription_options)

    with {:ok, subscription} <- do_subscribe(stream_id, subscriber, options) do
      {:ok, subscription}
    end
  end

  @impl EventStore
  def stream_version(stream_id) do
    case do_get_version(stream_id) do
      {:ok, version} -> {:ok, version}
      {:error, :stream_not_found} -> {:ok, 0}
      error -> error
    end
  end

  @impl EventStore
  def config(opts) do
    Keyword.merge([
      serializer: EventStore.JsonSerializer,
      username: "postgres",
      password: "csstarahid",
      database: "eventstore_test",
      hostname: "localhost"
    ], opts)
  end

  @impl EventStore
  def ack(subscription, events), do: EventStore.ack(subscription, events)

  @impl EventStore
  def delete_all_streams_subscription(subscription_name, opts),
    do: EventStore.delete_all_streams_subscription(subscription_name, opts)

  @impl EventStore
  def delete_snapshot(source_uuid, opts),
    do: EventStore.delete_snapshot(source_uuid, opts)

  @impl EventStore
  def delete_stream(stream_id, expected_version, hard_delete, opts),
    do: EventStore.delete_stream(stream_id, expected_version, hard_delete, opts)

  @impl EventStore
  def delete_subscription(stream_id, subscription_name, opts),
    do: EventStore.delete_subscription(stream_id, subscription_name, opts)

  @impl EventStore
  def link_to_stream(stream_id, expected_version, event_numbers, opts),
    do: EventStore.link_to_stream(stream_id, expected_version, event_numbers, opts)

  @impl EventStore
  def paginate_streams(opts),
    do: EventStore.paginate_streams(opts)

  @impl EventStore
  def read_all_streams_backward(start_from, count, opts),
    do: EventStore.read_all_streams_backward(start_from, count, opts)

  @impl EventStore
  def read_all_streams_forward(start_from, count, opts),
    do: EventStore.read_all_streams_forward(start_from, count, opts)

  @impl EventStore
  def read_snapshot(source_uuid, opts),
    do: EventStore.read_snapshot(source_uuid, opts)

  @impl EventStore
  def read_stream_backward(stream_id, start_version, count, opts),
    do: EventStore.read_stream_backward(stream_id, start_version, count, opts)

  @impl EventStore
  def record_snapshot(snapshot, opts),
    do: EventStore.record_snapshot(snapshot, opts)

  @impl EventStore
  def start_link(opts),
    do: EventStore.start_link(opts)

  @impl EventStore
  def stop(server, timeout),
    do: EventStore.stop(server, timeout)

  @impl EventStore
  def stream_all_backward(start_from, opts),
    do: EventStore.stream_all_backward(start_from, opts)

  @impl EventStore
  def stream_all_forward(start_from, opts),
    do: EventStore.stream_all_forward(start_from, opts)

  @impl EventStore
  def stream_backward(stream_id, start_version, opts),
    do: EventStore.stream_backward(stream_id, start_version, opts)

  @impl EventStore
  def stream_forward(stream_id, start_version, opts),
    do: EventStore.stream_forward(stream_id, start_version, opts)

  @impl EventStore
  def stream_info(stream_id, opts),
    do: EventStore.stream_info(stream_id, opts)

  @impl EventStore
  def subscribe(subscriber, opts),
    do: EventStore.subscribe(subscriber, opts)

  @impl EventStore
  def subscribe_to_all_streams(subscription_name, subscriber, subscription_options, opts),
    do: EventStore.subscribe_to_all_streams(subscription_name, subscriber, subscription_options, opts)

  @impl EventStore
  def unsubscribe_from_all_streams(subscription, opts),
    do: EventStore.unsubscribe_from_all_streams(subscription, opts)

  @impl EventStore
  def unsubscribe_from_stream(stream_id, subscription, opts),
    do: EventStore.unsubscribe_from_stream(stream_id, subscription, opts)

  #
  # Private Implementation
  #

  defp do_append_to_stream(stream_id, expected_version, events, opts) do
    with {:ok, event_data} <- prepare_events(events),
         {:ok, _} <- do_append(stream_id, expected_version, event_data) do
      {:ok, events}
    end
  end

  defp do_read_stream_forward(stream_id, start_version, count, opts) do
    guild_id = Keyword.get(opts, :guild_id)

    with {:ok, events} <- do_read_forward(stream_id, start_version, count),
         {:ok, filtered} <- maybe_filter_by_guild(events, guild_id) do
      {:ok, Enum.map(filtered, &extract_event_data/1)}
    end
  end

  defp do_subscribe_to_stream(stream_id, subscriber, subscription_options, opts) do
    options = process_subscription_options(subscription_options)

    with {:ok, subscription} <- do_subscribe(stream_id, subscriber, options) do
      {:ok, subscription}
    end
  end

  defp prepare_events(events) when is_list(events) do
    {:ok, Enum.map(events, &to_event_data/1)}
  end
  defp prepare_events(_), do: {:error, :invalid_events}

  defp to_event_data(event) do
    %EventData{
      event_type: to_string(event.event_type),
      data: event,
      metadata: %{}
    }
  end

  defp do_append(stream_id, expected_version, event_data) do
    try do
      case Stream.append_to_stream(stream_id, expected_version, event_data) do
        :ok -> {:ok, :appended}
        {:error, :wrong_expected_version} -> {:error, concurrency_error(expected_version)}
        {:error, reason} -> {:error, system_error("Append failed", reason)}
      end
    rescue
      e in DBConnection.ConnectionError -> {:error, connection_error(e)}
      e -> {:error, system_error("Append failed", e)}
    end
  end

  defp do_read_forward(stream_id, start_version, count) do
    try do
      case Stream.read_stream_forward(stream_id, start_version, count) do
        {:ok, []} when start_version == 0 -> {:error, not_found_error(stream_id)}
        {:ok, events} -> {:ok, events}
        {:error, :stream_not_found} -> {:error, not_found_error(stream_id)}
        {:error, reason} -> {:error, system_error("Read failed", reason)}
      end
    rescue
      e in DBConnection.ConnectionError -> {:error, connection_error(e)}
      e -> {:error, system_error("Read failed", e)}
    end
  end

  defp do_subscribe(stream_id, subscriber, options) do
    try do
      case Stream.subscribe_to_stream(stream_id, subscriber, options) do
        {:ok, subscription} -> {:ok, subscription}
        {:error, :stream_not_found} -> {:error, not_found_error(stream_id)}
        {:error, reason} -> {:error, system_error("Subscribe failed", reason)}
      end
    rescue
      e in DBConnection.ConnectionError -> {:error, connection_error(e)}
      e -> {:error, system_error("Subscribe failed", e)}
    end
  end

  defp maybe_filter_by_guild(events, nil), do: {:ok, events}
  defp maybe_filter_by_guild(events, guild_id) do
    filtered = Enum.filter(events, fn event ->
      data = extract_event_data(event)
      data.guild_id == guild_id || get_in(data, [:metadata, "guild_id"]) == guild_id
    end)
    {:ok, filtered}
  end

  defp do_get_version(stream_id) do
    try do
      Stream.stream_version(stream_id)
    rescue
      e in DBConnection.ConnectionError -> {:error, connection_error(e)}
      e -> {:error, system_error("Get version failed", e)}
    end
  end

  defp process_subscription_options(options) do
    Enum.reduce(options, [], fn
      {:start_from, :origin}, acc -> [{:start_from, :origin} | acc]
      {:start_from, version}, acc when is_integer(version) -> [{:start_from, version} | acc]
      {:include_existing, value}, acc when is_boolean(value) -> [{:include_existing, value} | acc]
      _, acc -> acc
    end)
  end

  defp handle_telemetry_event(@telemetry_prefix ++ [:event], measurements, metadata, _config) do
    require Logger
    Logger.debug(fn ->
      "EventStore event: #{inspect(metadata)}\nMeasurements: #{inspect(measurements)}"
    end)
  end

  defp extract_event_data(%Message{data: data}), do: data

  #
  # Error Helpers
  #

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
