defmodule GameBot.TestEventStore do
  @moduledoc """
  In-memory implementation of EventStore for testing.
  """

  @behaviour EventStore

  use GenServer

  # State structure
  defmodule State do
    defstruct streams: %{},              # stream_id => [event]
              subscriptions: %{},         # {stream_id, subscriber} => subscription_ref
              subscribers: %{}            # subscription_ref => subscriber
  end

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def stop(server, timeout \\ :infinity) do
    GenServer.stop(server, :normal, timeout)
  end

  # EventStore Callbacks

  @impl EventStore
  def init(_opts) do
    {:ok, %State{}}
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
  def subscribe_to_stream(stream_id, subscriber, subscription_options \\ []) do
    GenServer.call(__MODULE__, {:subscribe, stream_id, subscriber, subscription_options})
  end

  @impl EventStore
  def subscribe_to_all_streams(subscription_name, subscriber, subscription_options \\ []) do
    GenServer.call(__MODULE__, {:subscribe_all, subscription_name, subscriber, subscription_options})
  end

  @impl EventStore
  def ack(subscription, events) do
    GenServer.cast(__MODULE__, {:ack, subscription, events})
  end

  @impl EventStore
  def unsubscribe_from_stream(stream_id, subscription) do
    GenServer.call(__MODULE__, {:unsubscribe, stream_id, subscription})
  end

  @impl EventStore
  def delete_subscription(stream_id, subscription_name, _opts \\ []) do
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

  # Server Callbacks

  @impl GenServer
  def handle_call({:append, stream_id, expected_version, events}, _from, state) do
    stream = Map.get(state.streams, stream_id, [])
    current_version = length(stream)

    cond do
      expected_version != current_version ->
        {:reply, {:error, :wrong_expected_version}, state}

      true ->
        new_stream = stream ++ events
        new_state = %{state | streams: Map.put(state.streams, stream_id, new_stream)}
        {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_call({:read_forward, stream_id, start_version, count}, _from, state) do
    stream = Map.get(state.streams, stream_id, [])
    events = Enum.slice(stream, start_version, count)
    {:reply, {:ok, events}, state}
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
