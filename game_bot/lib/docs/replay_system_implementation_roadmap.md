# Replay System Implementation Roadmap

## Overview
This document outlines the step-by-step implementation plan for the replay system using event stream references. The system will store lightweight replay references that point to the original event streams rather than duplicating event data.

## Phase 1: Core Architecture

### 1.1 Type Definitions (Estimated: 1 day)
- [ ] Define `GameBot.Replay.Types` module
- [ ] Create `base_replay` type with necessary fields
- [ ] Define `base_stats` type 
- [ ] Create type definitions for mode-specific stats

### 1.2 Base Behavior (Estimated: 1 day)
- [ ] Create `GameBot.Replay.BaseReplay` behavior
- [ ] Implement `build_replay/1` callback specification
- [ ] Implement `format_embed/1` callback specification
- [ ] Implement `format_summary/1` callback specification
- [ ] Add `calculate_mode_stats/1` optional callback

### 1.3 Name Generator (Estimated: 1 day)
- [ ] Create `GameBot.Replay.Utils.NameGenerator` module
- [ ] Load dictionary words from priv/dictionary.txt
- [ ] Implement random word selection function
- [ ] Create 3-digit number generator
- [ ] Implement unique name generation function
- [ ] Add collision detection and retry logic
- [ ] Write tests for uniqueness and readability

## Phase 2: Database Infrastructure

### 2.1 Schema Definition (Estimated: 1 day)
- [ ] Create migration for `game_replays` table
  - [ ] Add `replay_id` as primary identifier
  - [ ] Add `game_id` to reference event stream
  - [ ] Add `display_name` for memorable identifier
  - [ ] Include `mode`, `start_time`, `end_time` fields
  - [ ] Add `base_stats` and `mode_stats` JSON fields
- [ ] Create migration for `replay_access_logs` table
- [ ] Add necessary indexes for performance

### 2.2 Repository Implementation (Estimated: 2 days)
- [ ] Create `GameBot.Replay.Storage` module
- [ ] Implement `store_replay/6` function
- [ ] Implement `get_replay/1` function (with event loading)
- [ ] Implement `get_replay_metadata/1` function (without events)
- [ ] Implement `list_replays/1` with filtering options
- [ ] Add `cleanup_old_replays/0` function
- [ ] Write integration tests with database

### 2.3 Caching Layer (Estimated: 1 day)
- [ ] Create ETS-based cache for replay metadata
- [ ] Implement cache lookup before database queries
- [ ] Add cache invalidation strategy
- [ ] Configure TTL for cached items
- [ ] Add monitoring for cache hit/miss ratio

## Phase 3: Event Processing

### 3.1 Game Completion Handler (Estimated: 2 days)
- [ ] Create game completion event subscription
- [ ] Implement handler to process completed games
- [ ] Add logic to calculate base statistics from events
- [ ] Generate unique memorable replay name
- [ ] Store replay reference with stats

### 3.2 Statistics Calculation (Estimated: 2 days)
- [ ] Create `GameBot.Replay.Utils.StatsCalculator` module
- [ ] Implement functions for common statistics
- [ ] Add mode-specific stat calculation
- [ ] Write unit tests for accuracy
- [ ] Benchmark performance for large event sets

### 3.3 Error Handling (Estimated: 1 day)
- [ ] Implement validation for event streams
- [ ] Add error recovery strategies
- [ ] Create meaningful error messages
- [ ] Add telemetry for error monitoring
- [ ] Write tests for error cases

## Phase 4: Mode-Specific Implementations

### 4.1 Two Player Replay (Estimated: 2 days)
- [ ] Create `GameBot.Replay.TwoPlayerReplay` module
- [ ] Implement event reconstruction logic
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

## Total Estimated Time: 28 days

## Implementation Checklist for Memorable Names

### Design Considerations
- [ ] Choose naming pattern: `{word}-{3-digit-number}` (e.g., "banana-742")
- [ ] Ensure names are URL-safe (no spaces or special characters)
- [ ] Make display names case-insensitive for lookup
- [ ] Add configuration for word filters (if needed)

### Name Generator Implementation
- [ ] Create module for name generation using dictionary.txt
- [ ] Implement collision detection with database check
- [ ] Add retry logic with different word/number if collision occurs
- [ ] Create helper functions for name formatting
- [ ] Write tests for uniqueness and distribution

### Integration Points
- [ ] Generate name when game completes
- [ ] Store both internal ID and display name
- [ ] Allow lookup by either name or ID
- [ ] Use display names in user-facing interfaces
- [ ] Add name generator to replay persistence flow

### UI/UX Considerations
- [ ] Show friendly names in Discord embeds
- [ ] Make names easily copyable
- [ ] Add validation for name lookup commands
- [ ] Create error messages for invalid names
- [ ] Consider autocomplete for partial name matches 