defmodule GameBot.Test.Mocks.MockEventStoreAccess do
  @moduledoc """
  Mock implementation of the EventStoreAccess module for testing.

  This module provides a mock that simulates the behavior of the
  GameBot.Replay.EventStoreAccess module without requiring actual
  event store connections. It allows tests to control the responses
  returned by the event store access functions.

  The mock maintains state to track configured responses and call history,
  making it easy to verify expected behavior in tests.
  """

  use GenServer
  require Logger

  # Define our State struct for consistency
  defmodule State do
    @moduledoc false
    defstruct events: %{},             # Map of game_id to events
              stream_versions: %{},    # Map of game_id to version
              game_exists: %{},        # Map of game_id to exists flag
              errors: %{},             # Map of function name to error
              call_history: []         # List of function calls for verification
  end

  # Client API

  @doc """
  Starts the mock EventStoreAccess server.
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
  Sets up events for a specific game.

  Args:
    - game_id: The ID of the game to set up events for
    - events: The list of events to return for this game
    - version: The stream version to return (default: length of events)
  """
  def setup_events(server \\ __MODULE__, game_id, events, version \\ nil) do
    version = version || length(events)
    GenServer.call(server, {:setup_events, game_id, events, version})
  end

  @doc """
  Configures the mock to return that a game exists.

  Args:
    - game_id: The ID of the game to set existence for
    - exists: Whether the game exists (default: true)
    - version: The stream version to return if exists (default: 1)
  """
  def setup_game_exists(server \\ __MODULE__, game_id, exists \\ true, version \\ 1) do
    GenServer.call(server, {:setup_game_exists, game_id, exists, version})
  end

  @doc """
  Configures the mock to return an error for a specific function.

  Args:
    - function: The name of the function to return an error for
    - error: The error to return
  """
  def setup_error(server \\ __MODULE__, function, error) do
    GenServer.call(server, {:setup_error, function, error})
  end

  @doc """
  Gets the call history for verification in tests.
  """
  def get_call_history(server \\ __MODULE__) do
    GenServer.call(server, :get_call_history)
  end

  # Implementation of GameBot.Replay.EventStoreAccess API

  @doc """
  Fetches events for a given game.

  This mock implementation returns events configured via setup_events/4.
  """
  def fetch_game_events(game_id, opts \\ []) do
    GenServer.call(__MODULE__, {:fetch_game_events, game_id, opts})
  end

  @doc """
  Gets the current version of a game's event stream.

  This mock implementation returns versions configured via setup_events/4.
  """
  def get_stream_version(game_id) do
    GenServer.call(__MODULE__, {:get_stream_version, game_id})
  end

  @doc """
  Checks if a game exists in the event store.

  This mock implementation returns existence configured via setup_game_exists/4.
  """
  def game_exists?(game_id) do
    GenServer.call(__MODULE__, {:game_exists?, game_id})
  end

  # GenServer Callbacks

  @impl GenServer
  def init(_) do
    {:ok, %State{}}
  end

  @impl GenServer
  def handle_call(:reset_state, _from, _state) do
    new_state = %State{
      events: %{},
      stream_versions: %{},
      game_exists: %{},
      errors: %{},
      call_history: []
    }
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:setup_events, game_id, events, version}, _from, state) do
    events = Map.put(state.events, game_id, events)
    stream_versions = Map.put(state.stream_versions, game_id, version)
    game_exists = Map.put(state.game_exists, game_id, true)

    new_state = %{state |
      events: events,
      stream_versions: stream_versions,
      game_exists: game_exists
    }

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:setup_game_exists, game_id, exists, version}, _from, state) do
    game_exists = Map.put(state.game_exists, game_id, exists)
    stream_versions = Map.put(state.stream_versions, game_id, version)

    new_state = %{state |
      game_exists: game_exists,
      stream_versions: stream_versions
    }

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
  def handle_call({:fetch_game_events, game_id, opts}, _from, state) do
    # Record the call for verification
    call_history = [{:fetch_game_events, game_id, opts} | state.call_history]
    new_state = %{state | call_history: call_history}

    # Check if we should return an error
    case Map.get(state.errors, :fetch_game_events) do
      nil ->
        # No error configured, return the events
        case Map.get(state.events, game_id) do
          nil ->
            # Game not found
            {:reply, {:error, :stream_not_found}, new_state}
          events ->
            # Apply options
            max_events = Keyword.get(opts, :max_events, 1000)
            start_version = Keyword.get(opts, :start_version, 0)

            # Filter and limit events based on options
            filtered_events = events
              |> Enum.drop(start_version)
              |> Enum.take(max_events)

            {:reply, {:ok, filtered_events}, new_state}
        end
      error ->
        # Return the configured error
        {:reply, {:error, error}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:get_stream_version, game_id}, _from, state) do
    # Record the call for verification
    call_history = [{:get_stream_version, game_id} | state.call_history]
    new_state = %{state | call_history: call_history}

    # Check if we should return an error
    case Map.get(state.errors, :get_stream_version) do
      nil ->
        # No error configured, return the version
        version = Map.get(state.stream_versions, game_id, 0)
        {:reply, {:ok, version}, new_state}
      error ->
        # Return the configured error
        {:reply, {:error, error}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:game_exists?, game_id}, _from, state) do
    # Record the call for verification
    call_history = [{:game_exists?, game_id} | state.call_history]
    new_state = %{state | call_history: call_history}

    # Check if we should return an error
    case Map.get(state.errors, :game_exists?) do
      nil ->
        # No error configured, check if the game exists
        case Map.get(state.game_exists, game_id, false) do
          true ->
            # Game exists, return the version
            version = Map.get(state.stream_versions, game_id, 1)
            {:reply, {:ok, version}, new_state}
          false ->
            # Game doesn't exist
            {:reply, {:error, :stream_not_found}, new_state}
        end
      error ->
        # Return the configured error
        {:reply, {:error, error}, new_state}
    end
  end
end
