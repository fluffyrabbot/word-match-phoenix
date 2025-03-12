defmodule GameBot.Infrastructure.Persistence.EventStore.Serializer do
  @moduledoc """
  DEPRECATED: This module is provided for backward compatibility only.

  New code should use GameBot.Infrastructure.Persistence.EventStore.JsonSerializer directly.
  This is a compatibility layer that forwards calls to the JsonSerializer implementation.
  """

  alias GameBot.Infrastructure.Persistence.EventStore.JsonSerializer

  @doc """
  DEPRECATED: Use JsonSerializer.serialize/1 instead.

  Forwards to the JsonSerializer implementation.
  """
  defdelegate serialize(event), to: JsonSerializer

  @doc """
  DEPRECATED: Use JsonSerializer.deserialize/1 instead.

  Forwards to the JsonSerializer implementation.
  """
  defdelegate deserialize(data), to: JsonSerializer

  @doc """
  DEPRECATED: Use JsonSerializer.event_version/1 instead.

  Forwards to the JsonSerializer implementation.
  """
  defdelegate event_version(event_type), to: JsonSerializer
end
