defmodule MockSubscriptionManager do
  @moduledoc """
  Mock implementation of the subscription manager for testing.

  This module provides a simple GenServer-based mock that can be used in tests
  to simulate the behavior of event subscriptions without requiring a real event store.
  """

  use GenServer

  defmodule State do
    @moduledoc false
    defstruct subscriptions: %{},
              handlers: %{},
              call_history: []
  end

  # Client API

  @doc """
  Starts the mock subscription manager server.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, %State{}, name: name)
  end

  @doc """
  Resets the mock state to initial empty state.
  """
  def reset_state(server \\ __MODULE__) do
    GenServer.call(server, :reset_state)
  end

  @doc """
  Get the call history for verification in tests.
  """
  def get_call_history(server \\ __MODULE__) do
    GenServer.call(server, :get_call_history)
  end

  @doc """
  Subscribe to a stream with a handler function.

  Args:
    - stream_id: The ID of the stream to subscribe to
    - handler: The handler function or module to call when events occur
    - opts: Additional subscription options
  """
  def subscribe(stream_id, handler, opts \\ []) do
    GenServer.call(__MODULE__, {:subscribe, stream_id, handler, opts})
  end

  @doc """
  Unsubscribe from a stream.

  Args:
    - subscription_id: The ID of the subscription to cancel
  """
  def unsubscribe(subscription_id) do
    GenServer.call(__MODULE__, {:unsubscribe, subscription_id})
  end

  @doc """
  Manually trigger events for a stream (test helper method).

  Args:
    - stream_id: The ID of the stream to simulate events for
    - events: The list of events to simulate
  """
  def simulate_events(stream_id, events) do
    GenServer.call(__MODULE__, {:simulate_events, stream_id, events})
  end

  @doc """
  Mock implementation of subscribe_to_event_type.
  Always returns :ok for testing.
  """
  def subscribe_to_event_type(event_type) do
    # Just log the subscription for testing purposes
    IO.puts("MockSubscriptionManager: Subscribed to #{event_type}")
    :ok
  end

  @doc """
  Mock implementation of unsubscribe.
  Always returns :ok for testing.
  """
#  def unsubscribe(subscription_id) do
#    # Just log the unsubscription for testing purposes
#    IO.puts("MockSubscriptionManager: Unsubscribed from #{subscription_id}")
#    :ok
#  end

  # GenServer Callbacks

  @impl GenServer
  def init(_) do
    {:ok, %State{}}
  end

  @impl GenServer
  def handle_call(:reset_state, _from, _state) do
    new_state = %State{
      subscriptions: %{},
      handlers: %{},
      call_history: []
    }
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_call_history, _from, state) do
    {:reply, state.call_history, state}
  end

  @impl GenServer
  def handle_call({:subscribe, stream_id, handler, opts}, _from, state) do
    subscription_id = System.unique_integer([:positive]) |> to_string()

    subscriptions = Map.put(state.subscriptions, subscription_id, %{
      stream_id: stream_id,
      opts: opts
    })

    handlers = Map.put(state.handlers, subscription_id, handler)

    call_history = [{:subscribe, stream_id, handler, opts} | state.call_history]

    new_state = %{state |
      subscriptions: subscriptions,
      handlers: handlers,
      call_history: call_history
    }

    {:reply, {:ok, subscription_id}, new_state}
  end

  @impl GenServer
  def handle_call({:unsubscribe, subscription_id}, _from, state) do
    subscriptions = Map.delete(state.subscriptions, subscription_id)
    handlers = Map.delete(state.handlers, subscription_id)

    call_history = [{:unsubscribe, subscription_id} | state.call_history]

    new_state = %{state |
      subscriptions: subscriptions,
      handlers: handlers,
      call_history: call_history
    }

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:simulate_events, stream_id, events}, _from, state) do
    # Find all subscriptions for this stream
    matching_subscriptions = Enum.filter(state.subscriptions, fn {_id, sub} ->
      sub.stream_id == stream_id
    end)

    # Call each handler with the events
    Enum.each(matching_subscriptions, fn {sub_id, _sub} ->
      handler = Map.get(state.handlers, sub_id)

      cond do
        is_function(handler, 1) ->
          handler.(events)
        is_atom(handler) and function_exported?(handler, :handle_events, 1) ->
          handler.handle_events(events)
        true ->
          # No-op for unhandled cases
          :ok
      end
    end)

    call_history = [{:simulate_events, stream_id, events} | state.call_history]

    new_state = %{state | call_history: call_history}

    {:reply, :ok, new_state}
  end
end
