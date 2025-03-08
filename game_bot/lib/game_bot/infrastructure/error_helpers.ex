defmodule GameBot.Infrastructure.ErrorHelpers do
  @moduledoc """
  Helper functions for error handling and transformation.

  This module provides utility functions to handle common error scenarios,
  transform errors between different formats, and wrap operations with
  consistent error handling.
  """

  alias GameBot.Infrastructure.Error

  @doc """
  Wraps an operation that may return {:ok, result} or {:error, reason}.
  Transforms any error into a standardized Error struct.
  """
  @spec wrap_error((() -> {:ok, term()} | {:error, term()}), module()) ::
    {:ok, term()} | {:error, Error.t()}
  def wrap_error(operation, context) when is_function(operation, 0) do
    try do
      case operation.() do
        {:ok, result} -> {:ok, result}
        {:error, %Error{} = error} -> {:error, error}
        {:error, reason} -> {:error, translate_error(reason, context)}
      end
    rescue
      e -> {:error, exception_to_error(e, context)}
    end
  end

  @doc """
  Wraps an operation with retry logic for transient errors.
  """
  @spec with_retries((() -> {:ok, term()} | {:error, term()}), module(), keyword()) ::
    {:ok, term()} | {:error, Error.t()}
  def with_retries(operation, context, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, 3)
    initial_delay = Keyword.get(opts, :initial_delay, 50)

    do_with_retries(operation, context, max_retries, initial_delay, 0)
  end

  @doc """
  Transforms various error types into a standardized Error struct.
  """
  @spec translate_error(term(), module()) :: Error.t()
  def translate_error(reason, context) do
    case reason do
      %Error{} = error -> error
      :not_found -> Error.not_found_error(context, "Resource not found")
      :timeout -> Error.timeout_error(context, "Operation timed out")
      :connection_error -> Error.connection_error(context, "Connection failed")
      {:validation, message} -> Error.validation_error(context, message)
      other -> Error.system_error(context, "Unexpected error", other)
    end
  end

  # Private Functions

  defp do_with_retries(operation, context, max_retries, delay, retry_count) do
    case wrap_error(operation, context) do
      {:error, %Error{type: type} = error} when type in [:connection, :timeout] ->
        if retry_count < max_retries do
          :timer.sleep(calculate_delay(delay, retry_count))
          do_with_retries(operation, context, max_retries, delay, retry_count + 1)
        else
          {:error, %{error | message: "#{error.message} (after #{max_retries} retries)"}}
        end
      result -> result
    end
  end

  defp calculate_delay(initial_delay, retry_count) do
    trunc(initial_delay * :math.pow(2, retry_count))
  end

  defp exception_to_error(exception, context) do
    case exception do
      %DBConnection.ConnectionError{} = e ->
        Error.connection_error(context, Exception.message(e), e)
      %ArgumentError{} = e ->
        Error.validation_error(context, Exception.message(e), e)
      e ->
        Error.system_error(context, Exception.message(e), e)
    end
  end
end
