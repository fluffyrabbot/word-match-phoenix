defmodule GameBot.Test.Mocks.EventStore do
  @moduledoc """
  Mock EventStore implementation for testing retry mechanisms and error conditions.
  """
  @behaviour GameBot.Infrastructure.Persistence.EventStore.Behaviour

  use GenServer
  alias GameBot.Infrastructure.Persistence.Error

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def set_failure_count(count) do
    GenServer.call(__MODULE__, {:set_failure_count, count})
  end

  def set_delay(milliseconds) do
    GenServer.call(__MODULE__, {:set_delay, milliseconds})
  end

  def reset_state do
    GenServer.call(__MODULE__, :reset_state)
  end

  # Behaviour Implementation

  @impl true
  def append_to_stream(stream_id, version, events, opts \\ []) do
    GenServer.call(__MODULE__, {:append, stream_id, version, events, opts})
  end

  @impl true
  def read_stream_forward(stream_id, start_version \\ 0, count \\ 1000, opts \\ []) do
    GenServer.call(__MODULE__, {:read, stream_id, start_version, count, opts})
  end

  @impl true
  def subscribe_to_stream(stream_id, subscriber, subscription_options \\ [], opts \\ []) do
    GenServer.call(__MODULE__, {:subscribe, stream_id, subscriber, subscription_options, opts})
  end

  @impl true
  def stream_version(stream_id) do
    GenServer.call(__MODULE__, {:version, stream_id})
  end

  # Server Implementation

  @impl true
  def init(_opts) do
    {:ok, %{
      streams: %{},
      failure_count: 0,
      delay: 0,
      subscriptions: %{}
    }}
  end

  @impl true
  def handle_call({:set_failure_count, count}, _from, state) do
    {:reply, :ok, %{state | failure_count: count}}
  end

  def handle_call({:set_delay, delay}, _from, state) do
    {:reply, :ok, %{state | delay: delay}}
  end

  def handle_call(:reset_state, _from, _state) do
    {:reply, :ok, %{streams: %{}, failure_count: 0, delay: 0, subscriptions: %{}}}
  end

  def handle_call({:append, stream_id, version, events, _opts}, _from, state) do
    if state.failure_count > 0 do
      {:reply, {:error, connection_error()}, %{state | failure_count: state.failure_count - 1}}
    else
      if state.delay > 0, do: Process.sleep(state.delay)

      stream = Map.get(state.streams, stream_id, [])
      current_version = length(stream)

      cond do
        version != current_version ->
          {:reply, {:error, concurrency_error(version, current_version)}, state}
        true ->
          new_stream = stream ++ events
          new_state = put_in(state.streams[stream_id], new_stream)
          notify_subscribers(stream_id, events, state.subscriptions)
          {:reply, {:ok, events}, new_state}
      end
    end
  end

  def handle_call({:read, stream_id, start_version, count, _opts}, _from, state) do
    if state.delay > 0, do: Process.sleep(state.delay)

    case Map.get(state.streams, stream_id) do
      nil ->
        {:reply, {:error, not_found_error(stream_id)}, state}
      events ->
        result = events
        |> Enum.drop(start_version)
        |> Enum.take(count)
        {:reply, {:ok, result}, state}
    end
  end

  def handle_call({:subscribe, stream_id, subscriber, _options, _opts}, _from, state) do
    ref = make_ref()
    new_subscriptions = Map.update(
      state.subscriptions,
      stream_id,
      %{ref => subscriber},
      &Map.put(&1, ref, subscriber)
    )
    {:reply, {:ok, ref}, %{state | subscriptions: new_subscriptions}}
  end

  def handle_call({:version, stream_id}, _from, state) do
    case Map.get(state.streams, stream_id) do
      nil -> {:reply, {:ok, 0}, state}
      events -> {:reply, {:ok, length(events)}, state}
    end
  end

  # Private Functions

  defp notify_subscribers(stream_id, events, subscriptions) do
    case Map.get(subscriptions, stream_id) do
      nil -> :ok
      subscribers ->
        Enum.each(subscribers, fn {_ref, pid} ->
          send(pid, {:events, events})
        end)
    end
  end

  defp connection_error do
    %Error{
      type: :connection,
      context: __MODULE__,
      message: "Simulated connection error",
      details: %{retryable: true}
    }
  end

  defp concurrency_error(expected, actual) do
    %Error{
      type: :concurrency,
      context: __MODULE__,
      message: "Wrong expected version",
      details: %{expected: expected, actual: actual}
    }
  end

  defp not_found_error(stream_id) do
    %Error{
      type: :not_found,
      context: __MODULE__,
      message: "Stream not found",
      details: %{stream_id: stream_id}
    }
  end
end
