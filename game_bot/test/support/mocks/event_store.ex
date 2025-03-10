defmodule GameBot.Test.Mocks.EventStore do
  @moduledoc """
  Mock implementation of EventStore for testing.

  This module provides a mock that simulates an event store
  without requiring a database connection. It's used for unit tests
  that need to verify event store interactions.

  This module delegates to GameBot.Test.Mocks.EventStoreCore for state management,
  avoiding conflicts between GenServer and EventStore behaviors.
  """

  @behaviour GameBot.Infrastructure.Persistence.EventStore.Adapter.Behaviour
  @behaviour EventStore

  require Logger
  alias GameBot.Test.Mocks.EventStoreCore

  # Client API

  @doc """
  Starts the mock event store server.
  """
  @impl EventStore
  def start_link(opts) do
    # We'll delegate to the Core implementation
    case EventStoreCore.start_link(opts) do
      {:ok, pid} ->
        # Register with the module name for backward compatibility
        if not Process.whereis(__MODULE__) do
          Process.register(pid, __MODULE__)
        end
        {:ok, pid}
      other -> other
    end
  end

  @doc """
  Reset the state of the mock event store.
  """
  def reset_state do
    EventStoreCore.reset_state()
  end

  @doc """
  Setup fake events for a stream.
  """
  def setup_events(stream_id, events, version \\ 0) do
    EventStoreCore.setup_events(stream_id, events, version)
  end

  @doc """
  Configure the mock to return an error for certain operations.
  """
  def setup_error(operation, error) do
    EventStoreCore.setup_error(operation, error)
  end

  # EventStore.Adapter.Behaviour callbacks

  @impl GameBot.Infrastructure.Persistence.EventStore.Adapter.Behaviour
  def append_to_stream(stream_id, expected_version, events, opts) do
    EventStoreCore.append_events(stream_id, expected_version, events, opts)
  end

  # Version without opts - delegates to the main implementation
  def append_to_stream(stream_id, expected_version, events) do
    append_to_stream(stream_id, expected_version, events, [])
  end

  @impl GameBot.Infrastructure.Persistence.EventStore.Adapter.Behaviour
  def read_stream_forward(stream_id, start_version, count, opts) do
    EventStoreCore.read_events_forward(stream_id, start_version, count, opts)
  end

  # Version without opts - delegates to the main implementation
  def read_stream_forward(stream_id, start_version, count) do
    read_stream_forward(stream_id, start_version, count, [])
  end

  @impl GameBot.Infrastructure.Persistence.EventStore.Adapter.Behaviour
  def stream_version(stream_id, opts) do
    EventStoreCore.get_stream_version(stream_id, opts)
  end

  # Version without opts - delegates to the main implementation
  def stream_version(stream_id) do
    stream_version(stream_id, [])
  end

  @impl GameBot.Infrastructure.Persistence.EventStore.Adapter.Behaviour
  def subscribe_to_stream(stream_id, subscription_name, subscriber, opts) do
    EventStoreCore.subscribe_to_stream(stream_id, subscription_name, subscriber, opts)
  end

  # Version without opts - delegates to the main implementation
  def subscribe_to_stream(stream_id, subscription_name, subscriber) do
    subscribe_to_stream(stream_id, subscription_name, subscriber, [])
  end

  # EventStore callbacks

  @impl EventStore
  def ack(subscription, event_number) do
    EventStoreCore.ack(subscription, event_number)
  end

  @impl EventStore
  def config do
    %{adapter: __MODULE__}
  end

  # Additional required EventStore callbacks with proper @impl

  @impl EventStore
  def delete_stream(stream_id, expected_version, opts) do
    EventStoreCore.delete_stream(stream_id, expected_version, opts)
  end

  # Version without opts - delegates to the main implementation
  def delete_stream(stream_id, expected_version) do
    delete_stream(stream_id, expected_version, [])
  end

  @impl EventStore
  def link_to_stream(source_stream_id, target_stream_id, event_ids, opts) do
    EventStoreCore.link_to_stream(source_stream_id, target_stream_id, event_ids, opts)
  end

  # Version without opts - delegates to the main implementation
  def link_to_stream(source_stream_id, target_stream_id, event_ids) do
    link_to_stream(source_stream_id, target_stream_id, event_ids, [])
  end

  @impl EventStore
  def read_all_streams_forward(start_event_number, count) do
    {:ok, [], nil, nil}
  end

  @impl EventStore
  def read_all_streams_backward(start_event_number, count) do
    {:ok, [], nil, nil}
  end

  @impl EventStore
  def read_stream_backward(stream_id, start_event_number, count) do
    EventStoreCore.read_events_backward(stream_id, start_event_number, count)
  end

  @impl EventStore
  def subscribe_to_all_streams(subscription_name, subscriber, opts) do
    EventStoreCore.subscribe_to_all_streams(subscription_name, subscriber, opts)
  end

  # Version without opts - delegates to the main implementation
  def subscribe_to_all_streams(subscription_name, subscriber) do
    subscribe_to_all_streams(subscription_name, subscriber, [])
  end

  @impl EventStore
  def unsubscribe_from_all_streams(subscription) do
    EventStoreCore.unsubscribe_from_all_streams(subscription)
  end

  @impl EventStore
  def unsubscribe_from_stream(subscription) do
    EventStoreCore.unsubscribe_from_stream(subscription)
  end

  @impl EventStore
  def delete_subscription(subscription_name, stream_uuid) do
    EventStoreCore.delete_subscription(subscription_name, stream_uuid)
  end

  @impl EventStore
  def delete_all_streams_subscription(subscription_name) do
    EventStoreCore.delete_all_streams_subscription(subscription_name)
  end

  @impl EventStore
  def read_snapshot(source_uuid) do
    EventStoreCore.read_snapshot(source_uuid)
  end

  @impl EventStore
  def record_snapshot(snapshot) do
    EventStoreCore.record_snapshot(snapshot)
  end

  @impl EventStore
  def delete_snapshot(source_uuid) do
    EventStoreCore.delete_snapshot(source_uuid)
  end

  # Additional EventStore Callbacks (Not fully implemented)

  @impl EventStore
  def stream_all_forward(_from_event_number) do
    {:ok, []}
  end

  @impl EventStore
  def stream_all_backward(_from_event_number) do
    {:ok, []}
  end

  @impl EventStore
  def stream_forward(_stream_id, _from_event_number) do
    {:ok, []}
  end

  @impl EventStore
  def stream_backward(_stream_id, _from_event_number) do
    {:ok, []}
  end

  @impl EventStore
  def subscribe(_subscriber) do
    {:ok, make_ref()}
  end

  @impl EventStore
  def stop(server, timeout) do
    GenServer.stop(server, :normal, timeout)
  end

  @impl EventStore
  def stream_info(_stream_id) do
    {:ok, nil}
  end

  @impl EventStore
  def paginate_streams() do
    {:ok, [], nil}
  end
end
