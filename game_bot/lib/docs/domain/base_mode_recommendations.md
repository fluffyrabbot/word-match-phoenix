# BaseMode Implementation Recommendations

## Overview
This document outlines required changes and suggested improvements for the `GameBot.Domain.GameModes.BaseMode` module to ensure proper integration with the event sourcing architecture and robust game state management.

## Required Changes

### 1. Event Integration

#### Round Management
```elixir
@callback start_round(GameState.t()) :: {:ok, GameState.t(), RoundStarted.t()} | error()
@callback end_round(GameState.t()) :: {:ok, GameState.t(), [Event.t()]} | error()

def start_round(state) do
  event = %RoundStarted{
    game_id: game_id(state),
    mode: state.mode,
    round_number: state.round_number,
    team_states: get_team_states(state),
    timestamp: DateTime.utc_now(),
    metadata: build_metadata(state)
  }
  {:ok, state, event}
end
```

#### Role Management
```elixir
@type roles :: %{player_id() => :giver | :guesser}

def initialize_game(mode, game_id, teams, roles, config) do
  state = GameState.new(mode, teams)
  validate_roles!(teams, roles)
  
  event = %GameStarted{
    game_id: game_id,
    mode: mode,
    round_number: 1,
    teams: teams,
    team_ids: Map.keys(teams),
    player_ids: List.flatten(Map.values(teams)),
    roles: roles,
    config: config,
    timestamp: DateTime.utc_now(),
    metadata: build_metadata(state)
  }
  {:ok, state, [event]}
end
```

### 2. State Management

#### State Validation
```elixir
def validate_state!(state) do
  cond do
    is_nil(state.mode) ->
      raise ArgumentError, "game mode is required"
    is_nil(state.round_number) ->
      raise ArgumentError, "round number is required"
    map_size(state.teams) == 0 ->
      raise ArgumentError, "at least one team is required"
    true -> :ok
  end
end

def validate_roles!(teams, roles) do
  player_ids = List.flatten(Map.values(teams))
  
  unless Enum.all?(roles, fn {player_id, role} ->
    player_id in player_ids and role in [:giver, :guesser]
  end) do
    raise ArgumentError, "invalid roles configuration"
  end
end
```

#### State Transitions
```elixir
@type transition :: :start_round | :end_round | :process_guess | :abandon_guess | :complete_game

def validate_transition!(state, transition) do
  case {state.status, transition} do
    {:initialized, :start_round} -> :ok
    {:in_round, :process_guess} -> :ok
    {:in_round, :abandon_guess} -> :ok
    {:in_round, :end_round} -> :ok
    {:round_ended, :start_round} -> :ok
    {:round_ended, :complete_game} -> :ok
    {status, transition} ->
      raise ArgumentError, "invalid transition #{transition} from state #{status}"
  end
end
```

### 3. Event Handling

#### Event Metadata
```elixir
def build_metadata(state) do
  %{
    client_version: Application.spec(:game_bot, :vsn),
    server_version: System.version(),
    timestamp: DateTime.utc_now(),
    correlation_id: state.correlation_id,
    causation_id: state.last_event_id
  }
end
```

#### Event Validation
```elixir
def validate_event!(event) do
  case event.__struct__.validate(event) do
    :ok -> :ok
    {:error, reason} ->
      raise ArgumentError, "invalid event: #{reason}"
  end
end
```

## Suggested Improvements

### 1. Concurrency Management

#### Process Registry
```elixir
defmodule GameBot.Domain.GameRegistry do
  def register_game(game_id) do
    Registry.register(__MODULE__, game_id, :ok)
  end
  
  def lookup_game(game_id) do
    Registry.lookup(__MODULE__, game_id)
  end
end
```

#### Timeout Handling
```elixir
def start_guess_timer(state, team_id) do
  timer_ref = Process.send_after(self(), {:guess_timeout, team_id}, state.config.guess_timeout)
  put_in(state.timers[team_id], timer_ref)
end

def cancel_guess_timer(state, team_id) do
  if timer_ref = state.timers[team_id] do
    Process.cancel_timer(timer_ref)
  end
  update_in(state.timers, &Map.delete(&1, team_id))
end
```

### 2. Error Handling

#### Custom Errors
```elixir
defmodule GameBot.Domain.GameError do
  defexception [:type, :message]
  
  def invalid_state(details), do: %__MODULE__{type: :invalid_state, message: details}
  def invalid_transition(details), do: %__MODULE__{type: :invalid_transition, message: details}
  def invalid_action(details), do: %__MODULE__{type: :invalid_action, message: details}
end
```

#### Error Recovery
```elixir
def safe_process_guess(state, team_id, guess_pair) do
  try do
    process_guess_pair(state, team_id, guess_pair)
  rescue
    e in GameError ->
      {:error, e.message}
    e in ArgumentError ->
      {:error, "invalid guess parameters: #{e.message}"}
    e ->
      Logger.error("Unexpected error processing guess: #{inspect(e)}")
      {:error, "internal error"}
  end
end
```

### 3. Telemetry Integration

```elixir
def emit_telemetry(event_name, measurements, metadata) do
  :telemetry.execute(
    [:game_bot, :game, event_name],
    measurements,
    metadata
  )
end

def process_guess_pair(state, team_id, guess_pair) do
  start_time = System.monotonic_time()
  
  result = do_process_guess_pair(state, team_id, guess_pair)
  
  emit_telemetry(:guess_processed, %{
    duration: System.monotonic_time() - start_time
  }, %{
    game_id: state.game_id,
    mode: state.mode,
    team_id: team_id,
    success: match?({:ok, _, _}, result)
  })
  
  result
end
```

### 4. Testing Support

```elixir
defmodule GameBot.Domain.GameModes.TestHelpers do
  def build_test_state(mode \\ :two_player) do
    %GameState{
      mode: mode,
      round_number: 1,
      teams: %{
        "team1" => %{player_ids: ["p1", "p2"]},
        "team2" => %{player_ids: ["p3", "p4"]}
      },
      roles: %{
        "p1" => :giver,
        "p2" => :guesser,
        "p3" => :giver,
        "p4" => :guesser
      },
      status: :initialized
    }
  end
  
  def simulate_game_sequence(state, events) do
    Enum.reduce(events, state, fn event, acc_state ->
      case apply_event(acc_state, event) do
        {:ok, new_state, _} -> new_state
        {:error, reason} -> raise "Failed to apply event: #{reason}"
      end
    end)
  end
end
```

## Implementation Checklist

### Required Changes
- [ ] Add missing RoundStarted event integration
- [ ] Implement proper role management
- [ ] Add state validation functions
- [ ] Implement state transition validation
- [ ] Add event metadata handling
- [ ] Implement event validation

### Suggested Improvements
- [ ] Add concurrency management
- [ ] Implement timeout handling
- [ ] Add custom error types
- [ ] Implement error recovery strategies
- [ ] Add telemetry integration
- [ ] Create testing helpers

## Migration Strategy

1. **Phase 1: Core Requirements**
   - Implement state validation
   - Add event validation
   - Add role management
   - Add round management

2. **Phase 2: Error Handling**
   - Add custom errors
   - Implement error recovery
   - Add validation checks

3. **Phase 3: Concurrency**
   - Add process registry
   - Implement timeout handling
   - Add state transition validation

4. **Phase 4: Monitoring**
   - Add telemetry
   - Implement logging
   - Add metrics collection

## Testing Requirements

1. **Unit Tests**
   - State transitions
   - Event validation
   - Role management
   - Error handling

2. **Integration Tests**
   - Full game sequences
   - Concurrent operations
   - Timeout scenarios
   - Error recovery

3. **Property Tests**
   - State invariants
   - Event consistency
   - Role assignments

## Documentation Requirements

1. **Module Documentation**
   - Behavior specification
   - Type specifications
   - Function documentation
   - Example usage

2. **Architecture Documentation**
   - Event flow diagrams
   - State transition diagrams
   - Error handling strategies
   - Concurrency model

3. **Testing Documentation**
   - Test helpers usage
   - Test data generation
   - Common test patterns 