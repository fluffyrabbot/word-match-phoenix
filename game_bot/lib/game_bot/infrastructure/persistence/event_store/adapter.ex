defmodule GameBot.Infrastructure.Persistence.EventStore.Adapter do
  @moduledoc """
  Adapter for EventStore operations with error handling, retries, and validation.

  This module provides a standardized interface to the event store with:
  - Input validation
  - Error transformation
  - Timeout handling
  - Configurable retry mechanism for transient errors
  - Telemetry integration
  """

  alias GameBot.Infrastructure.Persistence.Error
  alias GameBot.Infrastructure.Persistence.EventStore.{Behaviour, Serializer}

  require Logger

  # Configuration - using direct values instead of compile_env to avoid issues
  @max_append_retries 3
  @max_stream_size 10_000
  @base_backoff_delay 100

  # Use an environment-based approach to determine the store implementation
  @store (case Mix.env() do
    :test -> GameBot.Test.Mocks.EventStore
    _ -> GameBot.Infrastructure.Persistence.EventStore.Postgres
  end)

  # Configuration for retry mechanism - direct values
  @max_retries 3
  @initial_backoff_ms 50

  @doc """
  Append events to a stream with validation and retries.
  """
  def append_to_stream(stream_id, expected_version, events, opts \\ []) do
    with :ok <- validate_events(events),
         :ok <- validate_stream_size(stream_id),
         {:ok, serialized} <- serialize_events(events) do
      do_append_with_retry(stream_id, expected_version, serialized, opts)
    end
  end

  @doc """
  Read events from a stream with deserialization.
  """
  def read_stream_forward(stream_id, start_version \\ 0, count \\ 1000, opts \\ []) do
    with {:ok, events} <- @store.read_stream_forward(stream_id, start_version, count, opts),
         {:ok, deserialized} <- deserialize_events(events) do
      {:ok, deserialized}
    end
  end

  @doc """
  Subscribe to a stream with monitoring.
  """
  def subscribe_to_stream(stream_id, subscriber, subscription_options \\ [], opts \\ []) do
    @store.subscribe_to_stream(stream_id, subscriber, subscription_options, opts)
  end

  # Private Functions

  defp validate_events(events) when is_list(events), do: :ok
  defp validate_events(events), do: {:error, validation_error("Events must be a list", events)}

  defp validate_stream_size(stream_id) do
    case @store.stream_version(stream_id) do
      {:ok, version} when version >= @max_stream_size ->
        {:error, stream_size_error(stream_id, version)}
      _ ->
        :ok
    end
  end

  defp do_append_with_retry(stream_id, expected_version, events, opts) do
    timeout = Keyword.get(opts, :timeout, 5000)
    retry_count = Keyword.get(opts, :retry_count, @max_append_retries)

    case do_append_with_timeout(stream_id, expected_version, events, timeout) do
      {:error, %Error{type: :connection}} when retry_count > 0 ->
        Process.sleep(exponential_backoff(retry_count))
        do_append_with_retry(stream_id, expected_version, events, [
          {:timeout, timeout},
          {:retry_count, retry_count - 1}
        ])
      result ->
        result
    end
  end

  defp do_append_with_timeout(stream_id, expected_version, events, timeout) do
    task = Task.async(fn ->
      @store.append_to_stream(stream_id, expected_version, events)
    end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, timeout_error(stream_id, timeout)}
    end
  end

  defp serialize_events(events) do
    events
    |> Enum.map(&Serializer.serialize/1)
    |> collect_results()
  end

  defp deserialize_events(events) do
    events
    |> Enum.map(&(&1.data))
    |> Enum.map(&Serializer.deserialize/1)
    |> collect_results()
  end

  defp collect_results(results) do
    results
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, item}, {:ok, items} -> {:cont, {:ok, [item | items]}}
      {:error, _} = error, _ -> {:halt, error}
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      error -> error
    end
  end

  defp exponential_backoff(retry) do
    trunc(:math.pow(2, @max_append_retries - retry) * @base_backoff_delay)
  end

  # Error Helpers
  defp validation_error(message, details), do:
    %Error{type: :validation, context: __MODULE__, message: message, details: details}

  defp stream_size_error(stream_id, size), do:
    %Error{type: :stream_too_large, context: __MODULE__,
           message: "Stream exceeds maximum size",
           details: %{stream_id: stream_id, current_size: size, max_size: @max_stream_size}}

  defp timeout_error(stream_id, timeout), do:
    %Error{type: :timeout, context: __MODULE__,
           message: "Operation timed out",
           details: %{stream_id: stream_id, timeout: timeout}}

  # Enhanced error transformation functions
  defp transform_error(:append, error, stream_id, version, events, _opts) do
    case error do
      %Error{type: :concurrency} = err ->
        # Enhance concurrency error with expected vs actual version
        %{err |
          message: "Expected stream '#{stream_id}' at version #{version}, but got #{err.details[:actual] || "different version"}",
          details: Map.merge(err.details || %{}, %{
            stream_id: stream_id,
            expected_version: version,
            event_count: length(events),
            timestamp: DateTime.utc_now()
          })
        }

      %Error{type: :connection} = err ->
        # Enhance connection error with operation details
        %{err |
          message: "Connection error while appending to stream '#{stream_id}': #{err.message}",
          details: Map.merge(err.details || %{}, %{
            stream_id: stream_id,
            event_count: length(events),
            retryable: true,
            timestamp: DateTime.utc_now()
          })
        }

      %Error{} = err ->
        # Enhance other errors with basic context
        %{err |
          details: Map.merge(err.details || %{}, %{
            stream_id: stream_id,
            timestamp: DateTime.utc_now()
          })
        }

      _ ->
        # Transform unknown errors
        %Error{
          type: :unknown,
          context: __MODULE__,
          message: "Unknown error while appending to stream '#{stream_id}': #{inspect(error)}",
          details: %{
            stream_id: stream_id,
            expected_version: version,
            event_count: length(events),
            error: inspect(error),
            timestamp: DateTime.utc_now()
          }
        }
    end
  end

  # Similar enhanced error context for read operations
  defp transform_error(:read, error, stream_id, start_version, count, _opts) do
    case error do
      %Error{type: :not_found} = err ->
        %{err |
          message: "Stream '#{stream_id}' not found",
          details: Map.merge(err.details || %{}, %{
            stream_id: stream_id,
            timestamp: DateTime.utc_now()
          })
        }

      %Error{type: :connection} = err ->
        %{err |
          message: "Connection error while reading stream '#{stream_id}': #{err.message}",
          details: Map.merge(err.details || %{}, %{
            stream_id: stream_id,
            start_version: start_version,
            count: count,
            retryable: true,
            timestamp: DateTime.utc_now()
          })
        }

      %Error{} = err ->
        %{err |
          details: Map.merge(err.details || %{}, %{
            stream_id: stream_id,
            start_version: start_version,
            count: count,
            timestamp: DateTime.utc_now()
          })
        }

      _ ->
        %Error{
          type: :unknown,
          context: __MODULE__,
          message: "Unknown error while reading stream '#{stream_id}': #{inspect(error)}",
          details: %{
            stream_id: stream_id,
            start_version: start_version,
            count: count,
            error: inspect(error),
            timestamp: DateTime.utc_now()
          }
        }
    end
  end

  # Retry mechanism with exponential backoff and jitter
  defp with_retries(operation, func, args, retry_count \\ 0) do
    try do
      apply(func, args)
    rescue
      e ->
        error = Error.from_exception(e, __MODULE__)

        cond do
          # Only retry on retryable connection errors
          error.type == :connection &&
          Map.get(error.details || %{}, :retryable, false) &&
          retry_count < @max_retries ->
            delay = calculate_backoff(retry_count)
            Logger.warning("#{operation} failed with connection error, retrying in #{delay}ms (attempt #{retry_count + 1}/#{@max_retries})")
            Process.sleep(delay)
            with_retries(operation, func, args, retry_count + 1)

          true ->
            {:error, error}
        end
    end
  end

  # Calculate exponential backoff with jitter
  defp calculate_backoff(retry_count) do
    # Base exponential backoff: initial * 2^attempt
    base_delay = @initial_backoff_ms * :math.pow(2, retry_count)

    # Add random jitter of up to 10% to prevent thundering herd
    jitter = :rand.uniform(trunc(base_delay * 0.1))

    trunc(base_delay + jitter)
  end
end
