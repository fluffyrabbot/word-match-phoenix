defmodule GameBot.Infrastructure.Persistence.EventStore.Serialization.JsonSerializer do
  @moduledoc """
  DEPRECATED: This module has been merged into GameBot.Infrastructure.Persistence.EventStore.Serializer.

  This alias exists for backward compatibility.
  All functionality now lives in GameBot.Infrastructure.Persistence.EventStore.Serializer.
  """

  @deprecated "Use GameBot.Infrastructure.Persistence.EventStore.Serializer instead"

  defdelegate serialize(event, opts \\ []), to: GameBot.Infrastructure.Persistence.EventStore.Serializer
  defdelegate deserialize(data, opts \\ []), to: GameBot.Infrastructure.Persistence.EventStore.Serializer
  defdelegate validate(data, opts \\ []), to: GameBot.Infrastructure.Persistence.EventStore.Serializer
  defdelegate migrate(data, from_version, to_version, opts \\ []), to: GameBot.Infrastructure.Persistence.EventStore.Serializer
  defdelegate version(), to: GameBot.Infrastructure.Persistence.EventStore.Serializer
end
