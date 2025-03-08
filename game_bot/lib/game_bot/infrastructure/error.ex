defmodule GameBot.Infrastructure.Error do
  @moduledoc """
  Unified error handling for the GameBot infrastructure layer.

  This module provides a standardized way to handle errors across all infrastructure
  components including EventStore, Repository, and other persistence mechanisms.

  Error types are consolidated from various sources to provide a consistent interface
  while maintaining specific error context and details.
  """

  @type error_type ::
    :validation |
    :serialization |
    :not_found |
    :concurrency |
    :timeout |
    :connection |
    :system |
    :stream_too_large |
    :invalid_type |
    :missing_field |
    :invalid_format

  @type t :: %__MODULE__{
    type: error_type(),
    context: module(),
    message: String.t(),
    details: term(),
    source: term()
  }

  defexception [:type, :context, :message, :details, :source]

  @impl true
  def message(%{type: type, context: ctx, message: msg, details: details}) do
    """
    #{inspect(ctx)} error (#{type}): #{msg}
    Details: #{inspect(details)}
    """
  end

  @doc """
  Creates a new error struct with the given attributes.
  """
  @spec new(error_type(), module(), String.t(), term(), term()) :: t()
  def new(type, context, message, details \\ nil, source \\ nil) do
    %__MODULE__{
      type: type,
      context: context,
      message: message,
      details: details,
      source: source
    }
  end

  @doc """
  Creates a validation error.
  """
  @spec validation_error(module(), String.t(), term()) :: t()
  def validation_error(context, message, details \\ nil) do
    new(:validation, context, message, details)
  end

  @doc """
  Creates a not found error.
  """
  @spec not_found_error(module(), String.t(), term()) :: t()
  def not_found_error(context, message, details \\ nil) do
    new(:not_found, context, message, details)
  end

  @doc """
  Creates a concurrency error.
  """
  @spec concurrency_error(module(), String.t(), term()) :: t()
  def concurrency_error(context, message, details \\ nil) do
    new(:concurrency, context, message, details)
  end

  @doc """
  Creates a timeout error.
  """
  @spec timeout_error(module(), String.t(), term()) :: t()
  def timeout_error(context, message, details \\ nil) do
    new(:timeout, context, message, details)
  end

  @doc """
  Creates a connection error.
  """
  @spec connection_error(module(), String.t(), term()) :: t()
  def connection_error(context, message, details \\ nil) do
    new(:connection, context, message, details)
  end

  @doc """
  Creates a system error.
  """
  @spec system_error(module(), String.t(), term()) :: t()
  def system_error(context, message, details \\ nil) do
    new(:system, context, message, details)
  end

  @doc """
  Creates a serialization error.
  """
  @spec serialization_error(module(), String.t(), term()) :: t()
  def serialization_error(context, message, details \\ nil) do
    new(:serialization, context, message, details)
  end

  @doc """
  Creates a stream size error.
  """
  @spec stream_size_error(module(), String.t(), term()) :: t()
  def stream_size_error(context, message, details \\ nil) do
    new(:stream_too_large, context, message, details)
  end
end
