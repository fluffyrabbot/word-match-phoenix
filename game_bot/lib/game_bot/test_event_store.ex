defmodule GameBot.TestEventStore do
  @moduledoc """
  In-memory implementation of EventStore for testing.
  Implements both EventStore behavior for the interface and GenServer for the implementation.
  """

  @behaviour EventStore

  use GenServer

  # State structure
  defmodule State do
    defstruct streams: %{},              # stream_id => [event]
              subscriptions: %{},         # {stream_id, subscriber} => subscription_ref
              subscribers: %{},           # subscription_ref => subscriber
              failure_count: 0,           # Number of times to fail before succeeding
              track_retries: false,       # Whether to track retry attempts
              retry_delays: [],           # List of delays between retry attempts
              last_attempt_time: nil      # Timestamp of last attempt for tracking delays
  end

  # Client API

  @doc """
  Starts the test event store.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Stops the test event store.
  """
  def stop(server, timeout \\ :infinity) do
    case server do
      pid when is_pid(pid) ->
        if Process.alive?(pid) do
          GenServer.stop(pid, :normal, timeout)
        else
          :ok
        end
      name when is_atom(name) ->
        case Process.whereis(name) do
          nil -> :ok
          pid -> GenServer.stop(pid, :normal, timeout)
        end
      _ ->
        :ok
    end
  end

  @doc """
  Resets the test store state and clears all connections.
  Ensures compatibility with test helpers that expect this function.
  """
  def reset! do
    case Process.whereis(__MODULE__) do
      nil ->
        # If the process is not running, simply return ok
        :ok
      _pid ->
        # Reset internal state
        reset_state()

        # Return success
        :ok
    end
  end

  @doc """
  Sets the number of times operations should fail before succeeding.
  Used for testing retry mechanisms.
  """
  def set_failure_count(count) when is_integer(count) and count >= 0 do
    GenServer.call(__MODULE__, {:set_failure_count, count})
  end

  @doc """
  Gets the current failure count.
  """
  def get_failure_count do
    GenServer.call(__MODULE__, :get_failure_count)
  end

  @doc """
  Resets the state of the test event store.
  """
  def reset_state do
    GenServer.call(__MODULE__, :reset_state)
  end

  @doc """
  Enables or disables tracking of retries.
  """
  def set_track_retries(enable) when is_boolean(enable) do
    GenServer.call(__MODULE__, {:set_track_retries, enable})
  end

  @doc """
  Returns the delays between retry attempts.
  """
  def get_retry_delays do
    GenServer.call(__MODULE__, :get_retry_delays)
  end

  @doc """
  Gets the current version of a stream.
  """
  def stream_version(stream_id) do
    GenServer.call(__MODULE__, {:version, stream_id})
  end

  # EventStore Behaviour Callbacks

  @impl EventStore
  def init(config) do
    {:ok, config}
  end

  @impl EventStore
  def config do
    Application.get_env(:game_bot, __MODULE__, [])
  end

  @impl EventStore
  def subscribe(subscriber, subscription_options) do
    GenServer.call(__MODULE__, {:subscribe_all, subscriber, subscription_options})
  end

  @impl EventStore
  def unsubscribe_from_all_streams(subscription, _opts \\ []) do
    GenServer.call(__MODULE__, {:unsubscribe_all, subscription})
  end

  @impl EventStore
  def append_to_stream(stream_id, expected_version, events, _opts \\ []) when is_list(events) do
    GenServer.call(__MODULE__, {:append, stream_id, expected_version, events})
  end

  @impl EventStore
  def read_stream_forward(stream_id, start_version, count, _opts \\ []) do
    GenServer.call(__MODULE__, {:read_forward, stream_id, start_version, count})
  end

  @impl EventStore
  def read_stream_backward(stream_id, start_version, count, _opts \\ []) do
    GenServer.call(__MODULE__, {:read_backward, stream_id, start_version, count})
  end

  @impl EventStore
  def read_all_streams_forward(start_from, count, _opts \\ []) do
    GenServer.call(__MODULE__, {:read_all_forward, start_from, count})
  end

  @impl EventStore
  def read_all_streams_backward(start_from, count, _opts \\ []) do
    GenServer.call(__MODULE__, {:read_all_backward, start_from, count})
  end

  @impl EventStore
  def subscribe_to_stream(stream_id, subscriber, subscription_options \\ [], _opts \\ []) do
    GenServer.call(__MODULE__, {:subscribe, stream_id, subscriber, subscription_options})
  end

  @impl EventStore
  def subscribe_to_all_streams(subscription_name, subscriber, subscription_options) do
    GenServer.call(__MODULE__, {:subscribe_all, subscription_name, subscriber, subscription_options})
  end

  @impl EventStore
  def ack(subscription, events) do
    GenServer.cast(__MODULE__, {:ack, subscription, events})
  end

  @impl EventStore
  def unsubscribe_from_stream(stream_id, subscription, _opts \\ []) do
    GenServer.call(__MODULE__, {:unsubscribe, stream_id, subscription})
  end

  @impl EventStore
  def delete_subscription(stream_id, subscription_name, _opts) do
    GenServer.call(__MODULE__, {:delete_subscription, stream_id, subscription_name})
  end

  @impl EventStore
  def delete_all_streams_subscription(subscription_name, _opts \\ []) do
    GenServer.call(__MODULE__, {:delete_all_subscription, subscription_name})
  end

  @impl EventStore
  def stream_forward(stream_id, start_version \\ 0, _opts \\ []) do
    GenServer.call(__MODULE__, {:stream_forward, stream_id, start_version})
  end

  @impl EventStore
  def stream_backward(stream_id, start_version \\ 0, _opts \\ []) do
    GenServer.call(__MODULE__, {:stream_backward, stream_id, start_version})
  end

  @impl EventStore
  def stream_all_forward(start_from \\ 0, _opts \\ []) do
    GenServer.call(__MODULE__, {:stream_all_forward, start_from})
  end

  @impl EventStore
  def stream_all_backward(start_from \\ 0, _opts \\ []) do
    GenServer.call(__MODULE__, {:stream_all_backward, start_from})
  end

  @impl EventStore
  def delete_stream(stream_id, expected_version \\ 0, hard_delete \\ false, _opts \\ []) do
    GenServer.call(__MODULE__, {:delete_stream, stream_id, expected_version, hard_delete})
  end

  @impl EventStore
  def link_to_stream(stream_id, expected_version, event_numbers, _opts \\ []) do
    GenServer.call(__MODULE__, {:link_to_stream, stream_id, expected_version, event_numbers})
  end

  @impl EventStore
  def stream_info(stream_id, _opts \\ []) do
    GenServer.call(__MODULE__, {:stream_info, stream_id})
  end

  @impl EventStore
  def paginate_streams(_opts \\ []) do
    GenServer.call(__MODULE__, :paginate_streams)
  end

  @impl EventStore
  def read_snapshot(source_uuid, _opts \\ []) do
    GenServer.call(__MODULE__, {:read_snapshot, source_uuid})
  end

  @impl EventStore
  def record_snapshot(snapshot, _opts \\ []) do
    GenServer.call(__MODULE__, {:record_snapshot, snapshot})
  end

  @impl EventStore
  def delete_snapshot(source_uuid, _opts \\ []) do
    GenServer.call(__MODULE__, {:delete_snapshot, source_uuid})
  end

  @impl EventStore
  def handle_call({:unsubscribe_all, subscription}, _from, state) do
    new_state = %{state |
      subscriptions: Map.delete(state.subscriptions, subscription),
      subscribers: Map.delete(state.subscribers, subscription)
    }
    {:reply, :ok, new_state}
  end

  # GenServer Callbacks

  @impl GenServer
  def init(_) do
    {:ok, %State{}}
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
  def handle_call(:reset_state, _from, _state) do
    {:reply, :ok, %State{}}
  end

  @impl GenServer
  def handle_call({:set_track_retries, enable}, _from, state) do
    new_state = Map.put(state, :track_retries, enable)
    new_state = Map.put(new_state, :retry_delays, [])
    new_state = Map.put(new_state, :last_attempt_time, System.monotonic_time(:millisecond))
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_retry_delays, _from, state) do
    delays = Map.get(state, :retry_delays, [])
    {:reply, delays, state}
  end

  @impl GenServer
  def handle_call({:version, stream_id}, _from, state) do
    case Map.get(state.streams, stream_id) do
      nil -> {:reply, {:ok, 0}, state}
      events -> {:reply, {:ok, length(events)}, state}
    end
  end

  @impl GenServer
  def handle_call({:append, stream_id, expected_version, events}, _from, %{track_retries: true, failure_count: failure_count} = state) when failure_count > 0 do
    # Record the delay since the last attempt
    now = System.monotonic_time(:millisecond)
    last_time = Map.get(state, :last_attempt_time, now)
    delay = now - last_time

    # Update retry tracking state
    retry_delays = [delay | Map.get(state, :retry_delays, [])]
    new_state = %{state |
      failure_count: failure_count - 1,
      retry_delays: retry_delays,
      last_attempt_time: now
    }

    # Return proper connection error structure
    {:reply, {:error, %GameBot.Infrastructure.Persistence.Error{
      type: :connection,
      __exception__: true,
      context: __MODULE__,
      message: "Simulated connection error for testing",
      details: %{
        stream_id: stream_id,
        retryable: true,
        timestamp: DateTime.utc_now()
      }
    }}, new_state}
  end

  @impl GenServer
  def handle_call({:append, stream_id, expected_version, events}, _from, state) do
    if state.failure_count > 0 do
      # Return proper connection error structure
      {:reply, {:error, %GameBot.Infrastructure.Persistence.Error{
        type: :connection,
        __exception__: true,
        context: __MODULE__,
        message: "Simulated connection error for testing",
        details: %{
          stream_id: stream_id,
          retryable: true,
          timestamp: DateTime.utc_now()
        }
      }}, %{state | failure_count: state.failure_count - 1}}
    else
      stream = Map.get(state.streams, stream_id, [])
      current_version = length(stream)

      cond do
        expected_version != current_version and expected_version != :any ->
          {:reply, {:error, %GameBot.Infrastructure.Persistence.Error{
            type: :concurrency,
            __exception__: true,
            context: __MODULE__,
            message: "Wrong expected version",
            details: %{
              expected: expected_version,
              stream_id: stream_id,
              event_count: length(events),
              timestamp: DateTime.utc_now()
            }
          }}, state}

        true ->
          new_stream = stream ++ events
          new_state = %{state | streams: Map.put(state.streams, stream_id, new_stream)}
          {:reply, :ok, new_state}
      end
    end
  end

  @impl GenServer
  def handle_call({:read_forward, stream_id, start_version, count}, _from, state) do
    if state.failure_count > 0 do
      {:reply, {:error, %GameBot.Infrastructure.Persistence.Error{
        type: :connection,
        __exception__: true,
        context: __MODULE__,
        message: "Simulated connection error for testing",
        details: %{
          stream_id: stream_id,
          retryable: true,
          timestamp: DateTime.utc_now()
        }
      }}, %{state | failure_count: state.failure_count - 1}}
    else
      stream = Map.get(state.streams, stream_id, [])
      events = Enum.slice(stream, start_version, count)
      {:reply, {:ok, events}, state}
    end
  end

  @impl GenServer
  def handle_call({:read_backward, stream_id, start_version, count}, _from, state) do
    stream = Map.get(state.streams, stream_id, [])
    events = stream |> Enum.reverse() |> Enum.slice(start_version, count)
    {:reply, {:ok, events}, state}
  end

  @impl GenServer
  def handle_call({:read_all_forward, _start_from, _count}, _from, state) do
    events = state.streams |> Map.values() |> List.flatten()
    {:reply, {:ok, events}, state}
  end

  @impl GenServer
  def handle_call({:read_all_backward, _start_from, _count}, _from, state) do
    events = state.streams |> Map.values() |> List.flatten() |> Enum.reverse()
    {:reply, {:ok, events}, state}
  end

  @impl GenServer
  def handle_call({:subscribe, stream_id, subscriber, _options}, _from, state) do
    subscription = make_ref()
    new_state = %{state |
      subscriptions: Map.put(state.subscriptions, subscription, stream_id),
      subscribers: Map.put(state.subscribers, subscription, subscriber)
    }
    {:reply, {:ok, subscription}, new_state}
  end

  @impl GenServer
  def handle_call({:subscribe_all, _name, subscriber, _options}, _from, state) do
    subscription = make_ref()
    new_state = %{state |
      subscriptions: Map.put(state.subscriptions, subscription, :all),
      subscribers: Map.put(state.subscribers, subscription, subscriber)
    }
    {:reply, {:ok, subscription}, new_state}
  end

  @impl GenServer
  def handle_cast({:ack, _subscription, _events}, state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:unsubscribe, _stream_id, subscription}, _from, state) do
    new_state = %{state |
      subscriptions: Map.delete(state.subscriptions, subscription),
      subscribers: Map.delete(state.subscribers, subscription)
    }
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:delete_subscription, _stream_id, _subscription_name}, _from, state) do
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:delete_all_subscription, _subscription_name}, _from, state) do
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:stream_forward, stream_id, start_version}, _from, state) do
    stream = Map.get(state.streams, stream_id, [])
    events = Enum.drop(stream, start_version)
    {:reply, {:ok, events}, state}
  end

  @impl GenServer
  def handle_call({:stream_backward, stream_id, start_version}, _from, state) do
    stream = Map.get(state.streams, stream_id, [])
    events = stream |> Enum.reverse() |> Enum.drop(start_version)
    {:reply, {:ok, events}, state}
  end

  @impl GenServer
  def handle_call({:stream_all_forward, start_from}, _from, state) do
    events = state.streams |> Map.values() |> List.flatten() |> Enum.drop(start_from)
    {:reply, {:ok, events}, state}
  end

  @impl GenServer
  def handle_call({:stream_all_backward, start_from}, _from, state) do
    events = state.streams |> Map.values() |> List.flatten() |> Enum.reverse() |> Enum.drop(start_from)
    {:reply, {:ok, events}, state}
  end

  @impl GenServer
  def handle_call({:delete_stream, stream_id, _expected_version, _hard_delete}, _from, state) do
    new_state = %{state | streams: Map.delete(state.streams, stream_id)}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:link_to_stream, stream_id, expected_version, event_numbers}, _from, state) do
    stream = Map.get(state.streams, stream_id, [])
    current_version = length(stream)

    if expected_version != current_version do
      {:reply, {:error, :wrong_expected_version}, state}
    else
      linked_events = event_numbers |> Enum.map(fn n -> Enum.at(stream, n) end) |> Enum.reject(&is_nil/1)
      new_stream = stream ++ linked_events
      new_state = %{state | streams: Map.put(state.streams, stream_id, new_stream)}
      {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_call({:stream_info, stream_id}, _from, state) do
    stream = Map.get(state.streams, stream_id, [])
    {:reply, {:ok, %{version: length(stream)}}, state}
  end

  @impl GenServer
  def handle_call(:paginate_streams, _from, state) do
    streams = state.streams |> Map.keys() |> Enum.map(&%{stream_id: &1, stream_version: length(Map.get(state.streams, &1))})
    {:reply, {:ok, streams}, state}
  end

  @impl GenServer
  def handle_call({:read_snapshot, _source_uuid}, _from, state) do
    {:reply, {:error, :snapshot_not_found}, state}
  end

  @impl GenServer
  def handle_call({:record_snapshot, _snapshot}, _from, state) do
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:delete_snapshot, _source_uuid}, _from, state) do
    {:reply, :ok, state}
  end
end
