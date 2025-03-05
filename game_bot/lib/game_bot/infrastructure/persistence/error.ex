defmodule GameBot.Infrastructure.Persistence.Error do
  @moduledoc """
  Standardized error handling for persistence operations.
  """

  @type error_type ::
    :validation |
    :serialization |
    :not_found |
    :concurrency |
    :timeout |
    :connection |
    :system |
    :stream_too_large

  @type t :: %__MODULE__{
    type: error_type(),
    context: module(),
    message: String.t(),
    details: term()
  }

  defexception [:type, :context, :message, :details]

  @impl true
  def message(%{type: type, context: ctx, message: msg, details: details}) do
    "#{inspect(ctx)} error (#{type}): #{msg}\nDetails: #{inspect(details)}"
  end
end
