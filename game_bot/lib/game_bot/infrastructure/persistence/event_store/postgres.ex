defmodule GameBot.Infrastructure.Persistence.EventStore.Postgres do
  @moduledoc """
  PostgreSQL-based event store implementation.
  """

  use EventStore, otp_app: :game_bot
  @behaviour GameBot.Infrastructure.Persistence.EventStore.Behaviour

  alias GameBot.Infrastructure.Persistence.Error
  alias GameBot.Infrastructure.Persistence.EventStore.Serializer

  # Configuration
  @telemetry_prefix [:game_bot, :event_store]

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

  @impl GameBot.Infrastructure.Persistence.EventStore.Behaviour
  def append_to_stream(stream_id, expected_version, events, opts \\ []) do
    try do
      super(stream_id, expected_version, events, opts)
    rescue
      e in EventStore.WrongExpectedVersionError ->
        {:error, %Error{
          type: :concurrency,
          context: __MODULE__,
          message: "Concurrent modification detected",
          details: %{stream_id: stream_id, expected: expected_version, actual: e.current_version}
        }}
      e ->
        {:error, %Error{
          type: :system,
          context: __MODULE__,
          message: "Failed to append events",
          details: %{stream_id: stream_id, error: e}
        }}
    end
  end

  @impl GameBot.Infrastructure.Persistence.EventStore.Behaviour
  def read_stream_forward(stream_id, start_version \\ 0, count \\ 1000, opts \\ []) do
    try do
      super(stream_id, start_version, count, opts)
    rescue
      EventStore.StreamNotFoundError ->
        {:error, %Error{
          type: :not_found,
          context: __MODULE__,
          message: "Stream not found",
          details: %{stream_id: stream_id}
        }}
      e ->
        {:error, %Error{
          type: :system,
          context: __MODULE__,
          message: "Failed to read stream",
          details: %{stream_id: stream_id, error: e}
        }}
    end
  end

  @impl GameBot.Infrastructure.Persistence.EventStore.Behaviour
  def subscribe_to_stream(stream_id, subscriber, subscription_options \\ [], opts \\ []) do
    try do
      with {:ok, subscription} <- super(stream_id, subscriber, subscription_options, opts) do
        Process.monitor(subscription)
        {:ok, subscription}
      end
    rescue
      e ->
        {:error, %Error{
          type: :system,
          context: __MODULE__,
          message: "Failed to create subscription",
          details: %{stream_id: stream_id, error: e}
        }}
    end
  end

  @impl GameBot.Infrastructure.Persistence.EventStore.Behaviour
  def stream_version(stream_id) do
    try do
      case read_stream_forward(stream_id, 0, 1) do
        {:ok, []} -> {:ok, 0}
        {:ok, events} -> {:ok, length(events)}
        error -> error
      end
    rescue
      e ->
        {:error, %Error{
          type: :system,
          context: __MODULE__,
          message: "Failed to get stream version",
          details: %{stream_id: stream_id, error: e}
        }}
    end
  end

  # Private Functions

  defp handle_telemetry_event(@telemetry_prefix ++ [:event], measurements, metadata, _config) do
    require Logger
    Logger.debug(fn ->
      "EventStore event: #{inspect(metadata)}\nMeasurements: #{inspect(measurements)}"
    end)
  end
end
