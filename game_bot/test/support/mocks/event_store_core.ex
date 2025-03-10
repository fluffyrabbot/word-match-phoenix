defmodule GameBot.Test.Mocks.EventStoreCore do
  @moduledoc """
  Core GenServer implementation for the mock event store.

  This module handles the state management and provides the core functionality
  for the mock EventStore implementation. It is separate from the behavior
  implementation to avoid conflicts between GenServer and EventStore behaviors.
  """
  use GenServer
  require Logger

  # Define our State struct for consistency
  defmodule State do
    @moduledoc false
    defstruct streams: %{},
              errors: %{},
              subscriptions: %{}
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
  def reset_state(server \\ __MODULE__) do
    GenServer.call(server, :reset_state)
  end

  @doc """
  Setup fake events for a stream.
  """
  def setup_events(server \\ __MODULE__, stream_id, events, version \\ 0) do
    GenServer.call(server, {:setup_events, stream_id, events, version})
  end

  @doc """
  Configure the mock to return an error for certain operations.
  """
  def setup_error(server \\ __MODULE__, operation, error) do
    GenServer.call(server, {:setup_error, operation, error})
  end

  # Core operations that implement EventStore functionality

  @doc """
  Appends events to a stream.
  """
  def append_events(server \\ __MODULE__, stream_id, expected_version, events, opts \\ []) do
    GenServer.call(server, {:append_to_stream, stream_id, expected_version, events, opts})
  end

  @doc """
  Reads events from a stream in forward order.
  """
  def read_events_forward(server \\ __MODULE__, stream_id, start_version, count, opts \\ []) do
    GenServer.call(server, {:read_stream_forward, stream_id, start_version, count, opts})
  end

  @doc """
  Reads events from a stream in backward order.
  """
  def read_events_backward(server \\ __MODULE__, stream_id, start_version, count) do
    GenServer.call(server, {:read_stream_backward, stream_id, start_version, count})
  end

  @doc """
  Gets the current version of a stream.
  """
  def get_stream_version(server \\ __MODULE__, stream_id, opts \\ []) do
    GenServer.call(server, {:stream_version, stream_id, opts})
  end

  @doc """
  Subscribes to a stream.
  """
  def subscribe_to_stream(server \\ __MODULE__, stream_id, subscription_name, subscriber, opts \\ []) do
    GenServer.call(server, {:subscribe_to_stream, stream_id, subscription_name, subscriber, opts})
  end

  @doc """
  Acknowledges an event.
  """
  def ack(server \\ __MODULE__, subscription, event_number) do
    GenServer.call(server, {:ack, subscription, event_number})
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

  @doc """
  Subscribes to all streams.
  """
  def subscribe_to_all_streams(server \\ __MODULE__, subscription_name, subscriber, opts \\ []) do
    GenServer.call(server, {:subscribe_to_all_streams, subscription_name, subscriber, opts})
  end

  @doc """
  Unsubscribes from all streams.
  """
  def unsubscribe_from_all_streams(server \\ __MODULE__, subscription) do
    GenServer.call(server, {:unsubscribe_from_all_streams, subscription})
  end

  @doc """
  Unsubscribes from a stream.
  """
  def unsubscribe_from_stream(server \\ __MODULE__, subscription) do
    GenServer.call(server, {:unsubscribe_from_stream, subscription})
  end

  @doc """
  Deletes a subscription.
  """
  def delete_subscription(server \\ __MODULE__, subscription_name, stream_uuid) do
    GenServer.call(server, {:delete_subscription, subscription_name, stream_uuid})
  end

  @doc """
  Deletes an all-streams subscription.
  """
  def delete_all_streams_subscription(server \\ __MODULE__, subscription_name) do
    GenServer.call(server, {:delete_all_streams_subscription, subscription_name})
  end

  @doc """
  Reads a snapshot.
  """
  def read_snapshot(server \\ __MODULE__, source_uuid) do
    GenServer.call(server, {:read_snapshot, source_uuid})
  end

  @doc """
  Records a snapshot.
  """
  def record_snapshot(server \\ __MODULE__, snapshot) do
    GenServer.call(server, {:record_snapshot, snapshot})
  end

  @doc """
  Deletes a snapshot.
  """
  def delete_snapshot(server \\ __MODULE__, source_uuid) do
    GenServer.call(server, {:delete_snapshot, source_uuid})
  end

  # GenServer Callbacks

  @impl GenServer
  def init(_) do
    {:ok, %State{}}
  end

  @impl GenServer
  def handle_call(:reset_state, _from, _state) do
    new_state = %State{
      streams: %{},
      errors: %{},
      subscriptions: %{}
    }
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:setup_events, stream_id, events, version}, _from, state) do
    streams = Map.put(state.streams, stream_id, %{events: events, version: version})
    {:reply, :ok, %{state | streams: streams}}
  end

  @impl GenServer
  def handle_call({:setup_error, operation, error}, _from, state) do
    errors = Map.put(state.errors, operation, error)
    {:reply, :ok, %{state | errors: errors}}
  end

  @impl GenServer
  def handle_call({:append_to_stream, stream_id, expected_version, events, _opts}, _from, state) do
    case Map.get(state.errors, :append_to_stream) do
      nil ->
        # Get existing stream or create a new one
        stream = Map.get(state.streams, stream_id, %{events: [], version: 0})

        # Append events and update version
        updated_stream = %{
          events: stream.events ++ events,
          version: stream.version + length(events)
        }

        # Update state
        streams = Map.put(state.streams, stream_id, updated_stream)
        {:reply, {:ok, updated_stream.version}, %{state | streams: streams}}

      error ->
        {:reply, {:error, error}, state}
    end
  end

  @impl GenServer
  def handle_call({:read_stream_forward, stream_id, start_version, count, _opts}, _from, state) do
    case Map.get(state.errors, :read) do
      nil ->
        case Map.get(state.streams, stream_id) do
          nil ->
            # Stream doesn't exist
            {:reply, {:ok, []}, state}

          stream ->
            # Filter events from the stream
            events = stream.events
                    |> Enum.with_index(0)  # Start indexing from 0
                    |> Enum.filter(fn {_, index} ->
                      # Make sure we're comparing correctly for version numbers
                      index >= start_version && index < start_version + count
                    end)
                    |> Enum.map(fn {event, _} -> event end)

            Logger.debug("Read #{length(events)} events from stream #{stream_id} starting at #{start_version}, requested #{count}")

            {:reply, {:ok, events}, state}
        end

      error ->
        {:reply, {:error, error}, state}
    end
  end

  @impl GenServer
  def handle_call({:stream_version, stream_id, _opts}, _from, state) do
    case Map.get(state.errors, :version) do
      nil ->
        case Map.get(state.streams, stream_id) do
          nil -> {:reply, {:ok, 0}, state}
          stream -> {:reply, {:ok, stream.version}, state}
        end

      error ->
        {:reply, {:error, error}, state}
    end
  end

  @impl GenServer
  def handle_call({:subscribe_to_stream, stream_id, subscription_name, subscriber, _opts}, _from, state) do
    case Map.get(state.errors, :subscribe_to_stream) do
      nil ->
        # Add subscription
        {:reply, {:ok, make_ref()}, state}

      error ->
        {:reply, {:error, error}, state}
    end
  end

  @impl GenServer
  def handle_call(request, _from, state) do
    # Check if we have an error configured for this operation
    operation = elem(request, 0)
    case Map.get(state.errors, operation) do
      nil ->
        # Return a default successful response based on the operation
        {:reply, get_default_response(operation), state}

      error ->
        # Return the configured error
        {:reply, {:error, error}, state}
    end
  end

  # Helper functions

  defp get_default_response(:read_stream_backward), do: {:ok, [], 0, 0}
  defp get_default_response(:delete_stream), do: :ok
  defp get_default_response(:link_to_stream), do: :ok
  defp get_default_response(:read_all_streams_forward), do: {:ok, [], 0, 0}
  defp get_default_response(:read_all_streams_backward), do: {:ok, [], 0, 0}
  defp get_default_response(:subscribe_to_all_streams), do: {:ok, make_ref()}
  defp get_default_response(:unsubscribe_from_all_streams), do: :ok
  defp get_default_response(:unsubscribe_from_stream), do: :ok
  defp get_default_response(:delete_subscription), do: :ok
  defp get_default_response(:delete_all_streams_subscription), do: :ok
  defp get_default_response(:read_snapshot), do: {:error, :snapshot_not_found}
  defp get_default_response(:record_snapshot), do: :ok
  defp get_default_response(:delete_snapshot), do: :ok
  defp get_default_response(:ack), do: :ok
  defp get_default_response(_), do: {:error, :not_implemented}
end
