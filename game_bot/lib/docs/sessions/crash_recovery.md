# Session Crash Recovery Implementation Checklist

## Overview
This document outlines the implementation steps needed for full game session recovery after crashes. The system uses event sourcing to rebuild game state, ensuring no game progress is lost even if a session process crashes.

## Core Requirements

### 1. Event Store Integration
- [ ] Configure EventStore for game events
- [ ] Define event schemas and versioning
- [ ] Implement event serialization/deserialization
- [ ] Set up event persistence with proper indexes

### 2. Event Types to Track
- [ ] Game initialization events
  - Game creation
  - Team setup
  - Initial state
- [ ] Game progress events
  - Guess submissions
  - Match results
  - Forbidden word updates
  - Score changes
- [ ] Round management events
  - Round starts/ends
  - Winner declarations
- [ ] Game state events
  - Status changes
  - Player joins/leaves

### 3. State Recovery Implementation
- [ ] Create state rebuilding function
  ```elixir
  def rebuild_state(game_id) do
    {:ok, events} = EventStore.read_stream_forward(game_id)
    Enum.reduce(events, initial_state(), &apply_event/2)
  end
  ```
- [ ] Implement event application functions for each event type
- [ ] Add validation for event ordering
- [ ] Handle version migrations if needed

### 4. Recovery Process Flow
1. [ ] Detect session crash
2. [ ] Fetch all events for game_id
3. [ ] Sort events by timestamp
4. [ ] Initialize empty game state
5. [ ] Apply events sequentially
6. [ ] Validate recovered state
7. [ ] Resume game from recovered state

### 5. Supervisor Integration
- [ ] Update supervisor to handle restarts
- [ ] Implement crash detection
- [ ] Add recovery attempt tracking
- [ ] Set appropriate restart strategy

### 6. Testing Requirements
- [ ] Unit tests for event application
- [ ] Integration tests for full recovery
- [ ] Crash simulation tests
- [ ] State consistency verification
- [ ] Performance benchmarks

## Implementation Steps

### Phase 1: Event System Setup
1. [ ] Define event schemas
2. [ ] Set up EventStore configuration
3. [ ] Implement event persistence
4. [ ] Add event validation

### Phase 2: State Recovery
1. [ ] Implement state rebuilding
2. [ ] Add event application logic
3. [ ] Create recovery triggers
4. [ ] Add state validation

### Phase 3: Supervisor Integration
1. [ ] Update supervisor configuration
2. [ ] Add crash handling
3. [ ] Implement recovery flow
4. [ ] Add monitoring

### Phase 4: Testing & Validation
1. [ ] Write unit tests
2. [ ] Create integration tests
3. [ ] Add performance tests
4. [ ] Document recovery procedures

## Recovery Function Template
```elixir
defmodule GameBot.GameSessions.Recovery do
  @moduledoc """
  Handles recovery of crashed game sessions using event sourcing.
  """

  def recover_session(game_id) do
    with {:ok, events} <- fetch_events(game_id),
         {:ok, initial_state} <- build_initial_state(events),
         {:ok, recovered_state} <- apply_events(initial_state, events),
         {:ok, _pid} <- restart_session(game_id, recovered_state) do
      {:ok, recovered_state}
    else
      error -> {:error, error}
    end
  end

  defp fetch_events(game_id) do
    EventStore.read_stream_forward(game_id)
  end

  defp build_initial_state(events) do
    # Extract initialization data from first event
  end

  defp apply_events(state, events) do
    # Apply events in order to rebuild state
  end

  defp restart_session(game_id, state) do
    # Start new session with recovered state
  end
end
```

## Error Handling

### Recovery Failures
- [ ] Implement retry mechanism
- [ ] Add failure logging
- [ ] Create error notifications
- [ ] Handle partial recoveries

### Data Consistency
- [ ] Validate event ordering
- [ ] Check state invariants
- [ ] Verify team/player data
- [ ] Ensure score consistency

### Edge Cases
- [ ] Handle missing events
- [ ] Deal with corrupt data
- [ ] Manage version mismatches
- [ ] Process concurrent recoveries

## Monitoring & Logging

### Metrics to Track
- [ ] Recovery attempts
- [ ] Success/failure rates
- [ ] Recovery duration
- [ ] Event count processed

### Logging Requirements
- [ ] Crash detection
- [ ] Recovery progress
- [ ] Error conditions
- [ ] State validation

## Notes
- Recovery should be transparent to users
- Maintain event ordering guarantees
- Consider performance impact of large event streams
- Document recovery procedures for operators 