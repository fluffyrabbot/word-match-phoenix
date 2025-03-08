defmodule GameBot.Test.Mocks.EventStore do
  @moduledoc """
  Mock implementation of the EventStore behaviour for testing.
  """

  @behaviour GameBot.Infrastructure.Persistence.EventStore.Adapter.Behaviour
  # Also implement the EventStore behavior
  @behaviour EventStore

  use GenServer
  alias GameBot.Infrastructure.Persistence.Error

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def set_failure_count(count) do
    GenServer.call(__MODULE__, {:set_failure_count, count})
  end

  def get_failure_count do
    GenServer.call(__MODULE__, :get_failure_count)
  end

  def set_delay(milliseconds) do
    GenServer.call(__MODULE__, {:set_delay, milliseconds})
  end

  def reset_state do
    GenServer.call(__MODULE__, :reset_state)
  end

  # For compatibility with other test utilities
  def reset! do
    reset_state()
  end

  # For testing retry mechanism
  def set_track_retries(enable) do
    GenServer.call(__MODULE__, {:set_track_retries, enable})
  end

  def get_retry_delays do
    GenServer.call(__MODULE__, :get_retry_delays)
  end

  # EventStore Behavior Implementation

  @impl EventStore
  def config do
    Application.get_env(:game_bot, __MODULE__, [])
  end

  @impl EventStore
  def init(config) do
    {:ok, config}
  end

  @impl EventStore
  def stop(_server, _timeout \\ :infinity) do
    :ok
  end

  @impl EventStore
  def subscribe(_subscriber, _subscription_options) do
    {:ok, make_ref()}
  end

  @impl EventStore
  def subscribe_to_all_streams(_name, _subscriber, _subscription_options) do
    {:ok, make_ref()}
  end

  @impl EventStore
  def unsubscribe_from_all_streams(_subscription, _opts \\ []) do
    :ok
  end

  @impl EventStore
  def ack(_subscription, _events) do
    :ok
  end

  @impl EventStore
  def unsubscribe_from_stream(_stream_id, _subscription, _opts \\ []) do
    :ok
  end

  @impl EventStore
  def delete_subscription(_stream_id, _subscription_name, _opts) do
    :ok
  end

  @impl EventStore
  def delete_all_streams_subscription(_subscription_name, _opts \\ []) do
    :ok
  end

  @impl EventStore
  def stream_forward(stream_id, start_version \\ 0, _opts \\ []) do
    {:ok, []}
  end

  @impl EventStore
  def stream_backward(stream_id, start_version \\ 0, _opts \\ []) do
    {:ok, []}
  end

  @impl EventStore
  def stream_all_forward(start_from \\ 0, _opts \\ []) do
    {:ok, []}
  end

  @impl EventStore
  def stream_all_backward(start_from \\ 0, _opts \\ []) do
    {:ok, []}
  end

  @impl EventStore
  def read_stream_backward(stream_id, start_version, count, _opts \\ []) do
    {:ok, []}
  end

  @impl EventStore
  def read_all_streams_forward(start_from, count, _opts \\ []) do
    {:ok, []}
  end

  @impl EventStore
  def read_all_streams_backward(start_from, count, _opts \\ []) do
    {:ok, []}
  end

  @impl EventStore
  def stream_info(stream_id, _opts \\ []) do
    {:ok, %{stream_version: 0}}
  end

  @impl EventStore
  def paginate_streams(_opts \\ []) do
    {:ok, []}
  end

  @impl EventStore
  def read_snapshot(source_uuid, _opts \\ []) do
    {:error, :snapshot_not_found}
  end

  @impl EventStore
  def record_snapshot(snapshot, _opts \\ []) do
    :ok
  end

  @impl EventStore
  def delete_snapshot(source_uuid, _opts \\ []) do
    :ok
  end

  # Adapter Behaviour Implementation

  @impl GameBot.Infrastructure.Persistence.EventStore.Adapter.Behaviour
  def append_to_stream(stream_id, version, events, opts \\ []) do
    GenServer.call(__MODULE__, {:append, stream_id, version, events, opts})
  end

  @impl GameBot.Infrastructure.Persistence.EventStore.Adapter.Behaviour
  def read_stream_forward(stream_id, start_version \\ 0, count \\ 1000, opts \\ []) do
    GenServer.call(__MODULE__, {:read, stream_id, start_version, count, opts})
  end

  @impl GameBot.Infrastructure.Persistence.EventStore.Adapter.Behaviour
  def subscribe_to_stream(stream_id, subscriber, subscription_options \\ [], opts \\ []) do
    GenServer.call(__MODULE__, {:subscribe, stream_id, subscriber, subscription_options, opts})
  end

  @impl GameBot.Infrastructure.Persistence.EventStore.Adapter.Behaviour
  def stream_version(stream_id, opts \\ []) do
    GenServer.call(__MODULE__, {:version, stream_id})
  end

  @impl GameBot.Infrastructure.Persistence.EventStore.Adapter.Behaviour
  def delete_stream(stream_id, _expected_version, _opts \\ []) do
    GenServer.call(__MODULE__, {:delete_stream, stream_id})
  end

  @impl GameBot.Infrastructure.Persistence.EventStore.Adapter.Behaviour
  def link_to_stream(source_stream_id, target_stream_id, _opts \\ []) do
    GenServer.call(__MODULE__, {:link_stream, source_stream_id, target_stream_id})
  end

  # Server Implementation

  @impl GenServer
  def init(_opts) do
    {:ok, %{
      streams: %{},
      failure_count: 0,
      delay: 0,
      track_retries: false,
      retry_delays: [],
      subscriptions: %{},
      last_attempt_time: System.monotonic_time(:millisecond)
    }}
  end

  @impl GenServer
  def handle_call({:set_failure_count, count}, _from, state) do
    {:reply, :ok, %{state | failure_count: count}}
  end

  @impl GenServer
  def handle_call(:get_failure_count, _from, state) do
    {:reply, state.failure_count, state}
  end

  @impl GenServer
  def handle_call({:set_delay, delay}, _from, state) do
    {:reply, :ok, %{state | delay: delay}}
  end

  @impl GenServer
  def handle_call(:reset_state, _from, _state) do
    {:reply, :ok, %{
      streams: %{},
      failure_count: 0,
      delay: 0,
      track_retries: false,
      retry_delays: [],
      subscriptions: %{},
      last_attempt_time: System.monotonic_time(:millisecond)
    }}
  end

  @impl GenServer
  def handle_call({:set_track_retries, enable}, _from, state) do
    {:reply, :ok, %{state |
      track_retries: enable,
      retry_delays: [],
      last_attempt_time: System.monotonic_time(:millisecond)
    }}
  end

  @impl GenServer
  def handle_call(:get_retry_delays, _from, state) do
    {:reply, state.retry_delays, state}
  end

  # Enhanced for handling retry tracking
  @impl GenServer
  def handle_call({:append, stream_id, version, events, _opts}, _from,
                 %{failure_count: failure_count, track_retries: true} = state) when failure_count > 0 do
    # Record the delay and then process normally
    now = System.monotonic_time(:millisecond)
    last_time = Map.get(state, :last_attempt_time, now)
    delay = now - last_time

    retry_delays = [delay | state.retry_delays]
    state = %{state |
      failure_count: failure_count - 1,
      retry_delays: retry_delays,
      last_attempt_time: now
    }

    # Return connection error
    {:reply, {:error, connection_error()}, state}
  end

  @impl GenServer
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
          {:reply, {:ok, length(new_stream)}, new_state}
      end
    end
  end

  @impl GenServer
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

  @impl GenServer
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

  @impl GenServer
  def handle_call({:version, stream_id}, _from, state) do
    case Map.get(state.streams, stream_id) do
      nil -> {:reply, {:ok, 0}, state}
      events -> {:reply, {:ok, length(events)}, state}
    end
  end

  @impl GenServer
  def handle_call({:delete_stream, stream_id}, _from, state) do
    # Remove the stream
    new_streams = Map.delete(state.streams, stream_id)
    {:reply, :ok, %{state | streams: new_streams}}
  end

  @impl GenServer
  def handle_call({:link_stream, source_stream_id, target_stream_id}, _from, state) do
    # Simple implementation - just copy events from source to target
    case Map.get(state.streams, source_stream_id) do
      nil ->
        {:reply, {:error, not_found_error(source_stream_id)}, state}
      source_events ->
        target_events = Map.get(state.streams, target_stream_id, [])
        new_target_events = target_events ++ source_events
        new_streams = Map.put(state.streams, target_stream_id, new_target_events)
        {:reply, :ok, %{state | streams: new_streams}}
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
