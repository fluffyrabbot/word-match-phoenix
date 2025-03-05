defmodule GameBot.TestEventStore do
  @moduledoc """
  In-memory event store implementation for testing.
  """
  alias GameBot.Infrastructure.EventStore.{Error, Serializer}

  @behaviour EventStore

  # State
  @events_table :test_events
  @streams_table :test_streams

  def start_link do
    :ets.new(@events_table, [:set, :public, :named_table])
    :ets.new(@streams_table, [:set, :public, :named_table])
    {:ok, self()}
  end

  def reset do
    :ets.delete_all_objects(@events_table)
    :ets.delete_all_objects(@streams_table)
    :ok
  end

  @impl true
  def append_to_stream(stream_id, expected_version, events, _opts) when not is_list(events) do
    {:error, %Error{
      type: :validation,
      message: "Events must be a list",
      details: %{events: events}
    }}
  end

  @impl true
  def append_to_stream(stream_id, expected_version, events, _opts) do
    with :ok <- validate_version(stream_id, expected_version),
         {:ok, serialized} <- serialize_events(events) do
      do_append(stream_id, serialized)
    end
  end

  @impl true
  def read_stream_forward(stream_id, start_version \\ 0, count \\ 1000, _opts \\ []) do
    case get_stream_events(stream_id) do
      [] -> {:error, %Error{type: :not_found, message: "Stream not found", details: stream_id}}
      events -> {:ok, Enum.slice(events, start_version, count)}
    end
  end

  @impl true
  def subscribe_to_stream(stream_id, subscriber, _options \\ [], _opts \\ []) do
    {:ok, spawn_link(fn -> stream_events(stream_id, subscriber) end)}
  end

  # Private Functions

  defp validate_version(stream_id, expected_version) do
    current_version = get_stream_version(stream_id)

    cond do
      expected_version == :any -> :ok
      expected_version == current_version -> :ok
      true -> {:error, %Error{
        type: :concurrency,
        message: "Wrong expected version",
        details: %{
          stream_id: stream_id,
          expected: expected_version,
          actual: current_version
        }
      }}
    end
  end

  defp get_stream_version(stream_id) do
    case :ets.lookup(@streams_table, stream_id) do
      [{^stream_id, version}] -> version
      [] -> -1
    end
  end

  defp get_stream_events(stream_id) do
    :ets.match_object(@events_table, {stream_id, :_, :_})
    |> Enum.sort_by(fn {_, version, _} -> version end)
    |> Enum.map(fn {_, _, event} -> event end)
  end

  defp do_append(stream_id, events) do
    version = get_stream_version(stream_id) + 1

    Enum.with_index(events, version)
    |> Enum.each(fn {event, v} ->
      :ets.insert(@events_table, {stream_id, v, event})
    end)

    :ets.insert(@streams_table, {stream_id, version + length(events) - 1})
    {:ok, events}
  end

  defp serialize_events(events) do
    events
    |> Enum.map(&Serializer.serialize/1)
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

  defp stream_events(stream_id, subscriber) do
    receive do
      {:append, events} ->
        send(subscriber, {:events, events})
        stream_events(stream_id, subscriber)
      :stop ->
        :ok
    end
  end
end
