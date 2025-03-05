defmodule GameBot.Infrastructure.Persistence.EventStore.Adapter do
  @moduledoc """
  Adapter layer for EventStore providing validation, serialization, and monitoring.
  """

  alias GameBot.Infrastructure.Persistence.Error
  alias GameBot.Infrastructure.Persistence.EventStore.{Behaviour, Serializer}

  # Configuration
  @max_append_retries Application.compile_env(:game_bot, [EventStore, :max_append_retries], 3)
  @max_stream_size Application.compile_env(:game_bot, [EventStore, :max_stream_size], 10_000)
  @base_backoff_delay 100

  @store Application.compile_env(:game_bot, [EventStore, :implementation],
    GameBot.Infrastructure.Persistence.EventStore.Postgres)

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
end
