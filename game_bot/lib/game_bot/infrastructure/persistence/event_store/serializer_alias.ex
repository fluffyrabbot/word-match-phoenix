defmodule GameBot.Infrastructure.Persistence.EventStore.Serializer.Alias do
  @moduledoc """
  Provides backward compatibility for code that uses the old Serializer module.

  This module exists temporarily to facilitate a smooth transition to the JsonSerializer.
  It should be used alongside the actual Serializer module until all code has been updated
  to use JsonSerializer directly, at which point both this module and the original
  Serializer can be removed.
  """

  alias GameBot.Infrastructure.Persistence.EventStore.JsonSerializer

  @doc """
  Forwards to JsonSerializer.serialize/1
  """
  defdelegate serialize(event), to: JsonSerializer

  @doc """
  Forwards to JsonSerializer.deserialize/1
  """
  defdelegate deserialize(data), to: JsonSerializer

  @doc """
  Forwards to JsonSerializer.event_version/1
  """
  defdelegate event_version(event_type), to: JsonSerializer
end
