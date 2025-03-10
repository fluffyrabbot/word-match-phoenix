defmodule GameBot.TestEventStore do
  @moduledoc """
  A simple in-memory event store implementation for testing.

  This implementation is NOT suitable for production use. It provides
  implementations of the `EventStore` behaviour callbacks to
  allow for testing of components that depend on an event store.

  This module delegates to GameBot.Test.EventStoreCore for state management,
  avoiding the conflicts between GenServer and EventStore behaviors.
  """

  require Logger
  alias GameBot.Test.EventStoreCore

  # Declare that we implement the EventStore behaviour
  @behaviour EventStore

  # Define child_spec for supervisor compatibility
  @impl EventStore
  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[]]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  # Client API

  @doc """
  Starts the TestEventStore.
  """
  @impl EventStore
  def start_link(_opts) do
    # Try to provide a more specific error message if EventStoreCore is already running
    case EventStoreCore.start_link(name: EventStoreCore) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} ->
        Logger.info("EventStoreCore is already running with PID: #{inspect(pid)}")
        {:error, {:already_started, pid}}
      other -> other
    end
  end

  @doc """
  Resets the EventStore to its initial empty state.
  This is essential for test isolation and should be called
  between tests to prevent state from leaking between tests.

  Returns `:ok` on success or `{:error, reason}` if the reset fails.
  """
  def reset! do
    try do
      case EventStoreCore.reset() do
        :ok -> :ok
        {:error, reason} ->
          Logger.error("Failed to reset TestEventStore: #{inspect(reason)}")
          {:error, reason}
      end
    catch
      kind, reason ->
        Logger.error("Exception when resetting TestEventStore: #{inspect(kind)}: #{inspect(reason)}")
        {:error, {:exception, kind, reason}}
    end
  end

  @doc """
  Sets the number of operations that will fail before succeeding.
  Useful for testing retry logic.
  """
  def set_failure_count(count) do
    EventStoreCore.set_failure_count(count)
  end

  @doc """
  Sets a delay (in milliseconds) to be applied before each operation.
  Useful for testing asynchronous behavior.
  """
  def set_delay(delay) do
    EventStoreCore.set_delay(delay)
  end

  @impl EventStore
  def stop(server, timeout) do
    GenServer.stop(server, :normal, timeout)
  end

  # EventStore Behaviour Implementations

  @impl EventStore
  def init(config) do
    {:ok, config}
  end

  @impl EventStore
  def append_to_stream(server, stream_id, expected_version, events, opts \\ []) do
    EventStoreCore.append_to_stream(server, stream_id, expected_version, events)
  end

  @impl EventStore
  def read_stream_forward(server, stream_id, start_version, count) do
    EventStoreCore.read_stream_forward(server, stream_id, start_version, count)
  end

  @impl EventStore
  def read_stream_backward(server, stream_id, from_event_number, count) do
    EventStoreCore.read_events_backward(server, stream_id, from_event_number, count)
  end

  @impl EventStore
  def subscribe(server, subscriber) do
    EventStoreCore.subscribe_to_all_streams(server, subscriber, [])
  end

  @impl EventStore
  def unsubscribe_from_stream(server, subscriber, stream) do
    EventStoreCore.unsubscribe_from_stream(server, subscriber, stream)
  end

  @impl EventStore
  def subscribe_to_all_streams(server, subscriber, opts) do
    EventStoreCore.subscribe_to_all_streams(server, subscriber, opts)
  end

  # Version without opts for compatibility
  def subscribe_to_all_streams(server, subscriber) do
    subscribe_to_all_streams(server, subscriber, [])
  end

  @impl EventStore
  def unsubscribe_from_all_streams(server, subscriber) do
    EventStoreCore.unsubscribe_from_all_streams(server, subscriber)
  end

  @impl EventStore
  def config() do
    # Return a dummy configuration. Adjust as needed for your tests.
    %{some_config_option: :some_value}
  end

  @impl EventStore
  def delete_all_streams_subscription(_server, _subscriber_uuid) do
    :ok
  end

  @impl EventStore
  def delete_snapshot(_server, _stream_uuid) do
    :ok
  end

  @impl EventStore
  def delete_stream(server, stream_uuid, expected_version, opts) do
    EventStoreCore.delete_stream(server, stream_uuid, expected_version, opts)
  end

  # Version without opts for compatibility
  def delete_stream(server, stream_uuid, expected_version) do
    delete_stream(server, stream_uuid, expected_version, [])
  end

  @impl EventStore
  def delete_subscription(_server, _subscriber_uuid, _stream_uuid) do
    :ok
  end

  @impl EventStore
  def read_all_streams_backward(_server, _from_event_number, _count) do
    {:ok, [], nil, nil} # Correct return type
  end

  @impl EventStore
  def read_all_streams_forward(_server, _from_event_number, _count) do
    {:ok, [], nil, nil}  # Correct return type
  end

  @impl EventStore
  def read_snapshot(_server, _stream_uuid) do
    {:error, :snapshot_not_found}  # Correct return type
  end

  @impl EventStore
  def stream_all_backward(_server, _from_event_number) do
    {:ok, []}
  end

  @impl EventStore
  def stream_all_forward(_server, _from_event_number) do
    {:ok, []}
  end

  @impl EventStore
  def stream_backward(_server, _stream_id, _from_event_number) do
    {:ok, []}
  end

  @impl EventStore
  def stream_forward(_server, _stream_id, _from_event_number) do
    {:ok, []}
  end

  @impl EventStore
  def stream_info(_server, _stream_id) do
    {:ok, nil} # Correct return type
  end

  @impl EventStore
  def ack(_server, _ack_data) do
    :ok
  end

  @impl EventStore
  def link_to_stream(server, source_stream_id, target_stream_id, event_ids, opts) do
    EventStoreCore.link_to_stream(server, source_stream_id, target_stream_id, event_ids, opts)
  end

  # Version without opts for compatibility
  def link_to_stream(server, source_stream_id, target_stream_id, event_ids) do
    link_to_stream(server, source_stream_id, target_stream_id, event_ids, [])
  end

  @impl EventStore
  def paginate_streams(_server) do
    {:ok, [], nil}
  end

  @impl EventStore
  def record_snapshot(_server, _snapshot) do
    :ok
  end

  @impl EventStore
  def subscribe_to_stream(server, subscriber, stream_id, opts) do
    EventStoreCore.subscribe_to_stream(server, subscriber, stream_id, opts)
  end

  # Version without opts for compatibility
  def subscribe_to_stream(server, subscriber, stream_id) do
    subscribe_to_stream(server, subscriber, stream_id, [])
  end
end
