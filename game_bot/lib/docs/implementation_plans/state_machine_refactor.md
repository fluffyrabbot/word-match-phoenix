# Game State Machine Refactor Plan

## Overview

This document outlines the plan for implementing a proper state machine for game states using `gen_statem`. This will provide better state management, clear transitions, and improved validation.

## Phase 1: Core State Machine

### 1.1 Base State Machine Implementation
- [ ] Create `GameBot.Domain.GameStateMachine` module
  ```elixir
  defmodule GameBot.Domain.GameStateMachine do
    use GenStateMachine, callback_mode: :state_functions

    # States
    @states [:initializing, :player_joining, :active, :round_end, :completed]
    
    # Data structure
    @type game_data :: %{
      game_id: String.t(),
      guild_id: String.t(),
      mode: atom(),
      teams: map(),
      round: pos_integer(),
      start_time: DateTime.t() | nil,
      end_time: DateTime.t() | nil,
      metadata: map()
    }

    def start_link(game_id, opts \\ []) do
      GenStateMachine.start_link(__MODULE__, {game_id, opts}, name: via_tuple(game_id))
    end

    def init({game_id, opts}) do
      data = %{
        game_id: game_id,
        guild_id: Keyword.fetch!(opts, :guild_id),
        mode: Keyword.fetch!(opts, :mode),
        teams: %{},
        round: 1,
        start_time: nil,
        end_time: nil,
        metadata: %{}
      }
      {:ok, :initializing, data}
    end

    # State: Initializing
    def initializing(:cast, {:add_team, team_id, players}, data) do
      with :ok <- validate_team(players),
           new_data <- put_in(data.teams[team_id], players) do
        if ready_to_start?(new_data) do
          {:next_state, :player_joining, new_data}
        else
          {:keep_state, new_data}
        end
      else
        {:error, reason} -> {:keep_state_and_data, {:error, reason}}
      end
    end

    # State: Active
    def active(:cast, {:process_guess, team_id, guess}, data) do
      with {:ok, new_data} <- process_guess(data, team_id, guess) do
        if round_complete?(new_data) do
          {:next_state, :round_end, new_data}
        else
          {:keep_state, new_data}
        end
      end
    end

    # State: Round End
    def round_end(:cast, :start_next_round, data) do
      if game_complete?(data) do
        {:next_state, :completed, %{data | end_time: DateTime.utc_now()}}
      else
        {:next_state, :active, increment_round(data)}
      end
    end

    # State: Completed
    def completed(_event_type, _event, data) do
      {:keep_state_and_data, {:error, :game_completed}}
    end

    # Helper Functions
    defp via_tuple(game_id), do: {:via, Registry, {GameBot.GameRegistry, game_id}}
    
    defp validate_team(players) do
      cond do
        length(players) != 2 -> {:error, :invalid_team_size}
        !Enum.all?(players, &is_binary/1) -> {:error, :invalid_player_id}
        true -> :ok
      end
    end

    defp ready_to_start?(data) do
      case data.mode do
        :two_player -> map_size(data.teams) == 1
        :knockout -> map_size(data.teams) >= 2
        :race -> map_size(data.teams) >= 2
      end
    end

    defp all_players_ready?(data) do
      Enum.all?(data.teams, fn {_team_id, team_data} ->
        team_data.ready
      end)
    end

    defp process_guess(data, team_id, guess) do
      # Implement guess processing logic
      {:ok, data}
    end

    defp round_complete?(data) do
      # Implement round completion check
      false
    end

    defp game_complete?(data) do
      # Implement game completion check
      false
    end

    defp increment_round(data) do
      %{data | round: data.round + 1}
    end
  end
  ```

### 1.2 State Machine Supervisor
- [ ] Create `GameBot.Domain.GameStateMachine.Supervisor` module
  ```elixir
  defmodule GameBot.Domain.GameStateMachine.Supervisor do
    use DynamicSupervisor

    def start_link(init_arg) do
      DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
    end

    def init(_init_arg) do
      DynamicSupervisor.init(strategy: :one_for_one)
    end

    def start_game(game_id, opts) do
      child_spec = {GameBot.Domain.GameStateMachine, {game_id, opts}}
      DynamicSupervisor.start_child(__MODULE__, child_spec)
    end

    def stop_game(game_id) do
      case Registry.lookup(GameBot.GameRegistry, game_id) do
        [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
        [] -> {:error, :not_found}
      end
    end
  end
  ```

## Phase 2: State Validation and Events

### 2.1 State Validation
- [ ] Create validation modules for each state
  ```elixir
  defmodule GameBot.Domain.GameStateMachine.Validation do
    def validate_state_transition(from, to, data) do
      case {from, to} do
        {:initializing, :player_joining} -> validate_initialization(data)
        {:player_joining, :active} -> validate_player_readiness(data)
        {:active, :round_end} -> validate_round_completion(data)
        {:round_end, :active} -> validate_round_start(data)
        {:round_end, :completed} -> validate_game_completion(data)
        _ -> {:error, :invalid_transition}
      end
    end

    defp validate_initialization(data) do
      with :ok <- validate_teams(data.teams),
           :ok <- validate_mode(data.mode) do
        :ok
      end
    end

    # Add other validation functions
  end
  ```

### 2.2 State Events
- [ ] Create event modules for state transitions
  ```elixir
  defmodule GameBot.Domain.GameStateMachine.Events do
    defmodule StateChanged do
      @derive Jason.Encoder
      defstruct [:game_id, :from_state, :to_state, :timestamp, :metadata]
    end

    defmodule StateValidationFailed do
      @derive Jason.Encoder
      defstruct [:game_id, :current_state, :attempted_state, :reason, :timestamp]
    end
  end
  ```

## Phase 3: Integration

### 3.1 Game Session Integration
- [ ] Update `GameBot.GameSessions.Session` to use state machine
  ```elixir
  defmodule GameBot.GameSessions.Session do
    def start_game(game_id, opts) do
      GameBot.Domain.GameStateMachine.Supervisor.start_game(game_id, opts)
    end

    def process_command(game_id, command) do
      case Registry.lookup(GameBot.GameRegistry, game_id) do
        [{pid, _}] -> GenStateMachine.call(pid, {:command, command})
        [] -> {:error, :game_not_found}
      end
    end
  end
  ```

### 3.2 Command Handler Integration
- [ ] Update command handlers to work with state machine
  ```elixir
  defmodule GameBot.Domain.Commands.GameCommandHandler do
    def handle(%StartGame{} = command) do
      GameBot.Domain.GameStateMachine.Supervisor.start_game(
        command.game_id,
        guild_id: command.guild_id,
        mode: command.mode
      )
    end

    def handle(%ProcessGuess{} = command) do
      GameBot.GameSessions.Session.process_command(
        command.game_id,
        {:process_guess, command.team_id, command.guess}
      )
    end
  end
  ```

## Phase 4: Testing

### 4.1 Unit Tests
- [ ] Create comprehensive unit tests for state machine
  ```elixir
  defmodule GameBot.Domain.GameStateMachineTest do
    use ExUnit.Case
    alias GameBot.Domain.GameStateMachine

    setup do
      game_id = "test_#{:crypto.strong_rand_bytes(8) |> Base.encode16()}"
      {:ok, pid} = GameStateMachine.start_link(game_id, guild_id: "test", mode: :two_player)
      %{game_id: game_id, pid: pid}
    end

    test "initializes in correct state", %{pid: pid} do
      assert :sys.get_state(pid) == :initializing
    end

    # Add more test cases
  end
  ```

### 4.2 Integration Tests
- [ ] Create integration tests for state machine
  ```elixir
  defmodule GameBot.Domain.GameStateMachineIntegrationTest do
    use GameBot.DataCase
    alias GameBot.Domain.GameStateMachine

    test "completes full game lifecycle" do
      # Test complete game flow
    end
  end
  ```

## Success Criteria

1. **State Management**
   - Clear state transitions
   - Proper validation
   - Event emission

2. **Error Handling**
   - Proper error states
   - Clear error messages
   - Recovery paths

3. **Performance**
   - State transitions < 10ms
   - Memory usage < 1MB per game
   - Concurrent games > 100

## Migration Strategy

1. **Phase 1: Development (2 days)**
   - Implement core state machine
   - Add validation
   - Create tests

2. **Phase 2: Integration (2 days)**
   - Update game sessions
   - Update command handlers
   - Add monitoring

3. **Phase 3: Testing (1 day)**
   - Run integration tests
   - Performance testing
   - Load testing

4. **Phase 4: Deployment (1 day)**
   - Gradual rollout
   - Monitor metrics
   - Document changes

## Risks and Mitigation

### State Machine Risks
- **Risk**: Complex state transitions
- **Mitigation**: Comprehensive validation

### Performance Risks
- **Risk**: Memory leaks
- **Mitigation**: Proper cleanup

### Integration Risks
- **Risk**: Breaking changes
- **Mitigation**: Gradual rollout 