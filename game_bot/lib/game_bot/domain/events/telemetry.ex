defmodule GameBot.Domain.Events.Telemetry do
  @moduledoc """
  Telemetry integration for event processing.
  Provides metrics and monitoring for event operations.
  """

  require Logger

  @event_prefix [:game_bot, :events]

  @doc """
  Records an event being processed.
  """
  @spec record_event_processed(module(), integer()) :: :ok
  def record_event_processed(event_type, duration) do
    :telemetry.execute(
      @event_prefix ++ [:processed],
      %{duration: duration},
      %{
        event_type: event_type,
        timestamp: DateTime.utc_now()
      }
    )
  end

  @doc """
  Records an event validation.
  """
  @spec record_event_validated(module(), integer()) :: :ok
  def record_event_validated(event_type, duration) do
    :telemetry.execute(
      @event_prefix ++ [:validated],
      %{duration: duration},
      %{
        event_type: event_type,
        timestamp: DateTime.utc_now()
      }
    )
  end

  @doc """
  Records an event serialization operation.
  """
  @spec record_event_serialized(module(), integer()) :: :ok
  def record_event_serialized(event_type, duration) do
    :telemetry.execute(
      @event_prefix ++ [:serialized],
      %{duration: duration},
      %{
        event_type: event_type,
        timestamp: DateTime.utc_now()
      }
    )
  end

  @doc """
  Records an event processing error.
  """
  @spec record_error(module(), term()) :: :ok
  def record_error(event_type, reason) do
    :telemetry.execute(
      @event_prefix ++ [:error],
      %{count: 1},
      %{
        event_type: event_type,
        error: reason,
        timestamp: DateTime.utc_now()
      }
    )
  end

  @doc """
  Attaches telemetry handlers for event monitoring.
  """
  @spec attach_handlers() :: :ok
  def attach_handlers do
    :telemetry.attach_many(
      "game-bot-event-handlers",
      [
        @event_prefix ++ [:processed],
        @event_prefix ++ [:validated],
        @event_prefix ++ [:serialized],
        @event_prefix ++ [:error]
      ],
      &handle_event/4,
      nil
    )
  end

  # Private Functions

  defp handle_event(event_name, measurements, metadata, _config) do
    Logger.debug("Event #{inspect(event_name)}: #{inspect(measurements)} #{inspect(metadata)}")
  end
end
