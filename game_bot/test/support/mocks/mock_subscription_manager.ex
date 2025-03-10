defmodule GameBot.Test.Mocks.MockSubscriptionManager do
  @moduledoc """
  Mock implementation of the subscription manager for testing.

  This module simulates the behavior of a subscription manager without
  requiring actual event store connections. It allows tests to control
  the subscription behavior and verify the expected calls.
  """

  use GenServer
  require Logger

  # Define our State struct for consistency
  defmodule State do
    @moduledoc false
    defstruct subscriptions: %{},    # Map of subscription_id to subscription details
              handlers: %{},         # Map of subscription_id to handler function
              errors: %{},           # Map of function name to error
              call_history: []       # List of function calls for verification
  end

  # Client API

  @doc """
  Starts the mock subscription manager.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)

    # Check if process is already running
    case Process.whereis(name) do
      nil ->
        GenServer.start_link(__MODULE__, %State{}, name: name)
      pid ->
        if Process.alive?(pid) do
          {:ok, pid}
        else
          # Process is dead but still registered
          Process.unregister(name)
          GenServer.start_link(__MODULE__, %State{}, name: name)
        end
    end
  end

  @doc """
  Resets the mock state.
  """
  def reset_state(server \\ __MODULE__) do
    GenServer.call(server, :reset_state)
  end

  @doc """
  Sets up a subscription for testing.
  """
  def setup_subscription(server \\ __MODULE__, subscription_id, details) do
    GenServer.call(server, {:setup_subscription, subscription_id, details})
  end

  @doc """
  Sets up a handler for a subscription.
  """
  def setup_handler(server \\ __MODULE__, subscription_id, handler_fn) do
    GenServer.call(server, {:setup_handler, subscription_id, handler_fn})
  end

  @doc """
  Configures an error for a specific function.
  """
  def setup_error(server \\ __MODULE__, function, error) do
    GenServer.call(server, {:setup_error, function, error})
  end

  @doc """
  Gets the call history for verification.
  """
  def get_call_history(server \\ __MODULE__) do
    GenServer.call(server, :get_call_history)
  end

  @doc """
  Simulates an event occurring for a subscription.
  """
  def simulate_event(server \\ __MODULE__, subscription_id, event) do
    GenServer.cast(server, {:simulate_event, subscription_id, event})
  end

  # Mock API functions (customize these to match the actual API you're mocking)

  @doc """
  Subscribes to a stream.
  """
  def subscribe_to_stream(stream_id, handler_module, opts \\ []) do
    GenServer.call(__MODULE__, {:subscribe_to_stream, stream_id, handler_module, opts})
  end

  @doc """
  Unsubscribes from a stream.
  """
  def unsubscribe(subscription_id) do
    GenServer.call(__MODULE__, {:unsubscribe, subscription_id})
  end

  @doc """
  Gets the current subscriptions.
  """
  def get_subscriptions do
    GenServer.call(__MODULE__, :get_subscriptions)
  end

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
      errors: %{},
      call_history: []
    }
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:setup_subscription, subscription_id, details}, _from, state) do
    subscriptions = Map.put(state.subscriptions, subscription_id, details)
    new_state = %{state | subscriptions: subscriptions}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:setup_handler, subscription_id, handler_fn}, _from, state) do
    handlers = Map.put(state.handlers, subscription_id, handler_fn)
    new_state = %{state | handlers: handlers}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:setup_error, function, error}, _from, state) do
    errors = Map.put(state.errors, function, error)
    new_state = %{state | errors: errors}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_call_history, _from, state) do
    {:reply, state.call_history, state}
  end

  @impl GenServer
  def handle_call({:subscribe_to_stream, stream_id, handler_module, opts}, _from, state) do
    # Record the call
    call_history = [{:subscribe_to_stream, stream_id, handler_module, opts} | state.call_history]
    new_state = %{state | call_history: call_history}

    # Check if we should return an error
    case Map.get(state.errors, :subscribe_to_stream) do
      nil ->
        # Generate a new subscription ID
        subscription_id = "subscription-#{:erlang.unique_integer([:positive])}"

        # Create subscription details
        subscription = %{
          id: subscription_id,
          stream_id: stream_id,
          handler: handler_module,
          opts: opts
        }

        # Add to subscriptions
        subscriptions = Map.put(new_state.subscriptions, subscription_id, subscription)
        final_state = %{new_state | subscriptions: subscriptions}

        {:reply, {:ok, subscription_id}, final_state}
      error ->
        {:reply, {:error, error}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:unsubscribe, subscription_id}, _from, state) do
    # Record the call
    call_history = [{:unsubscribe, subscription_id} | state.call_history]
    new_state = %{state | call_history: call_history}

    # Check if we should return an error
    case Map.get(state.errors, :unsubscribe) do
      nil ->
        # Remove from subscriptions and handlers
        subscriptions = Map.delete(new_state.subscriptions, subscription_id)
        handlers = Map.delete(new_state.handlers, subscription_id)
        final_state = %{new_state | subscriptions: subscriptions, handlers: handlers}

        {:reply, :ok, final_state}
      error ->
        {:reply, {:error, error}, new_state}
    end
  end

  @impl GenServer
  def handle_call(:get_subscriptions, _from, state) do
    # Record the call
    call_history = [:get_subscriptions | state.call_history]
    new_state = %{state | call_history: call_history}

    # Check if we should return an error
    case Map.get(state.errors, :get_subscriptions) do
      nil ->
        # Return all subscriptions
        {:reply, {:ok, Map.values(state.subscriptions)}, new_state}
      error ->
        {:reply, {:error, error}, new_state}
    end
  end

  @impl GenServer
  def handle_cast({:simulate_event, subscription_id, event}, state) do
    # Look up the handler for this subscription
    case Map.get(state.handlers, subscription_id) do
      nil ->
        Logger.warning("No handler found for subscription #{subscription_id}")
        {:noreply, state}
      handler_fn when is_function(handler_fn) ->
        # Call the handler function
        try do
          handler_fn.(event)
        rescue
          e -> Logger.error("Error in subscription handler: #{inspect(e)}")
        end
        {:noreply, state}
    end
  end
end
