defmodule GameBot.TestEventStore do
  @moduledoc """
  In-memory event store implementation for testing.
  """

  @behaviour EventStore

  use GenServer

  # State structure
  defmodule State do
    defstruct streams: %{},              # stream_id => [event]
              subscriptions: %{},         # {stream_id, subscriber} => subscription_ref
              subscription_options: %{},  # subscription_ref => options
              snapshots: %{}             # source_uuid => snapshot
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
  def read_stream_forward(stream_id, start_version \\ 0, count \\ 1000, _opts \\ []) do
    GenServer.call(__MODULE__, {:read_forward, stream_id, start_version, count})
  end

  @impl EventStore
  def read_stream_backward(stream_id, start_version \\ 0, count \\ 1000, _opts \\ []) do
    GenServer.call(__MODULE__, {:read_backward, stream_id, start_version, count})
  end

  @impl EventStore
  def subscribe_to_stream(stream_id, subscriber, subscription_options \\ [], _opts \\ []) do
    GenServer.call(__MODULE__, {:subscribe, stream_id, subscriber, subscription_options})
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
  def delete_stream(stream_id, _expected_version \\ :any, _hard_delete \\ false, _opts \\ []) do
    GenServer.call(__MODULE__, {:delete_stream, stream_id})
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
  def stream_forward(stream_id, start_version \\ 0, _opts \\ []) do
    GenServer.call(__MODULE__, {:stream_forward, stream_id, start_version})
  end

  @impl EventStore
  def stream_backward(stream_id, start_version \\ 0, _opts \\ []) do
    GenServer.call(__MODULE__, {:stream_backward, stream_id, start_version})
  end

  @impl EventStore
  def stream_all_forward(start_from \\ :start, _opts \\ []) do
    GenServer.call(__MODULE__, {:stream_all_forward, start_from})
  end

  @impl EventStore
  def stream_all_backward(start_from \\ :end, _opts \\ []) do
    GenServer.call(__MODULE__, {:stream_all_backward, start_from})
  end

  @impl EventStore
  def subscribe(subscriber, _opts \\ []) do
    GenServer.call(__MODULE__, {:subscribe_all, subscriber})
  end

  @impl EventStore
  def subscribe_to_all_streams(subscription_name, subscriber, subscription_options \\ [], _opts \\ []) do
    GenServer.call(__MODULE__, {:subscribe_all_named, subscription_name, subscriber, subscription_options})
  end

  @impl EventStore
  def unsubscribe_from_all_streams(subscription, _opts \\ []) do
    GenServer.call(__MODULE__, {:unsubscribe_all, subscription})
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
  def config do
    [
      serializer: EventStore.JsonSerializer,
      username: "postgres",
      password: "postgres",
      database: "eventstore_test",
      hostname: "localhost"
    ]
  end

  # Server Callbacks

  def handle_call({:append, stream_id, expected_version, events}, _from, state) do
    current_stream = Map.get(state.streams, stream_id, [])
    current_version = length(current_stream)

    cond do
      expected_version != :any && expected_version != current_version ->
        {:reply, {:error, :wrong_expected_version}, state}

      true ->
        new_stream = current_stream ++ events
        new_state = %{state | streams: Map.put(state.streams, stream_id, new_stream)}
        notify_subscribers(stream_id, events, state.subscriptions)
        {:reply, :ok, new_state}
    end
  end

  def handle_call({:read_forward, stream_id, start_version, count}, _from, state) do
    case Map.get(state.streams, stream_id) do
      nil ->
        {:reply, {:error, :stream_not_found}, state}

      events ->
        result = events
        |> Enum.drop(start_version)
        |> Enum.take(count)
        {:reply, {:ok, result}, state}
    end
  end

  def handle_call({:read_backward, stream_id, start_version, count}, _from, state) do
    case Map.get(state.streams, stream_id) do
      nil ->
        {:reply, {:error, :stream_not_found}, state}

      events ->
        result = events
        |> Enum.reverse()
        |> Enum.drop(start_version)
        |> Enum.take(count)
        {:reply, {:ok, result}, state}
    end
  end

  def handle_call({:subscribe, stream_id, subscriber, options}, _from, state) do
    ref = make_ref()
    subscriptions = Map.put(state.subscriptions, {stream_id, subscriber}, ref)
    subscription_options = Map.put(state.subscription_options, ref, options)
    {:reply, {:ok, ref}, %{state | subscriptions: subscriptions, subscription_options: subscription_options}}
  end

  def handle_call({:unsubscribe, stream_id, subscription}, _from, state) do
    subscriptions = Map.delete(state.subscriptions, {stream_id, subscription})
    subscription_options = Map.delete(state.subscription_options, subscription)
    {:reply, :ok, %{state | subscriptions: subscriptions, subscription_options: subscription_options}}
  end

  def handle_call({:delete_stream, stream_id}, _from, state) do
    {:reply, :ok, %{state | streams: Map.delete(state.streams, stream_id)}}
  end

  def handle_call({:read_snapshot, source_uuid}, _from, state) do
    case Map.get(state.snapshots, source_uuid) do
      nil -> {:reply, {:error, :snapshot_not_found}, state}
      snapshot -> {:reply, {:ok, snapshot}, state}
    end
  end

  def handle_call({:record_snapshot, snapshot}, _from, state) do
    {:reply, :ok, %{state | snapshots: Map.put(state.snapshots, snapshot.source_uuid, snapshot)}}
  end

  def handle_call({:delete_snapshot, source_uuid}, _from, state) do
    {:reply, :ok, %{state | snapshots: Map.delete(state.snapshots, source_uuid)}}
  end

  def handle_call({:stream_info, stream_id}, _from, state) do
    case Map.get(state.streams, stream_id) do
      nil -> {:reply, {:error, :stream_not_found}, state}
      events -> {:reply, {:ok, %{stream_id: stream_id, stream_version: length(events)}}, state}
    end
  end

  def handle_call(:paginate_streams, _from, state) do
    streams = Map.keys(state.streams)
    |> Enum.map(fn stream_id ->
      events = Map.get(state.streams, stream_id)
      %{stream_id: stream_id, stream_version: length(events)}
    end)
    {:reply, {:ok, streams, %{has_more?: false}}, state}
  end

  def handle_cast({:ack, _subscription, _events}, state) do
    # In the test store, we don't need to track acknowledgments
    {:noreply, state}
  end

  # Private Functions

  defp notify_subscribers(stream_id, events, subscriptions) do
    for {{sid, subscriber}, ref} <- subscriptions, sid == stream_id do
      send(subscriber, {:events, ref, events})
    end
  end
end
