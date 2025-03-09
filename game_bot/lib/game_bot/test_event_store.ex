defmodule GameBot.TestEventStore do
  @moduledoc """
  In-memory implementation of EventStore for testing.

  This module implements the EventStore behaviour for test compatibility.
  """

  use GenServer

  # Mark that we're implementing EventStore behavior to avoid warnings
  @behaviour EventStore

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
  @impl EventStore
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

  @doc """
  Gets the current version of a stream with options.
  """
  def stream_version(stream_id, _opts) do
    GenServer.call(__MODULE__, {:version, stream_id})
  end

  # Implementation of EventStore and GenServer callbacks

  @impl GenServer
  def init(_config) do
    {:ok, %State{}}
  end

  @impl EventStore
  def config do
    Application.get_env(:game_bot, __MODULE__, [])
  end

  @impl EventStore
  def subscribe(_subscriber, _subscription_options) do
    {:ok, make_ref()}
  end

  @impl EventStore
  def unsubscribe_from_all_streams(_subscription, _opts \\ []) do
    :ok
  end

  @impl EventStore
  def append_to_stream(stream_id, _expected_version, events, _opts \\ []) when is_list(events) do
    GenServer.call(__MODULE__, {:append, stream_id, events})
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
  def read_all_streams_forward(_start_from, count, _opts \\ []) do
    GenServer.call(__MODULE__, {:read_all_forward, count})
  end

  @impl EventStore
  def read_all_streams_backward(_start_from, count, _opts \\ []) do
    GenServer.call(__MODULE__, {:read_all_backward, count})
  end

  @impl EventStore
  def subscribe_to_stream(_stream_id, _subscriber, _subscription_options \\ [], _opts \\ []) do
    {:ok, make_ref()}
  end

  @impl EventStore
  def subscribe_to_all_streams(_subscription_name, _subscriber, _subscription_options) do
    {:ok, make_ref()}
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
  def stream_forward(_stream_id, _start_version \\ 0, _opts \\ []) do
    {:ok, []}
  end

  @impl EventStore
  def stream_backward(_stream_id, _start_version \\ 0, _opts \\ []) do
    {:ok, []}
  end

  @impl EventStore
  def stream_all_forward(_start_from \\ 0, _opts \\ []) do
    {:ok, []}
  end

  @impl EventStore
  def stream_all_backward(_start_from \\ 0, _opts \\ []) do
    {:ok, []}
  end

  @impl EventStore
  def delete_stream(stream_id, _expected_version \\ 0, _hard_delete \\ false, _opts \\ []) do
    GenServer.call(__MODULE__, {:delete_stream, stream_id})
  end

  @impl EventStore
  def link_to_stream(_stream_id, _expected_version, _event_numbers, _opts \\ []) do
    :ok
  end

  @impl EventStore
  def stream_info(_stream_id, _opts \\ []) do
    {:ok, %{stream_version: 0, stream_id: "", created_at: DateTime.utc_now()}}
  end

  @impl EventStore
  def paginate_streams(_opts \\ []) do
    {:ok, []}
  end

  @impl EventStore
  def read_snapshot(_source_uuid, _opts \\ []) do
    {:error, :snapshot_not_found}
  end

  @impl EventStore
  def record_snapshot(_snapshot, _opts \\ []) do
    :ok
  end

  @impl EventStore
  def delete_snapshot(_source_uuid, _opts \\ []) do
    :ok
  end

  # GenServer callback implementations

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
    {:reply, :ok, %{state | track_retries: enable, retry_delays: []}}
  end

  @impl GenServer
  def handle_call(:get_retry_delays, _from, state) do
    {:reply, state.retry_delays, state}
  end

  @impl GenServer
  def handle_call({:version, stream_id}, _from, state) do
    events = Map.get(state.streams, stream_id, [])
    version = length(events)
    {:reply, {:ok, version}, state}
  end

  @impl GenServer
  def handle_call({:delete_stream, stream_id}, _from, state) do
    # Remove the stream
    streams = Map.delete(state.streams, stream_id)
    {:reply, :ok, %{state | streams: streams}}
  end

  @impl GenServer
  def handle_call({:append, stream_id, events}, _from, state) do
    # Check for failure simulation
    if state.failure_count > 0 do
      # Simulate a failure for testing retry mechanisms
      new_state = %{state | failure_count: state.failure_count - 1}

      # Track retry attempt time if enabled
      new_state = if state.track_retries do
        now = :os.system_time(:millisecond)

        delay = case state.last_attempt_time do
          nil -> 0
          time -> now - time
        end

        retry_delays = [delay | state.retry_delays]
        %{new_state | retry_delays: retry_delays, last_attempt_time: now}
      else
        new_state
      end

      {:reply, {:error, :temporary_failure}, new_state}
    else
      # Get current events for this stream
      current_events = Map.get(state.streams, stream_id, [])

      # Ensure all events have stream_id set
      prepared_events = Enum.map(events, fn event ->
        case event do
          %{stream_id: _} -> event
          _ when is_map(event) -> Map.put(event, :stream_id, stream_id)
          _ -> event
        end
      end)

      # Append the new events
      updated_events = current_events ++ prepared_events

      # Update the streams map
      streams = Map.put(state.streams, stream_id, updated_events)

      # Return the new version number (number of events)
      {:reply, {:ok, length(updated_events)}, %{state | streams: streams}}
    end
  end

  @impl GenServer
  def handle_call({:read_forward, stream_id, start_version, count}, _from, state) do
    events = Map.get(state.streams, stream_id, [])

    # Filter events by version and take the requested count
    result =
      events
      |> Enum.drop(start_version)
      |> Enum.take(count)

    {:reply, {:ok, result}, state}
  end

  @impl GenServer
  def handle_call({:read_backward, stream_id, start_version, count}, _from, state) do
    events = Map.get(state.streams, stream_id, [])
    total = length(events)

    # Convert the start_version to a position from the end if it's :end
    start_pos = if start_version == :end, do: total - 1, else: start_version

    # Calculate the range of events to return
    end_pos = max(0, start_pos - count + 1)

    # Get the events
    result =
      events
      |> Enum.slice(end_pos..start_pos)
      |> Enum.reverse()

    {:reply, {:ok, result}, state}
  end

  @impl GenServer
  def handle_call({:read_all_forward, count}, _from, state) do
    # Flatten all events from all streams and sort by some criteria
    events =
      state.streams
      |> Map.values()
      |> List.flatten()
      |> Enum.sort_by(fn event ->
        # Sort by created_at or some other field
        Map.get(event, :created_at, 0)
      end)
      |> Enum.take(count)

    {:reply, {:ok, events}, state}
  end

  @impl GenServer
  def handle_call({:read_all_backward, count}, _from, state) do
    # Flatten all events from all streams and sort by some criteria
    events =
      state.streams
      |> Map.values()
      |> List.flatten()
      |> Enum.sort_by(fn event ->
        # Sort by created_at or some other field
        Map.get(event, :created_at, 0)
      end, :desc)
      |> Enum.take(count)

    {:reply, {:ok, events}, state}
  end

  @impl GenServer
  def handle_cast({:ack, _subscription, _events}, state) do
    {:noreply, state}
  end
end
