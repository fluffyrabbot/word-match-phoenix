defmodule GameBot.Infrastructure.EventStore.Error do
  @moduledoc """
  Defines error types and structures for the event store.
  """

  @type t :: %__MODULE__{
    type: error_type(),
    message: String.t(),
    details: term()
  }

  @type error_type ::
    :validation |
    :serialization |
    :not_found |
    :concurrency |
    :timeout |
    :connection |
    :system

  defexception [:type, :message, :details]

  @impl true
  def message(%{type: type, message: msg, details: details}) do
    "EventStore error (#{type}): #{msg}\nDetails: #{inspect(details)}"
  end
end
