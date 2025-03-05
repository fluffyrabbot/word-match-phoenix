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

  # Private Functions
  defp handle_telemetry_event(@telemetry_prefix ++ [:event], measurements, metadata, _config) do
    require Logger
    Logger.debug(fn ->
      "EventStore event: #{inspect(metadata)}\nMeasurements: #{inspect(measurements)}"
    end)
  end
end
