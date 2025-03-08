defmodule GameBot.Infrastructure.EventStore do
  @moduledoc """
  Core EventStore implementation for GameBot.
  Provides basic event persistence using the EventStore library.

  This module should not be used directly. Instead, use GameBot.Infrastructure.EventStoreAdapter
  which provides additional validation, serialization, and monitoring.
  """
  use EventStore, otp_app: :game_bot

  # Configuration
  @telemetry_prefix [:game_bot, :event_store]

  @doc """
  Initialize the event store with configuration and setup monitoring.
  """
  @impl EventStore
  def init(config) do
    :telemetry.attach(
      "event-store-handler",
      @telemetry_prefix ++ [:event],
      &handle_telemetry_event/4,
      nil
    )

    {:ok, config}
  end

  @doc """
  Acknowledge receipt of an event.
  """
  @impl EventStore
  def ack(subscription, events) do
    :ok = EventStore.ack(subscription, events)
  end

  @doc """
  Resets the event store by deleting all events.
  Only available in test environment.
  """
  def reset! do
    if Mix.env() != :test do
      raise "reset! is only available in test environment"
    end

    config = Application.get_env(:game_bot, __MODULE__, [])
    {:ok, conn} = EventStore.Config.parse(config)

    # Drop and recreate the event store database with explicit options
    :ok = EventStore.Storage.Initializer.reset!(conn, [])
  end

  @doc """
  Gets the current version of a stream.
  """
  def stream_version(stream_id) do
    case read_stream_backward(stream_id, 1) do
      {:ok, []} -> {:ok, 0}
      {:ok, [event]} -> {:ok, event.stream_version}
      {:error, :stream_not_found} -> {:ok, 0}
      error -> error
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
