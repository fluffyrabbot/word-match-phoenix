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
    jitter = Keyword.get(opts, :jitter, true)

    # Add telemetry for retries
    operation_with_telemetry = fn ->
      result = operation.()

      if match?({:error, _}, result) do
        :telemetry.execute(
          [:gamebot, :infrastructure, :retry],
          %{count: 1},
          %{context: context}
        )
      end

      result
    end

    do_with_retries(operation_with_telemetry, context, max_retries, initial_delay, 0, jitter)
  end

  @doc """
  Transforms various error types into a standardized Error struct.
  """
  @spec translate_error(term(), module()) :: Error.t()
  def translate_error(reason, context) do
    case reason do
      # Handle our own error type
      %Error{} = error -> error

      # Handle EventStore specific errors
      %{__struct__: struct, reason: reason, message: message} when struct == EventStore.Error ->
        translate_eventstore_error(reason, message, context)

      # Handle common Ecto errors
      %Ecto.ConstraintError{constraint: constraint, type: type} ->
        Error.validation_error(context, "Database constraint violation: #{type} #{constraint}")

      %Ecto.InvalidChangesetError{changeset: changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, &format_changeset_error/1)
        Error.validation_error(context, "Invalid data", errors)

      %Ecto.MultiplePrimaryKeyError{} ->
        Error.validation_error(context, "Multiple primary keys provided")

      # Handle common error atoms
      :not_found -> Error.not_found_error(context, "Resource not found")
      :timeout -> Error.timeout_error(context, "Operation timed out")
      :connection_error -> Error.connection_error(context, "Connection failed")
      :invalid_stream_version -> Error.concurrency_error(context, "Invalid stream version")
      :stream_exists -> Error.concurrency_error(context, "Stream already exists")
      :wrong_expected_version -> Error.concurrency_error(context, "Wrong expected version")

      # Handle tuples with context
      {:validation, message} -> Error.validation_error(context, message)
      {:not_found, details} -> Error.not_found_error(context, "Resource not found", details)
      {:concurrency, message} -> Error.concurrency_error(context, message)
      {:system, message} -> Error.system_error(context, message)
      {:serialization, message} -> Error.serialization_error(context, message)

      # Catch-all
      other -> Error.system_error(context, "Unexpected error", other)
    end
  end

  @doc """
  Formats a changeset error message.
  """
  def format_changeset_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  # Private Functions

  defp do_with_retries(operation, context, max_retries, delay, retry_count, jitter) do
    case wrap_error(operation, context) do
      {:error, %Error{type: type} = error} when type in [:connection, :timeout] ->
        if retry_count < max_retries do
          actual_delay = calculate_delay(delay, retry_count, jitter)
          :timer.sleep(actual_delay)

          # Add retry context to the error for better tracking
          updated_error = add_retry_context(error, retry_count, max_retries)

          do_with_retries(operation, context, max_retries, delay, retry_count + 1, jitter)
        else
          # Add retry exhaustion information to the error
          {:error, %{error |
            message: "#{error.message} (after #{max_retries} retries)",
            details: Map.put(error.details || %{}, :retries_exhausted, true)
          }}
        end
      result -> result
    end
  end

  defp calculate_delay(initial_delay, retry_count, jitter) do
    base_delay = trunc(initial_delay * :math.pow(2, retry_count))

    if jitter do
      # Add random jitter (±20%) to prevent thundering herd problem
      jitter_factor = :rand.uniform() * 0.4 + 0.8 # 0.8 to 1.2
      trunc(base_delay * jitter_factor)
    else
      base_delay
    end
  end

  defp add_retry_context(error, retry_count, max_retries) do
    details = error.details || %{}
    updated_details = Map.merge(details, %{
      retry_attempt: retry_count + 1,
      retries_remaining: max_retries - retry_count - 1
    })

    %{error | details: updated_details}
  end

  defp translate_eventstore_error(reason, message, context) do
    case reason do
      :wrong_expected_version ->
        Error.concurrency_error(context, "Concurrency conflict: #{message}")
      :stream_exists ->
        Error.concurrency_error(context, "Stream already exists: #{message}")
      :stream_not_found ->
        Error.not_found_error(context, "Stream not found: #{message}")
      :subscription_already_exists ->
        Error.concurrency_error(context, "Subscription already exists: #{message}")
      :failed_to_connect ->
        Error.connection_error(context, "Failed to connect to event store: #{message}")
      _ ->
        Error.system_error(context, "EventStore error: #{message}", reason)
    end
  end

  defp exception_to_error(exception, context) do
    # Handle different error types based on string matching for safety
    cond do
      # Database connection errors
      match?(%DBConnection.ConnectionError{}, exception) ->
        Error.connection_error(context, "Database connection error: #{Exception.message(exception)}", exception)

      # Use string matching for EventStore-specific exceptions to avoid dependency issues
      exception_name_matches?(exception, "EventStore.StreamNotFoundError") ->
        Error.not_found_error(context, "Stream not found: #{Exception.message(exception)}", exception)

      exception_name_matches?(exception, "EventStore.WrongExpectedVersionError") ->
        Error.concurrency_error(context, "Concurrency conflict: #{Exception.message(exception)}", exception)

      # Common validation errors
      match?(%ArgumentError{}, exception) ->
        Error.validation_error(context, "Invalid argument: #{Exception.message(exception)}", exception)

      match?(%FunctionClauseError{}, exception) ->
        Error.validation_error(context, "Function clause error: #{Exception.message(exception)}", exception)

      # JSON encoding/decoding errors
      exception_name_matches?(exception, "Jason.EncodeError") ->
        Error.serialization_error(context, "JSON encoding error: #{Exception.message(exception)}", exception)

      exception_name_matches?(exception, "Jason.DecodeError") ->
        Error.serialization_error(context, "JSON decoding error: #{Exception.message(exception)}", exception)

      # Catch-all for other exceptions
      true ->
        Error.system_error(context, "Unexpected exception: #{Exception.message(exception)}", exception)
    end
  end

  # Helper to check exception module name without directly referencing the module
  defp exception_name_matches?(exception, module_name) do
    mod_name = exception.__struct__ |> to_string()
    String.contains?(mod_name, module_name)
  end
end
