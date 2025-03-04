# Game Modes Migration Roadmap

## Overview

This document outlines the step-by-step migration from the current monolithic base mode to the new modular game modes architecture. The migration is designed to be incremental and reversible, with clear validation points at each step.

## Phase 0: Preparation

### 0.1 Create New Directory Structure
```bash
mkdir -p lib/game_bot/domain/game_modes/{behaviours,implementations,shared}
```

### 0.2 Set Up Test Infrastructure
```elixir
# test/support/game_modes/test_helpers.ex
defmodule GameBot.Test.GameModes.TestHelpers do
  def build_test_state(mode \\ :two_player)
  def simulate_game_sequence(state, events)
  def verify_event_sequence(events, expected_types)
end
```

## Phase 1: Core Behaviors (Week 1)

### 1.1 Define Base Interfaces
```elixir
# lib/game_bot/domain/game_modes/behaviours/game_mode.ex
defmodule GameBot.Domain.GameModes.Behaviour.GameMode do
  @callback init(game_id(), teams(), config()) ::
    {:ok, GameState.t()} | error()
  # ... other callbacks
end
```

### 1.2 Extract Common State Management
```elixir
# lib/game_bot/domain/game_modes/shared/state.ex
defmodule GameBot.Domain.GameModes.State do
  defstruct [:mode, :round_number, :teams, mode_state: %{}]
  
  def new(mode, teams), do: %__MODULE__{mode: mode, teams: teams}
  def update_after_guess(state, team_id, result)
  def update_round(state, round_number)
end
```

### 1.3 Create Event Building Helpers
```elixir
# lib/game_bot/domain/game_modes/shared/events.ex
defmodule GameBot.Domain.GameModes.Events do
  def build_base_event(state, type, fields)
  def build_metadata(state, opts \\ [])
end
```

## Phase 2: Two Player Mode Migration (Week 2)

### 2.1 Create Initial Implementation
```elixir
# lib/game_bot/domain/game_modes/implementations/two_player_mode.ex
defmodule GameBot.Domain.GameModes.TwoPlayerMode do
  use GameBot.Domain.GameModes.BaseMode
  
  # Implement core game mode behavior first
  @impl true
  def init(game_id, teams, config)
  @impl true
  def handle_guess(state, team_id, guess)
end
```

### 2.2 Add Round Management
```elixir
# Add to TwoPlayerMode
@impl GameBot.Domain.GameModes.Behaviour.RoundManager
def start_round(state)
def end_round(state)
```

### 2.3 Add Scoring
```elixir
# Add to TwoPlayerMode
@impl GameBot.Domain.GameModes.Behaviour.Scoring
def calculate_score(state, team_id, result)
def update_rankings(state, team_id, score)
```

### 2.4 Validation & Testing
```elixir
# test/domain/game_modes/implementations/two_player_mode_test.exs
defmodule GameBot.Test.GameModes.TwoPlayerModeTest do
  use ExUnit.Case
  
  test "completes full game sequence"
  test "handles round transitions"
  test "calculates scores correctly"
end
```

## Phase 3: Base Mode Refactoring (Week 3)

### 3.1 Extract Common Logic
```elixir
# lib/game_bot/domain/game_modes/base_mode.ex
defmodule GameBot.Domain.GameModes.BaseMode do
  # Move common functionality from old base_mode.ex
  def validate_guess_pair(state, team_id, guess_pair)
  def validate_team(state, team_id)
end
```

### 3.2 Add Shared Validation
```elixir
# lib/game_bot/domain/game_modes/shared/validation.ex
defmodule GameBot.Domain.GameModes.Validation do
  def validate_event(event)
  def validate_state(state)
  def validate_transition(state, action)
end
```

### 3.3 Create Test Support
```elixir
# test/support/game_modes/mode_test_case.ex
defmodule GameBot.Test.GameModes.ModeTestCase do
  use ExUnit.CaseTemplate
  
  using do
    quote do
      import GameBot.Test.GameModes.TestHelpers
      # Common test helpers and setup
    end
  end
end
```

## Phase 4: Knockout Mode Implementation (Week 4)

### 4.1 Core Implementation
```elixir
# lib/game_bot/domain/game_modes/implementations/knockout_mode.ex
defmodule GameBot.Domain.GameModes.KnockoutMode do
  use GameBot.Domain.GameModes.BaseMode
  
  def init(game_id, teams, roles, config)
  def handle_elimination(state, team_id)
end
```

### 4.2 Add Time Management
```elixir
# Add to KnockoutMode
def start_timer(state)
def handle_timeout(state)
def check_time_limit(state)
```

### 4.3 Add Elimination Logic
```elixir
# Add to KnockoutMode
def find_eliminated_teams(state)
def process_eliminations(state, eliminated)
def advance_teams(state, advancing)
```

## Phase 5: Race Mode Implementation (Week 5)

### 5.1 Core Implementation
```elixir
# lib/game_bot/domain/game_modes/implementations/race_mode.ex
defmodule GameBot.Domain.GameModes.RaceMode do
  use GameBot.Domain.GameModes.BaseMode
  
  def init(game_id, teams, roles, config)
  def handle_match(state, team_id, match)
end
```

### 5.2 Add Time Management
```elixir
# Add to RaceMode
def start_race_timer(state)
def handle_time_expired(state)
```

### 5.3 Add Scoring System
```elixir
# Add to RaceMode
def calculate_race_score(matches, time)
def update_race_rankings(state)
```

## Phase 6: Integration & Testing (Week 6)

### 6.1 Integration Tests
```elixir
# test/domain/game_modes/integration/mode_switching_test.exs
defmodule GameBot.Test.GameModes.Integration.ModeSwitchingTest do
  use ExUnit.Case
  
  test "switches between game modes"
  test "maintains consistent state"
  test "handles mode-specific events"
end
```

### 6.2 Performance Tests
```elixir
# test/domain/game_modes/performance/concurrent_games_test.exs
defmodule GameBot.Test.GameModes.Performance.ConcurrentGamesTest do
  use ExUnit.Case
  
  test "handles multiple concurrent games"
  test "maintains performance under load"
end
```

### 6.3 Event Store Integration
```elixir
# test/domain/game_modes/integration/event_store_test.exs
defmodule GameBot.Test.GameModes.Integration.EventStoreTest do
  use ExUnit.Case
  
  test "persists mode-specific events"
  test "reconstructs game state"
end
```

## Phase 7: Cleanup & Documentation (Week 7)

### 7.1 Code Cleanup
- Remove deprecated code
- Update type specifications
- Add missing documentation
- Optimize performance bottlenecks

### 7.2 Documentation
- Update architecture docs
- Add mode-specific guides
- Create example implementations
- Document testing strategies

### 7.3 Monitoring
- Add telemetry points
- Create dashboards
- Set up alerts

## Validation Points

### After Each Phase
1. Run full test suite
2. Verify event sequences
3. Check state transitions
4. Validate performance
5. Review documentation

### Mode-Specific Checks
1. Two Player Mode
   - Basic gameplay flow
   - Score calculation
   - Round management

2. Knockout Mode
   - Elimination logic
   - Tournament progression
   - Time management

3. Race Mode
   - Concurrent matches
   - Time tracking
   - Score aggregation

## Rollback Strategy

### For Each Phase
1. Keep old implementation alongside new code
2. Use feature flags to control rollout
3. Maintain backward compatibility in events
4. Store rollback procedures

### Emergency Rollback
1. Disable new mode implementations
2. Revert to base mode
3. Migrate affected games
4. Log and analyze failures

## Success Criteria

### Technical
- All tests passing
- Performance metrics met
- No regression in existing functionality
- Clean separation of concerns

### Functional
- All game modes operational
- Proper event handling
- State consistency maintained
- Smooth mode transitions

### Operational
- Monitoring in place
- Documentation complete
- Support procedures documented
- Team trained on new architecture 