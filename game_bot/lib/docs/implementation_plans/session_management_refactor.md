# Session Management Refactor Plan

## Overview

This document outlines the plan for refactoring the session management system to provide better resource management, fault tolerance, and monitoring capabilities. The new system will use a proper supervision tree and handle session lifecycle events properly.

## Phase 1: Core Session Infrastructure

### 1.1 Session Registry
- [ ] Create `GameBot.GameSessions.Registry` module
  ```elixir
  defmodule GameBot.GameSessions.Registry do
    @moduledoc """
    Registry for tracking active game sessions.
    """

    def child_spec(_) do
      Registry.child_spec(
        keys: :unique,
        name: __MODULE__,
        partitions: System.schedulers_online()
      )
    end

    def via_tuple(game_id), do: {:via, Registry, {__MODULE__, game_id}}

    def whereis(game_id) do
      case Registry.lookup(__MODULE__, game_id) do
        [{pid, _}] -> {:ok, pid}
        [] -> {:error, :not_found}
      end
    end

    def get_sessions do
      Registry.select(__MODULE__, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}])
    end
  end
  ```

### 1.2 Session Supervisor
- [ ] Create `GameBot.GameSessions.Supervisor` module
  ```elixir
  defmodule GameBot.GameSessions.Supervisor do
    use DynamicSupervisor

    def start_link(init_arg) do
      DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
    end

    def init(_init_arg) do
      DynamicSupervisor.init(
        strategy: :one_for_one,
        max_restarts: 3,
        max_seconds: 5
      )
    end

    def start_session(game_id, opts \\ []) do
      child_spec = %{
        id: GameBot.GameSessions.Session,
        start: {GameBot.GameSessions.Session, :start_link, [game_id, opts]},
        restart: :transient
      }

      DynamicSupervisor.start_child(__MODULE__, child_spec)
    end

    def terminate_session(game_id) do
      case GameBot.GameSessions.Registry.whereis(game_id) do
        {:ok, pid} -> DynamicSupervisor.terminate_child(__MODULE__, pid)
        error -> error
      end
    end

    def active_sessions do
      DynamicSupervisor.which_children(__MODULE__)
      |> Enum.count()
    end
  end
  ```

### 1.3 Session State Machine
- [ ] Create `GameBot.GameSessions.Session` module
  ```elixir
  defmodule GameBot.GameSessions.Session do
    use GenStateMachine, callback_mode: :state_functions

    alias GameBot.GameSessions.Registry
    alias GameBot.Domain.Events

    # Session states
    @states [:initializing, :active, :paused, :cleanup, :terminated]

    def start_link(game_id, opts \\ []) do
      GenStateMachine.start_link(__MODULE__, {game_id, opts}, name: Registry.via_tuple(game_id))
    end

    def init({game_id, opts}) do
      Process.flag(:trap_exit, true)

      {:ok, :initializing, %{
        game_id: game_id,
        guild_id: Keyword.fetch!(opts, :guild_id),
        mode: Keyword.fetch!(opts, :mode),
        state: :initializing,
        start_time: DateTime.utc_now(),
        last_activity: DateTime.utc_now(),
        cleanup_timer: nil
      }}
    end

    # State: Initializing
    def initializing(:cast, {:initialize, config}, data) do
      with {:ok, game_state} <- initialize_game_state(config),
           :ok <- broadcast_initialized(data.game_id, game_state) do
        {:next_state, :active, %{data | state: game_state}}
      else
        error ->
          {:stop, error, data}
      end
    end

    # State: Active
    def active(:cast, {:process_command, command}, data) do
      with {:ok, new_state, events} <- apply_command(data.state, command),
           :ok <- broadcast_events(data.game_id, events) do
        {:keep_state, %{data | state: new_state, last_activity: DateTime.utc_now()}}
      else
        error ->
          {:keep_state_and_data, error}
      end
    end

    def active(:cast, :pause, data) do
      {:next_state, :paused, data}
    end

    # State: Paused
    def paused(:cast, :resume, data) do
      {:next_state, :active, data}
    end

    # State: Cleanup
    def cleanup(:cast, :finish_cleanup, data) do
      {:stop, :normal, data}
    end

    def cleanup(:cast, _, data) do
      {:keep_state_and_data, {:error, :cleaning_up}}
    end

    # Lifecycle Events
    def terminate(reason, state, data) do
      cleanup_session(data)
      broadcast_terminated(data.game_id, reason)
      :ok
    end

    # Private Functions

    defp initialize_game_state(config) do
      # Initialize game state based on mode and config
      {:ok, %{}}
    end

    defp apply_command(state, command) do
      # Apply command and generate events
      {:ok, state, []}
    end

    defp broadcast_events(game_id, events) do
      Enum.each(events, &broadcast_event(game_id, &1))
      :ok
    end

    defp broadcast_event(game_id, event) do
      Phoenix.PubSub.broadcast(
        GameBot.PubSub,
        "game:#{game_id}",
        {:game_event, event}
      )
    end

    defp cleanup_session(data) do
      # Cleanup resources
      :ok
    end

    defp broadcast_initialized(game_id, state) do
      broadcast_event(game_id, %Events.GameInitialized{
        game_id: game_id,
        state: state,
        timestamp: DateTime.utc_now()
      })
    end

    defp broadcast_terminated(game_id, reason) do
      broadcast_event(game_id, %Events.GameTerminated{
        game_id: game_id,
        reason: reason,
        timestamp: DateTime.utc_now()
      })
    end
  end
  ```

## Phase 2: Session Management

### 2.1 Session Manager
- [ ] Create `GameBot.GameSessions.Manager` module
  ```elixir
  defmodule GameBot.GameSessions.Manager do
    use GenServer

    alias GameBot.GameSessions.{Supervisor, Registry}

    @cleanup_interval :timer.minutes(5)
    @session_timeout :timer.minutes(30)

    def start_link(_) do
      GenServer.start_link(__MODULE__, [], name: __MODULE__)
    end

    def init(_) do
      schedule_cleanup()
      {:ok, %{}}
    end

    def handle_info(:cleanup, state) do
      cleanup_inactive_sessions()
      schedule_cleanup()
      {:noreply, state}
    end

    defp cleanup_inactive_sessions do
      Registry.get_sessions()
      |> Enum.each(fn {game_id, pid, _} ->
        if session_inactive?(pid) do
          Supervisor.terminate_session(game_id)
        end
      end)
    end

    defp session_inactive?(pid) do
      case :sys.get_state(pid) do
        %{last_activity: last_activity} ->
          DateTime.diff(DateTime.utc_now(), last_activity, :second) > @session_timeout
        _ -> false
      end
    end

    defp schedule_cleanup do
      Process.send_after(self(), :cleanup, @cleanup_interval)
    end
  end
  ```

### 2.2 Session Monitoring
- [ ] Create `GameBot.GameSessions.Monitor` module
  ```elixir
  defmodule GameBot.GameSessions.Monitor do
    use GenServer

    require Logger

    def start_link(_) do
      GenServer.start_link(__MODULE__, [], name: __MODULE__)
    end

    def init(_) do
      :telemetry.attach_many(
        "game-sessions-monitor",
        [
          [:game_bot, :sessions, :started],
          [:game_bot, :sessions, :terminated],
          [:game_bot, :sessions, :command_processed],
          [:game_bot, :sessions, :error]
        ],
        &handle_telemetry_event/4,
        nil
      )

      {:ok, %{}}
    end

    def handle_telemetry_event([:game_bot, :sessions, :started], measurements, metadata, _config) do
      Logger.info("Session started",
        game_id: metadata.game_id,
        measurements: measurements
      )
    end

    def handle_telemetry_event([:game_bot, :sessions, :error], measurements, metadata, _config) do
      Logger.error("Session error",
        game_id: metadata.game_id,
        error: metadata.error,
        measurements: measurements
      )
    end
  end
  ```

## Phase 3: Integration

### 3.1 Application Integration
- [ ] Update `GameBot.Application` module
  ```elixir
  defmodule GameBot.Application do
    use Application

    def start(_type, _args) do
      children = [
        GameBot.GameSessions.Registry,
        GameBot.GameSessions.Supervisor,
        GameBot.GameSessions.Manager,
        GameBot.GameSessions.Monitor
      ]

      opts = [strategy: :one_for_one, name: GameBot.Supervisor]
      Supervisor.start_link(children, opts)
    end
  end
  ```

### 3.2 Command Integration
- [ ] Update command handlers
  ```elixir
  defmodule GameBot.Domain.Commands.GameCommandHandler do
    alias GameBot.GameSessions

    def handle(%StartGame{} = command) do
      GameSessions.Supervisor.start_session(command.game_id,
        guild_id: command.guild_id,
        mode: command.mode
      )
    end

    def handle(%ProcessGuess{} = command) do
      case GameSessions.Registry.whereis(command.game_id) do
        {:ok, pid} -> GenStateMachine.cast(pid, {:process_command, command})
        error -> error
      end
    end
  end
  ```

## Phase 4: Testing

### 4.1 Unit Tests
- [ ] Create session test modules
  ```elixir
  defmodule GameBot.GameSessions.SessionTest do
    use ExUnit.Case, async: true

    setup do
      game_id = "test_#{:crypto.strong_rand_bytes(8) |> Base.encode16()}"
      {:ok, pid} = GameBot.GameSessions.Session.start_link(game_id,
        guild_id: "test",
        mode: :two_player
      )
      %{game_id: game_id, pid: pid}
    end

    test "initializes in correct state", %{pid: pid} do
      assert :sys.get_state(pid).state == :initializing
    end

    test "processes commands in active state", %{pid: pid, game_id: game_id} do
      # Test command processing
    end
  end
  ```

### 4.2 Integration Tests
- [ ] Create integration test modules
  ```elixir
  defmodule GameBot.GameSessions.IntegrationTest do
    use GameBot.DataCase

    test "manages complete session lifecycle" do
      # Test session lifecycle
    end
  end
  ```

## Success Criteria

1. **Resource Management**
   - Memory leaks eliminated
   - Proper cleanup
   - Resource limits enforced

2. **Fault Tolerance**
   - Proper error handling
   - Session recovery
   - State consistency

3. **Monitoring**
   - Session metrics
   - Error tracking
   - Performance monitoring

## Migration Strategy

1. **Phase 1: Development (2 days)**
   - Implement core infrastructure
   - Add state machine
   - Create monitoring

2. **Phase 2: Integration (2 days)**
   - Update command handling
   - Update event handling
   - Add telemetry

3. **Phase 3: Testing (1 day)**
   - Unit tests
   - Integration tests
   - Load tests

4. **Phase 4: Deployment (1 day)**
   - Gradual rollout
   - Monitor metrics
   - Document changes

## Risks and Mitigation

### Resource Risks
- **Risk**: Memory leaks
- **Mitigation**: Proper cleanup and monitoring

### State Risks
- **Risk**: Inconsistent state
- **Mitigation**: State machine validation

### Concurrency Risks
- **Risk**: Race conditions
- **Mitigation**: Proper synchronization 