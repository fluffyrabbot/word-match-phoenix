defmodule GameBot.Infrastructure.Persistence.EventStore.Adapter do
  @moduledoc """
  Adapter for EventStore operations with error handling, retries, and validation.

  This module provides a standardized interface to the event store with:
  - Input validation
  - Error transformation
  - Timeout handling
  - Configurable retry mechanism for transient errors
  - Telemetry integration

  This adapter implements the EventStore.Behaviour and delegates to the actual
  EventStore implementation (PostgreSQL in production, mock in tests).
  """

  @behaviour GameBot.Infrastructure.Persistence.EventStore.Behaviour

  alias GameBot.Infrastructure.Persistence.Error
  alias GameBot.Infrastructure.Persistence.EventStore.{Behaviour, Serializer}
  alias EventStore.{EventData, RecordedEvent}

  require Logger

  # Configuration - using direct values instead of compile_env to avoid issues
  @max_append_retries 3
  @max_stream_size 10_000
  @base_backoff_delay 100

  # Use an environment-based approach to determine the store implementation
  @store (case Mix.env() do
    :test -> GameBot.TestEventStore
    _ -> GameBot.Infrastructure.Persistence.EventStore.Postgres
  end)

  # Configuration for retry mechanism - direct values
  @max_retries 3
  @initial_backoff_ms 50

  @doc """
  Append events to a stream with optimistic concurrency control.
  """
  @impl Behaviour
  @spec append_to_stream(String.t(), non_neg_integer() | :any | :no_stream | :stream_exists, [struct()], keyword()) ::
    {:ok, non_neg_integer()} | {:error, term()}
  def append_to_stream(stream_id, expected_version, events, opts \\ []) do
    with {:ok, event_data} <- Serializer.serialize_events(events) do
      case @store.safe_append_to_stream(stream_id, expected_version, event_data, opts) do
        {:ok, version} -> {:ok, version}
        {:error, reason} -> {:error, transform_error(reason)}
      end
    end
  end

  @doc """
  Read events from a stream in forward order.
  """
  @impl Behaviour
  @spec read_stream_forward(String.t(), non_neg_integer(), pos_integer(), keyword()) ::
    {:ok, [struct()]} | {:error, term()}
  def read_stream_forward(stream_id, start_version \\ 0, count \\ 1000, _opts \\ []) do
    case @store.safe_read_stream_forward(stream_id, start_version, count) do
      {:ok, events} ->
        # Process each event with deserialize, collecting results
        events
        |> Enum.reduce_while({:ok, []}, fn event, {:ok, acc} ->
          case Serializer.deserialize(event.data) do
            {:ok, deserialized} -> {:cont, {:ok, [deserialized | acc]}}
            {:error, reason} -> {:halt, {:error, transform_error(reason)}}
          end
        end)
        |> case do
          {:ok, deserialized_events} -> {:ok, Enum.reverse(deserialized_events)}
          error -> error
        end
      {:error, reason} -> {:error, transform_error(reason)}
    end
  end

  @doc """
  Subscribe to a stream with monitoring.
  """
  @impl Behaviour
  def subscribe_to_stream(stream_id, subscriber, subscription_options \\ [], _opts \\ []) do
    options = process_subscription_options(subscription_options)

    with_retries("subscribe", fn ->
      try do
        case @store.subscribe_to_stream(stream_id, subscriber, options) do
          {:ok, subscription} ->
            {:ok, subscription}
          {:error, :stream_not_found} ->
            {:error, not_found_error(stream_id)}
          {:error, reason} ->
            {:error, system_error("Subscribe failed", reason)}
        end
      rescue
        e in DBConnection.ConnectionError ->
          {:error, connection_error(e)}
        e ->
          {:error, system_error("Subscribe failed", e)}
      end
    end)
  end

  @doc """
  Get the current version of a stream.
  """
  @impl Behaviour
  @spec stream_version(String.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def stream_version(stream_id) do
    case @store.safe_stream_version(stream_id) do
      {:ok, version} -> {:ok, version}
      {:error, reason} -> {:error, transform_error(reason)}
    end
  end

  @doc """
  Convenience function to append events with any version.
  """
  def append_events(stream_id, events, opts \\ []) do
    append_to_stream(stream_id, :any, events, opts)
  end

  @doc """
  Convenience function to read all events from a stream.
  """
  def read_events(stream_id, opts \\ []) do
    read_stream_forward(stream_id, 0, 1000, opts)
  end

  # Private Functions

  defp validate_events(events) when is_list(events), do: :ok
  defp validate_events(events), do: {:error, validation_error("Events must be a list", events)}

  defp validate_stream_size(stream_id) do
    case stream_version(stream_id) do
      {:ok, version} when version >= @max_stream_size ->
        {:error, stream_size_error(stream_id, version)}
      _ ->
        :ok
    end
  end

  defp prepare_events(events) when is_list(events) do
    {:ok, Enum.map(events, &to_event_data/1)}
  end
  defp prepare_events(_), do: {:error, validation_error("Events must be a list", nil)}

  defp to_event_data(event) do
    %EventData{
      event_type: to_string(event.event_type),
      data: event,
      metadata: %{}
    }
  end

  defp do_append_with_retry(stream_id, expected_version, event_data, opts) do
    timeout = Keyword.get(opts, :timeout, 5000)
    retry_count = Keyword.get(opts, :retry_count, @max_append_retries)

    case do_append_with_timeout(stream_id, expected_version, event_data, timeout) do
      {:error, %Error{type: :connection}} when retry_count > 0 ->
        Process.sleep(exponential_backoff(retry_count))
        do_append_with_retry(stream_id, expected_version, event_data, [
          {:timeout, timeout},
          {:retry_count, retry_count - 1}
        ])
      {:error, %Error{type: :system, details: :connection_error}} when retry_count > 0 ->
        Process.sleep(exponential_backoff(retry_count))
        do_append_with_retry(stream_id, expected_version, event_data, [
          {:timeout, timeout},
          {:retry_count, retry_count - 1}
        ])
      {:ok, _} = result ->
        # Extract the original events from the event_data
        events = Enum.map(event_data, fn %EventData{data: data} -> data end)
        {:ok, events}
      error ->
        error
    end
  end

  defp do_append_with_timeout(stream_id, expected_version, event_data, timeout) do
    task = Task.async(fn ->
      with_retries("append", fn ->
        try do
          case @store.append_to_stream(stream_id, expected_version, event_data) do
            :ok ->
              {:ok, :appended}
            {:error, :wrong_expected_version} ->
              {:error, concurrency_error(expected_version, stream_id, length(event_data))}
            {:error, reason} ->
              {:error, transform_error(:append, reason, stream_id, expected_version, event_data, [])}
          end
        rescue
          e in DBConnection.ConnectionError ->
            {:error, connection_error(e)}
          e ->
            {:error, transform_error(:append, e, stream_id, expected_version, event_data, [])}
        end
      end)
    end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, timeout_error(stream_id, timeout)}
    end
  end

  defp extract_event_data(%RecordedEvent{data: data}), do: data
  defp extract_event_data(%EventData{data: data}), do: data.data

  defp process_subscription_options(options) do
    Enum.reduce(options, [], fn
      {:start_from, :origin}, acc -> [{:start_from, :origin} | acc]
      {:start_from, version}, acc when is_integer(version) -> [{:start_from, version} | acc]
      {:include_existing, value}, acc when is_boolean(value) -> [{:include_existing, value} | acc]
      _, acc -> acc
    end)
  end

  defp exponential_backoff(retry) do
    trunc(:math.pow(2, @max_append_retries - retry) * @base_backoff_delay)
  end

  # Improved error handling for reliability
  defp with_retries(operation, func, retry_count \\ 0) do
    try do
      case func.() do
        {:error, :connection_error} ->
          if retry_count < @max_retries do
            delay = calculate_backoff(retry_count)
            Logger.warning("#{operation} failed with connection error, retrying in #{delay}ms (attempt #{retry_count + 1}/#{@max_retries})")
            Process.sleep(delay)
            with_retries(operation, func, retry_count + 1)
          else
            {:error, connection_error("Max retries exceeded")}
          end
        other -> other
      end
    rescue
      e in DBConnection.ConnectionError ->
        if retry_count < @max_retries do
          delay = calculate_backoff(retry_count)
          Logger.warning("#{operation} failed with connection error, retrying in #{delay}ms (attempt #{retry_count + 1}/#{@max_retries})")
          Process.sleep(delay)
          with_retries(operation, func, retry_count + 1)
        else
          {:error, connection_error(e)}
        end
      e ->
        {:error, system_error("#{operation} failed", e)}
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

  # Error Helpers - Improved for better error reporting
  defp validation_error(message, details), do:
    %Error{type: :validation, __exception__: true, context: __MODULE__, message: message, details: details}

  defp stream_size_error(stream_id, size), do:
    %Error{type: :stream_too_large, __exception__: true, context: __MODULE__,
           message: "Stream '#{stream_id}' exceeds maximum size of #{@max_stream_size}",
           details: %{stream_id: stream_id, current_size: size, max_size: @max_stream_size}}

  defp timeout_error(stream_id, timeout), do:
    %Error{type: :timeout, __exception__: true, context: __MODULE__,
           message: "Operation on stream '#{stream_id}' timed out after #{timeout}ms",
           details: %{stream_id: stream_id, timeout: timeout, timestamp: DateTime.utc_now()}}

  defp concurrency_error(expected_version, stream_id, event_count) do
    %Error{
      type: :concurrency,
      __exception__: true,
      context: __MODULE__,
      message: "Wrong expected version",
      details: %{
        expected: expected_version,
        stream_id: stream_id,
        event_count: event_count,
        timestamp: DateTime.utc_now()
      }
    }
  end

  defp not_found_error(stream_id) do
    %Error{
      type: :not_found,
      __exception__: true,
      context: __MODULE__,
      message: "Stream not found",
      details: %{stream_id: stream_id, timestamp: DateTime.utc_now()}
    }
  end

  defp connection_error(error) do
    %Error{
      type: :connection,
      __exception__: true,
      context: __MODULE__,
      message: "Database connection error",
      details: %{error: error, retryable: true, timestamp: DateTime.utc_now()}
    }
  end

  defp system_error(message, error) do
    %Error{
      type: :system,
      __exception__: true,
      context: __MODULE__,
      message: message,
      details: error
    }
  end

  # Enhanced error transformation functions
  defp transform_error(:append, error, stream_id, version, events, _opts) do
    case error do
      # If we already have a properly formatted error, return it as is
      %Error{} = err ->
        err

      # For any other type of error, convert to a standard format
      _ ->
        %Error{
          type: :unknown,
          __exception__: true,
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
      # First check if it's already a properly formatted error
      %Error{} = err when err.type in [:not_found, :connection, :validation, :timeout] ->
        # Just add extra context info
        %{err |
          details: Map.merge(err.details || %{}, %{
            stream_id: stream_id,
            start_version: start_version,
            count: count,
            timestamp: DateTime.utc_now()
          })
        }

      # Special handling for system errors
      %Error{type: :system} = err ->
        # Check if this is actually a connection error
        if is_connection_error?(err.details) do
          # Convert to connection error for consistent handling
          %Error{
            type: :connection,
            __exception__: true,
            context: __MODULE__,
            message: "Connection error while reading stream '#{stream_id}'",
            details: %{
              stream_id: stream_id,
              start_version: start_version,
              count: count,
              original_error: err.details,
              retryable: true,
              timestamp: DateTime.utc_now()
            }
          }
        else
          # Keep as system error but enhance details
          %{err |
            details: Map.merge(
              (if is_map(err.details), do: err.details, else: %{original: err.details}),
              %{
                stream_id: stream_id,
                start_version: start_version,
                count: count,
                timestamp: DateTime.utc_now()
              }
            )
          }
        end

      # For any other type of error, convert to a standard format
      _ ->
        %Error{
          type: :unknown,
          __exception__: true,
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

  # Helper to determine if an error is connection-related
  defp is_connection_error?(details) do
    cond do
      details == :connection_error -> true
      is_binary(details) && String.contains?(details, "connection") -> true
      is_exception(details) && details.__struct__ == DBConnection.ConnectionError -> true
      is_map(details) && Map.get(details, :reason) == :connection_error -> true
      true -> false
    end
  end

  # General error transformation for simpler cases
  defp transform_error(error) do
    case error do
      # If we already have a properly formatted error, return it as is
      %Error{} = err ->
        err

      :stream_not_found ->
        %Error{
          type: :not_found,
          __exception__: true,
          context: __MODULE__,
          message: "Stream not found",
          details: %{timestamp: DateTime.utc_now()}
        }

      :wrong_expected_version ->
        %Error{
          type: :concurrency,
          __exception__: true,
          context: __MODULE__,
          message: "Wrong expected version",
          details: %{timestamp: DateTime.utc_now()}
        }

      error when is_exception(error) and error.__struct__ == DBConnection.ConnectionError ->
        connection_error(error)

      # For any other type of error, convert to a standard format
      _ ->
        %Error{
          type: :unknown,
          __exception__: true,
          context: __MODULE__,
          message: "Unknown error: #{inspect(error)}",
          details: %{
            error: inspect(error),
            timestamp: DateTime.utc_now()
          }
        }
    end
  end
end
