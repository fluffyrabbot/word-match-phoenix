defmodule GameBot.Test.EventStoreCore do
  @moduledoc """
  Core GenServer implementation for the test event store.

  This module handles the state management and provides the core functionality
  for the EventStore mock implementation. It is separate from the behavior
  implementation to avoid conflicts between GenServer and EventStore behaviors.
  """
  use GenServer
  require Logger

  # Define our State struct for consistency
  defmodule State do
    @moduledoc false
    defstruct streams: %{},
              subscriptions: %{},
              failure_count: 0,
              delay: 0
  end

  # Public API for Core functionality

  @doc """
  Starts the core EventStore GenServer.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, %State{}, name: name)
  end

  @doc """
  Resets the state to initial empty state.
  """
  def reset(server \\ __MODULE__) do
    GenServer.call(server, :reset_state)
  end

  @doc """
  Sets the number of operations that will fail before succeeding.
  Useful for testing retry logic.
  """
  def set_failure_count(server \\ __MODULE__, count) do
    GenServer.call(server, {:set_failure_count, count})
  end

  @doc """
  Sets a delay (in milliseconds) to be applied before each operation.
  Useful for testing asynchronous behavior.
  """
  def set_delay(server \\ __MODULE__, delay) do
    GenServer.call(server, {:set_delay, delay})
  end

  # Handle requests from the API module

  @doc """
  Appends events to a stream with concurrency control via expected_version.
  """
  def append_to_stream(server \\ __MODULE__, stream_id, expected_version, events) do
    GenServer.call(server, {:append_to_stream, stream_id, expected_version, events, []})
  end

  @doc """
  Reads events from a stream starting from the given version,
  moving forward through the stream up to the max_count.
  """
  def read_stream_forward(server \\ __MODULE__, stream_id, start_version, count) do
    GenServer.call(server, {:read_stream_forward, stream_id, start_version, count})
  end

  @doc """
  Reads events from a stream in backward order.
  """
  def read_events_backward(server \\ __MODULE__, stream_id, from_event_number, count) do
    GenServer.call(server, {:read_stream_backward, stream_id, from_event_number, count})
  end

  @doc """
  Subscribes to a stream.
  """
  def subscribe_to_stream(server \\ __MODULE__, subscriber, stream_id, opts \\ []) do
    GenServer.call(server, {:subscribe_to_stream, subscriber, stream_id, opts})
  end

  @doc """
  Subscribes to all streams.
  """
  def subscribe_to_all_streams(server \\ __MODULE__, subscriber, opts \\ []) do
    GenServer.call(server, {:subscribe_to_all, subscriber, opts})
  end

  @doc """
  Unsubscribes from a stream.
  """
  def unsubscribe_from_stream(server \\ __MODULE__, subscriber, stream_id) do
    GenServer.call(server, {:unsubscribe, subscriber, stream_id})
  end

  @doc """
  Unsubscribes from all streams.
  """
  def unsubscribe_from_all_streams(server \\ __MODULE__, subscriber) do
    GenServer.call(server, {:unsubscribe_all, subscriber})
  end

  @doc """
  Gets the current version of a stream.
  """
  def get_stream_version(server \\ __MODULE__, stream_id, opts \\ []) do
    GenServer.call(server, {:stream_version, stream_id, opts})
  end

  @doc """
  Deletes a stream.
  """
  def delete_stream(server \\ __MODULE__, stream_id, expected_version, opts \\ []) do
    GenServer.call(server, {:delete_stream, stream_id, expected_version, opts})
  end

  @doc """
  Links events from one stream to another.
  """
  def link_to_stream(server \\ __MODULE__, source_stream_id, target_stream_id, event_ids, opts \\ []) do
    GenServer.call(server, {:link_to_stream, source_stream_id, target_stream_id, event_ids, opts})
  end

  # GenServer Callbacks

  @impl GenServer
  def init(_) do
    # Initialize with an empty State struct
    {:ok, %State{}}
  end

  @impl GenServer
  def handle_call(:reset_state, _from, _state) do
    # Create a fresh state to ensure complete reset
    new_state = %State{
      streams: %{},
      subscriptions: %{},
      failure_count: 0,
      delay: 0
    }
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:set_failure_count, count}, _from, state) when is_integer(count) and count >= 0 do
    {:reply, :ok, %{state | failure_count: count}}
  end

  @impl GenServer
  def handle_call({:set_delay, delay}, _from, state) when is_integer(delay) and delay >= 0 do
    {:reply, :ok, %{state | delay: delay}}
  end

  @impl GenServer
  def handle_call(request, from, %{failure_count: failure_count, delay: delay} = state) do
    # Apply artificial delay if configured
    if delay > 0 do
      Process.sleep(delay)
    end

    # If failure count is set, decrement and fail the operation
    if failure_count > 0 do
      new_state = %{state | failure_count: failure_count - 1}
      {:reply, {:error, :artificial_failure}, new_state}
    else
      # Otherwise, process the request normally
      process_request(request, from, state)
    end
  end

  # Process specific requests

  defp process_request({:append_to_stream, stream_id, expected_version, events, _opts}, _from, state) do
    # Get existing stream or create a new one
    stream = Map.get(state.streams, stream_id, %{events: [], version: 0})

    # Check expected version
    case check_version(stream, expected_version) do
      :ok ->
        # Append events and update version
        updated_stream = %{
          events: stream.events ++ events,
          version: stream.version + length(events)
        }

        # Update state
        streams = Map.put(state.streams, stream_id, updated_stream)
        {:reply, {:ok, updated_stream.version}, %{state | streams: streams}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp process_request({:read_stream_forward, stream_id, start_version, count}, _from, state) do
    # Get the stream if it exists
    case Map.get(state.streams, stream_id) do
      nil ->
        # Stream doesn't exist
        {:reply, {:ok, [], nil, nil}, state}

      stream ->
        # Filter events from the stream
        events = stream.events
                 |> Enum.with_index()
                 |> Enum.filter(fn {_, index} -> index >= start_version && index < start_version + count end)
                 |> Enum.map(fn {event, _} -> event end)

        # Get next version
        next_version = if length(events) < count, do: nil, else: start_version + count
        # Get current version
        current_version = if stream.events == [], do: nil, else: stream.version

        {:reply, {:ok, events, next_version, current_version}, state}
    end
  end

  defp process_request({:read_stream_backward, stream_id, start_version, count}, _from, state) do
    # Get the stream if it exists
    case Map.get(state.streams, stream_id) do
      nil ->
        # Stream doesn't exist
        {:reply, {:ok, [], nil, nil}, state}

      stream ->
        # Calculate the real start index (0-based)
        start_index = if start_version == :end, do: length(stream.events) - 1, else: start_version

        # Filter events from the stream in reverse order
        events = stream.events
                 |> Enum.with_index()
                 |> Enum.filter(fn {_, index} -> index <= start_index && index > start_index - count end)
                 |> Enum.map(fn {event, _} -> event end)
                 |> Enum.reverse()

        # Get next version
        next_version = if length(events) < count, do: nil, else: start_index - count
        # Get current version
        current_version = if stream.events == [], do: nil, else: stream.version

        {:reply, {:ok, events, next_version, current_version}, state}
    end
  end

  defp process_request({:subscribe_to_stream, subscriber, stream_id, _opts}, _from, state) do
    # Generate a unique subscription reference
    subscription_ref = make_ref()

    # Get existing subscriptions for this stream
    stream_subs = Map.get(state.subscriptions, stream_id, %{})

    # Add new subscription
    updated_stream_subs = Map.put(stream_subs, subscription_ref, subscriber)

    # Update state
    subscriptions = Map.put(state.subscriptions, stream_id, updated_stream_subs)

    {:reply, {:ok, subscription_ref}, %{state | subscriptions: subscriptions}}
  end

  defp process_request({:subscribe_to_all, subscriber, _opts}, _from, state) do
    # Generate a unique subscription reference
    subscription_ref = make_ref()

    # Get existing subscriptions for all streams
    all_subs = Map.get(state.subscriptions, :all, %{})

    # Add new subscription
    updated_all_subs = Map.put(all_subs, subscription_ref, subscriber)

    # Update state
    subscriptions = Map.put(state.subscriptions, :all, updated_all_subs)

    {:reply, {:ok, subscription_ref}, %{state | subscriptions: subscriptions}}
  end

  defp process_request({:unsubscribe, subscriber, stream_id}, _from, state) do
    # Get existing subscriptions for this stream
    stream_subs = Map.get(state.subscriptions, stream_id, %{})

    # Remove all subscriptions for this subscriber
    updated_stream_subs = Enum.filter(stream_subs, fn {_, sub} -> sub != subscriber end) |> Map.new()

    # Update state
    subscriptions = Map.put(state.subscriptions, stream_id, updated_stream_subs)

    {:reply, :ok, %{state | subscriptions: subscriptions}}
  end

  defp process_request({:unsubscribe_all, subscriber}, _from, state) do
    # Get existing subscriptions for all streams
    all_subs = Map.get(state.subscriptions, :all, %{})

    # Remove all subscriptions for this subscriber
    updated_all_subs = Enum.filter(all_subs, fn {_, sub} -> sub != subscriber end) |> Map.new()

    # Update state
    subscriptions = Map.put(state.subscriptions, :all, updated_all_subs)

    {:reply, :ok, %{state | subscriptions: subscriptions}}
  end

  defp process_request({:delete_stream, stream_id, expected_version, _opts}, _from, state) do
    # Get the stream if it exists
    case Map.get(state.streams, stream_id) do
      nil ->
        # Stream doesn't exist
        if expected_version == :any_version do
          {:reply, :ok, state}
        else
          {:reply, {:error, :stream_not_found}, state}
        end

      stream ->
        # Check expected version
        case check_version(stream, expected_version) do
          :ok ->
            # Remove stream
            streams = Map.delete(state.streams, stream_id)
            {:reply, :ok, %{state | streams: streams}}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  defp process_request({:link_to_stream, source_stream_id, target_stream_id, _event_ids, _opts}, _from, state) do
    # Get source and target streams
    source_stream = Map.get(state.streams, source_stream_id)
    _target_stream = Map.get(state.streams, target_stream_id, %{events: [], version: 0})

    cond do
      source_stream == nil ->
        {:reply, {:error, :source_stream_not_found}, state}

      # Filter events from source stream by given event IDs (mock implementation)
      # In a real implementation, this would need to match actual event IDs
      true ->
        # For simplicity, we'll just pretend we linked the events
        {:reply, :ok, state}
    end
  end

  defp process_request({:stream_version, stream_id, _opts}, _from, state) do
    # Get the stream if it exists
    case Map.get(state.streams, stream_id) do
      nil ->
        # Stream doesn't exist
        {:reply, {:error, :stream_not_found}, state}

      stream ->
        {:reply, {:ok, stream.version}, state}
    end
  end

  defp process_request(_request, _from, state) do
    # Default handler for unrecognized requests
    {:reply, {:error, :not_implemented}, state}
  end

  # Helper functions

  defp check_version(_stream, :any_version) do
    :ok
  end

  defp check_version(%{version: current}, expected) when expected == current do
    :ok
  end

  defp check_version(%{version: current}, expected) do
    {:error, {:wrong_expected_version, expected: expected, current: current}}
  end
end
