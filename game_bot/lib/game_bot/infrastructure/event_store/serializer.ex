defmodule GameBot.Infrastructure.EventStore.Serializer do
  @moduledoc """
  Event serializer for GameBot.
  Handles serialization and deserialization of game events.
  """

  alias GameBot.Domain.Events.GameEvents

  @doc """
  Serializes an event to the format expected by the event store.
  """
  def serialize(event) do
    GameEvents.serialize(event)
  end

  @doc """
  Deserializes stored event data back into an event struct.
  """
  def deserialize(event_data) do
    GameEvents.deserialize(event_data)
  end

  @doc """
  Returns the current version of an event type.
  Used for schema evolution and migration.
  """
  def event_version(event_type) do
    case event_type do
      "game_started" -> 1
      "round_started" -> 1
      "guess_processed" -> 1
      "guess_abandoned" -> 1
      "team_eliminated" -> 1
      "game_completed" -> 1
      "knockout_round_completed" -> 1
      "race_mode_time_expired" -> 1
      "longform_day_ended" -> 1
      _ -> raise "Unknown event type: #{event_type}"
    end
  end
end
