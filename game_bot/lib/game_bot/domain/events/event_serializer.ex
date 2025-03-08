defprotocol GameBot.Domain.Events.EventSerializer do
  @moduledoc """
  Protocol for serializing and deserializing events.
  Provides a standard interface for converting events to and from maps for storage.
  """

  @doc "Converts an event to a map for storage"
  def to_map(event)

  @doc "Converts a map back to an event struct"
  def from_map(data)
end
