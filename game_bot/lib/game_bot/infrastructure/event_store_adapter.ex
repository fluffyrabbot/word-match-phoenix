defmodule GameBot.Infrastructure.EventStoreAdapter do
  @moduledoc """
  Adapter layer for EventStore that provides:
  - Event validation
  - Serialization/deserialization
  - Error handling and retries
  - Stream size limits
  - Monitoring and telemetry

  This is the main interface that should be used for event storage.

  ## Usage Examples

      # Append events to a stream
      {:ok, events} = EventStoreAdapter.append_to_stream("game-123", 0, [event])

      # Read events forward
      {:ok, events} = EventStoreAdapter.read_stream_forward("game-123")

      # Subscribe to a stream
      {:ok, subscription} = EventStoreAdapter.subscribe_to_stream("game-123", self())
  """

  alias GameBot.Infrastructure.EventStore
  alias GameBot.Infrastructure.EventStore.Serializer
  alias GameBot.Domain.Events.EventStructure

  # Configuration
  @max_append_retries Application.compile_env(:game_bot, [EventStore, :max_append_retries], 3)
  @max_stream_size Application.compile_env(:game_bot, [EventStore, :max_stream_size], 10_000)
  @base_backoff_delay 100

  defmodule Error do
    @moduledoc false

    @type error_type ::
      :connection |
      :serialization |
      :validation |
      :not_found |
      :concurrency |
      :timeout |
      :system |
      :stream_too_large

    @type t :: %__MODULE__{
      type: error_type(),
      message: String.t(),
      details: term()
    }

    defexception [:type, :message, :details]

    @impl true
    def message(%{type: type, message: msg, details: details}) do
      "EventStore error (#{type}): #{msg}\nDetails: #{inspect(details)}"
    end
  end

  @doc """
  Append events to a stream with validation and retries.

  ## Parameters
    * `stream_id` - Unique identifier for the event stream
    * `expected_version` - Expected version for optimistic concurrency
    * `events` - List of event structs to append
    * `opts` - Optional parameters:
      * `:timeout` - Operation timeout in milliseconds (default: 5000)
      * `:retry_count` - Number of retries (default: 3)
  """
  def append_to_stream(stream_id, expected_version, events, opts \\ []) do
    with :ok <- validate_event_list(events),
         :ok <- validate_event_structures(events),
         :ok <- validate_stream_size(stream_id),
         {:ok, serialized} <- serialize_events(events) do
      do_append_with_retry(stream_id, expected_version, serialized, opts)
    end
  end

  @doc """
  Read events from a stream with deserialization.
  """
  def read_stream_forward(stream_id, start_version \\ 0, count \\ 1000, opts \\ []) do
    with {:ok, events} <- EventStore.read_stream_forward(stream_id, start_version, count, opts),
         {:ok, deserialized} <- deserialize_events(events) do
      {:ok, deserialized}
    end
  end

  @doc """
  Subscribe to a stream with monitoring.
  """
  def subscribe_to_stream(stream_id, subscriber, subscription_options \\ [], opts \\ []) do
    with {:ok, subscription} <- EventStore.subscribe_to_stream(stream_id, subscriber, subscription_options, opts) do
      Process.monitor(subscription)
      {:ok, subscription}
    end
  end

  @doc """
  Validate a list of events to ensure they are properly structured.

  ## Parameters
    * `events` - List of event structs to validate

  ## Returns
    * `:ok` - All events are valid
    * `{:error, reason}` - Validation failed
  """
  @spec validate_event_structures([struct()]) :: :ok | {:error, Error.t()}
  def validate_event_structures(events) do
    Enum.reduce_while(events, :ok, fn event, _ ->
      case EventStructure.validate(event) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  @doc """
  Serialize a list of events for storage.

  ## Parameters
    * `events` - List of event structs to serialize

  ## Returns
    * `{:ok, serialized}` - Events serialized successfully
    * `{:error, reason}` - Serialization failed
  """
  @spec serialize_events([struct()]) :: {:ok, [map()]} | {:error, Error.t()}
  def serialize_events(events) do
    events
    |> Enum.map(&Serializer.serialize/1)
    |> collect_results()
  end

  # Private Functions

  defp validate_event_list(events) when is_list(events), do: :ok
  defp validate_event_list(events), do: {:error, validation_error("Events must be a list", events)}

  defp validate_stream_size(stream_id) do
    case EventStore.stream_version(stream_id) do
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
      EventStore.append_to_stream(stream_id, expected_version, events)
    end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, timeout_error(stream_id, timeout)}
    end
  end

  defp deserialize_events(events) do
    events
    |> Enum.map(&Serializer.deserialize(&1.data))
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

  defp validation_error(message, details), do: %Error{type: :validation, message: message, details: details}
  defp stream_size_error(stream_id, size), do: %Error{type: :stream_too_large, message: "Stream exceeds maximum size", details: %{stream_id: stream_id, current_size: size, max_size: @max_stream_size}}
  defp timeout_error(stream_id, timeout), do: %Error{type: :timeout, message: "Operation timed out", details: %{stream_id: stream_id, timeout: timeout}}
end
