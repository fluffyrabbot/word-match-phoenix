defmodule GameBot.Infrastructure.Persistence.EventStore.Behaviour do
  @moduledoc """
  Defines the core interface for event store implementations.
  """

  @type stream_id :: String.t()
  @type version :: non_neg_integer()
  @type event :: term()
  @type error :: EventStore.Error.t()

  @callback append_to_stream(stream_id(), version(), [event()], keyword()) ::
    {:ok, [event()]} | {:error, error()}

  @callback read_stream_forward(stream_id(), version(), pos_integer(), keyword()) ::
    {:ok, [event()]} | {:error, error()}

  @callback subscribe_to_stream(stream_id(), pid(), keyword(), keyword()) ::
    {:ok, pid()} | {:error, error()}

  @callback stream_version(stream_id()) ::
    {:ok, version()} | {:error, error()}
end
