# Replay System Implementation Roadmap

## Overview
This document outlines the step-by-step implementation plan for the replay system using event stream references. The system will store lightweight replay references that point to the original event streams rather than duplicating event data.

## Phase 0: Event Store Integration Prerequisites

### 0.1 Event Store Access Layer (Estimated: 1 day)
- [x] Create `GameBot.Replay.EventStoreAccess` module
- [x] Implement `fetch_game_events/2` function using proper adapter pattern
  ```elixir
  # Example usage pattern
  {:ok, events} = GameBot.Infrastructure.Persistence.EventStore.Adapter.read_stream_forward(game_id)
  ```
- [x] Implement pagination support for large event streams
- [x] Add proper error handling for event retrieval failures

### 0.2 Event Verification (Estimated: 1 day)
- [x] Create `GameBot.Replay.EventVerifier` module
- [x] Implement `verify_event_sequence/1` to ensure event chronology
- [x] Add `validate_game_completion/1` to confirm game ended properly
- [x] Create helpers for checking required events presence

### 0.3 Event Version Compatibility (Estimated: 1 day)
- [x] Create `GameBot.Replay.VersionCompatibility` module
- [x] Implement version checking for all event types
- [x] Add compatibility layer for potential version differences
- [x] Create tests for various event version scenarios

## Phase 1: Core Architecture

### 1.1 Type Definitions (Estimated: 1 day)
- [x] Define `GameBot.Replay.Types` module
- [x] Create `replay_reference` type with event stream pointer
  ```elixir
  @type replay_reference :: %{
    replay_id: String.t(),
    game_id: String.t(),
    display_name: String.t(),
    created_at: DateTime.t(),
    # Store reference pointer, not full events
    event_count: non_neg_integer()
  }
  ```
- [x] Define `base_stats` type 
- [x] Create type definitions for mode-specific stats

### 1.2 Base Behavior (Estimated: 1 day)
- [x] Create `GameBot.Replay.BaseReplay` behavior
- [x] Implement `build_replay/1` callback specification
  ```elixir
  # Must use EventStoreAccess module for retrieval
  @callback build_replay(game_id :: String.t()) :: 
    {:ok, GameBot.Replay.Types.replay_reference()} | {:error, term()}
  ```
- [x] Implement `format_embed/1` callback specification
- [x] Implement `format_summary/1` callback specification
- [x] Add `calculate_mode_stats/1` optional callback

### 1.3 Name Generator (Estimated: 1 day)
- [x] Create `GameBot.Replay.Utils.NameGenerator` module
- [x] Load dictionary words from priv/dictionary.txt
- [x] Implement random word selection function
- [x] Create 3-digit number generator
- [x] Implement unique name generation function
- [x] Add collision detection and retry logic
- [x] Write tests for uniqueness and readability

## Phase 2: Database Infrastructure

### 2.1 Schema Definition (Estimated: 1 day)
- [x] Create migration for `game_replays` table
  - [x] Add `replay_id` as primary identifier
  - [x] Add `game_id` to reference event stream
  - [x] Add `display_name` for memorable identifier
  - [x] Include `mode`, `start_time`, `end_time` fields
  - [x] Add `base_stats` and `mode_stats` JSON fields
  - [x] Add `event_version_map` to track event versions
- [x] Create migration for `replay_access_logs` table
- [x] Add necessary indexes for performance

### 2.2 Repository Implementation (Estimated: 2 days)
- [x] Create `GameBot.Replay.Storage` module
- [x] Implement `store_replay/6` function using transaction management
  ```elixir
  # Use transaction handling from event store
  GameBot.Infrastructure.Persistence.Repo.Transaction.execute(fn ->
    # Store reference details only, not full events
    Repo.insert(%GameReplay{...})
  end)
  ```
- [x] Implement `get_replay/1` function (with event loading using EventStoreAccess)
- [x] Implement `get_replay_metadata/1` function (without events)
- [x] Implement `list_replays/1` with filtering options
- [x] Add `cleanup_old_replays/0` function
- [x] Write integration tests with database

### 2.3 Caching Layer (Estimated: 1 day)
- [x] Create ETS-based cache for replay metadata
- [x] Implement cache lookup before database queries
- [x] Add cache invalidation strategy
- [x] Configure TTL for cached items
- [x] Add monitoring for cache hit/miss ratio

## Phase 3: Event Processing

### 3.1 Game Completion Handler (Estimated: 2 days)
- [x] Create game completion event subscription using `SubscriptionManager`
  ```elixir
  # Subscribe to game_completed events
  GameBot.Domain.Events.SubscriptionManager.subscribe_to_event_type("game_completed")
  ```
- [x] Implement handler to process completed games
- [x] Add logic to calculate base statistics from events
- [x] Generate unique memorable replay name
- [x] Store replay reference with stats

### 3.2 Statistics Calculation (Estimated: 2 days)
- [x] Create `GameBot.Replay.Utils.StatsCalculator` module
- [x] Implement functions for common statistics
- [x] Add mode-specific stat calculation
- [x] Write unit tests for accuracy
- [ ] Benchmark performance for large event sets

### 3.3 Error Handling (Estimated: 1 day)
- [x] Implement validation for event streams
- [x] Add error recovery strategies
  ```elixir
  # Pattern for graceful error handling with event streams
  case GameBot.Replay.EventStoreAccess.fetch_game_events(game_id) do
    {:ok, events} -> 
      # Process events
    {:error, :stream_not_found} ->
      # Handle missing game
    {:error, :deserialization_failed} ->
      # Handle corrupt events
    {:error, _} ->
      # General error handling
  end
  ```
- [x] Create meaningful error messages
- [x] Add telemetry for error monitoring
- [ ] Write tests for error cases

### 3.4 Core Infrastructure Testing (Estimated: 2 days)
- [x] Create test fixtures for common event data
- [x] Write comprehensive tests for EventStoreAccess
  - [x] Test pagination and batch handling
  - [x] Test error handling and recovery
  - [x] Test version retrieval and verification
- [x] Write tests for EventVerifier
  - [x] Test chronology verification
  - [x] Test completion validation
  - [x] Test event requirements checking
- [x] Write tests for VersionCompatibility
  - [x] Test version checking for event types
  - [x] Test version mapping functionality
  - [x] Test event validation
  - [x] Test replay compatibility validation
- [x] Write tests for Storage operations
  - [x] Test full lifecycle (store, retrieve, list, filter)
  - [x] Test error handling and constraints
  - [x] Test cleanup functionality
- [x] Write tests for Cache behavior
  - [x] Test cache hits and misses
  - [x] Test TTL and expiration
  - [x] Test eviction policies
- [x] Write tests for StatsCalculator
  - [x] Test base stats calculation
  - [x] Test mode-specific stats calculation
  - [x] Test error handling
- [x] Write tests for GameCompletionHandler
  - [x] Test end-to-end event processing
  - [x] Test error recovery in the pipeline
  - [x] Test replay creation with simulated events
- [ ] Set up CI integration for automated testing

## Phase 4: Mode-Specific Implementations

### 4.1 Two Player Replay (Estimated: 2 days)
- [ ] Create `GameBot.Replay.TwoPlayerReplay` module
- [ ] Implement event reconstruction logic using version-aware deserializers
  ```elixir
  # Pattern for handling event versions
  events
  |> Enum.map(fn event ->
    # Deserialize with version awareness
    case event.event_version do
      1 -> process_v1_event(event)
      v -> {:error, {:unsupported_version, v}}
    end
  end)
  ```
- [ ] Add mode-specific stats calculation
- [ ] Create embed formatting for two-player mode
- [ ] Write summary generation
- [ ] Add tests for reconstruction and formatting

### 4.2 Knockout Replay (Estimated: 2 days)
- [ ] Create `GameBot.Replay.KnockoutReplay` module
- [ ] Implement elimination tracking 
- [ ] Add round progression reconstruction
- [ ] Create embed formatting for knockout mode
- [ ] Write summary generation
- [ ] Add tests for reconstruction and formatting

### 4.3 Race Replay (Estimated: 2 days)
- [ ] Create `GameBot.Replay.RaceReplay` module
- [ ] Implement team progress tracking
- [ ] Add speed metrics calculation
- [ ] Create embed formatting for race mode
- [ ] Write summary generation
- [ ] Add tests for reconstruction and formatting

### 4.4 Golf Race Replay (Estimated: 2 days)
- [ ] Create `GameBot.Replay.GolfRaceReplay` module
- [ ] Implement score progression tracking
- [ ] Add efficiency metrics calculation
- [ ] Create embed formatting for golf race mode
- [ ] Write summary generation
- [ ] Add tests for reconstruction and formatting

## Phase 5: Command Integration

### 5.1 Command Implementation (Estimated: 2 days)
- [ ] Create `GameBot.Commands.ReplayCommand` module
- [ ] Implement command registration
- [ ] Add parameter parsing and validation
- [ ] Create permission checking
- [ ] Implement response formatting
- [ ] Add help documentation

### 5.2 Display Formatting (Estimated: 1 day)
- [ ] Create `GameBot.Replay.Utils.EmbedFormatter` module
- [ ] Implement common embedding utilities
- [ ] Add time formatting utilities
- [ ] Create paginated display support
- [ ] Add interactive components (if needed)

### 5.3 Testing & Documentation (Estimated: 2 days)
- [ ] Write end-to-end tests for command flow
- [ ] Create user documentation
- [ ] Add developer API documentation
- [ ] Write example usage guide
- [ ] Create error handling documentation

## Phase 6: Performance Optimization

### 6.1 Benchmarking (Estimated: 1 day)
- [ ] Benchmark replay generation for various game sizes
- [ ] Test database query performance
- [ ] Measure memory usage patterns
- [ ] Identify performance bottlenecks
- [ ] Document baseline performance

### 6.2 Optimization (Estimated: 2 days)
- [ ] Implement lazy loading optimizations
- [ ] Add batch processing for large operations
- [ ] Tune cache parameters based on usage patterns
- [ ] Optimize query patterns
- [ ] Implement pagination for large replays

### 6.3 Monitoring (Estimated: 1 day)
- [ ] Add telemetry for replay generation time
- [ ] Implement access logging
- [ ] Add error rate monitoring
- [ ] Create performance dashboards
- [ ] Set up alerting for performance degradation

## Current Progress
We have completed the following major components:
- ✓ Event Store Access Layer
- ✓ Event Verification
- ✓ Version Compatibility
- ✓ Type Definitions
- ✓ Base Behavior Definition
- ✓ Name Generator
- ✓ Database Schemas
- ✓ Repository Operations
- ✓ Caching Layer
- ✓ Game Completion Handler
- ✓ Statistics Calculator
- ✓ Core Testing (EventStoreAccess, EventVerifier, VersionCompatibility, Storage)

## Next Steps
Our next priorities should be:
1. Complete the remaining tests for core infrastructure:
   - Cache behavior tests
   - GameCompletionHandler tests
2. Develop the mode-specific replay modules (Two Player, Knockout, Race, Golf Race)
3. Implement the replay command interface
4. Create the embed formatting utilities
5. Complete testing and performance optimization 