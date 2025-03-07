defmodule GameBot.Infrastructure.Persistence.EventStore.Postgres do
  @moduledoc """
  PostgreSQL-based event store implementation.
  Implements EventStore behaviour through macro.

  This module is intentionally kept minimal to avoid conflicts with macro-generated functions.
  All custom functionality is implemented in the adapter layer.
  """

  use EventStore, otp_app: :game_bot

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

  # Add @impl annotation for ack/2 function generated by EventStore macro
  @impl true
  def ack(subscription, events) do
    # Call the macro-generated implementation
    super(subscription, events)
  end

  # Private functions
  defp handle_telemetry_event(@telemetry_prefix ++ [:event], measurements, metadata, _config) do
    require Logger
    Logger.debug(fn ->
      "EventStore event: #{inspect(metadata)}\nMeasurements: #{inspect(measurements)}"
    end)
  end
end
