# Warning Fix Roadmap

This document outlines the remaining critical and high priority warnings to address in the GameBot codebase.

## Priority 1: Critical Functionality Issues

### 1.1 EventStore Integration (CRITICAL)
- [ ] Fix EventStore API compatibility issues:
  - [ ] Replace `EventStore.Config.parse/2` with `parse/1` in migrate.ex
  - [ ] Fix `EventStore.Storage.Initializer.migrate/2` usage in migrate.ex
  - [ ] Update `EventStore.Storage.Initializer.reset!/1` to use correct arity
- [ ] Implement proper stream versioning and concurrency control
- [ ] Add proper error handling for EventStore operations

### 1.2 Critical Type Violations
- [ ] Fix pattern match that will never match in TestHelpers:
  ```elixir
  {:ok, new_state} -> new_state  # Incompatible with return type
  ```
- [ ] Fix missing fields in events:
  ```elixir
  event.finished_at  # Unknown key in GameFinished event
  event.started_at   # Unknown key in RoundStarted event
  ```

### 1.3 Critical Behaviour Conflicts
- [ ] Fix conflicting behaviours in TestEventStore:
  ```elixir
  warning: conflicting behaviours found. Callback function init/1 is defined by both EventStore and GenServer
  ```
- [ ] Fix module redefinition issues in test mocks:
  - [ ] `Nostrum.Api.Message`
  - [ ] `Nostrum.Api.Interaction`

### 1.4 Safe Function Implementation
- [ ] Implement missing safe functions in TestEventStore:
  - [ ] `safe_append_to_stream/4`
  - [ ] `safe_read_stream_forward/3`
  - [ ] `safe_stream_version/1`

## Priority 2: High Priority Issues

### 2.1 Documentation and Type Specifications
- [ ] Add proper @moduledoc for all EventStore modules
- [ ] Add @doc for all public functions
- [ ] Add @typedoc for all custom types
- [ ] Add @type specifications for all custom types
- [ ] Add @spec for all public functions
- [ ] Document error handling and recovery procedures

### 2.2 Testing Requirements
- [ ] Add unit tests for all EventStore operations
- [ ] Add integration tests for stream operations
- [ ] Add concurrency tests
- [ ] Add error handling tests
- [ ] Add tests for timeout and validation errors

### 2.3 Function Organization
- [ ] Group related function clauses together:
  - [ ] `handle_call/3` in NostrumApiMock
  - [ ] `handle_game_summary/2` in ReplayCommands
  - [ ] `handle_event/1` and `handle_event/2` in GameProjection
- [ ] Fix duplicate @doc attributes in ReplayCommands

## Priority 3: Code Quality Issues

### 3.1 Unused Code Cleanup
- [ ] Clean up unused functions in EventStore.Adapter:
  - [ ] Error handling functions (validation_error, timeout_error, etc.)
  - [ ] Helper functions (prepare_events, extract_event_data, etc.)
  - [ ] Retry mechanism functions (exponential_backoff, do_append_with_retry)
- [ ] Remove unused module attributes:
  - [ ] `@min_word_length` and `@max_word_length` in Listener
  - [ ] `@base_fields` in GameEvents
- [ ] Clean up unused imports:
  - [ ] `Mix.Ecto` in migrate.ex

### 3.2 Variable and Alias Cleanup
- [ ] Add underscore prefix to unused variables in core modules:
  - [ ] WordService (word parameter)
  - [ ] CommandHandler (interaction parameter)
  - [ ] TeamProjection (various id parameters)
- [ ] Remove unused aliases:
  - [ ] TeamProjection event aliases
  - [ ] GameMode-related aliases
  - [ ] EventStore-related aliases

## Completed Fixes Summary

### Critical Functionality
- [x] Fixed all Metadata module references and imports
- [x] Implemented missing TeamProjection functions
- [x] Fixed all command handler undefined functions
- [x] Fixed Game Mode typing issues
- [x] Fixed Command Handler typing issues
- [x] Fixed pattern matching issues in game sequence simulation
- [x] Fixed GameProjection key issues
- [x] Implemented GameFinished.new/4
- [x] Fixed incompatible types in ReplayCommands
- [x] Added missing @impl annotations
- [x] Fixed all critical EventStore adapter issues

### Event System
- [x] Added missing event fields (team_ids, started_at, finished_at, guild_id)
- [x] Implemented all required event creation functions
- [x] Fixed event serialization and deserialization

### API Updates
- [x] Updated all Logger calls to current API
- [x] Updated all Nostrum API calls to latest version
- [x] Fixed test mocking for Nostrum API

### Code Organization
- [x] Fixed function definition issues with default parameters
- [x] Added proper @impl annotations to behaviour implementations
- [x] Fixed import structures across modules

## Implementation Guidelines

1. Focus on EventStore-related issues first (data integrity)
2. Address type safety and behaviour conflicts next
3. Then move to documentation and testing
4. Finally handle code quality improvements

## Testing Strategy

1. Add tests for each critical fix
2. Focus on data integrity tests first
3. Add regression tests for fixed issues
4. Ensure error condition coverage

## Deployment Considerations

- High priority items should be addressed before merging new features
- Medium priority items should be fixed in the next cleanup phase
- Low priority items can be addressed during routine maintenance
- Consider feature flags for major changes 

## Implementation Notes
- Focus on fixing EventStore-related issues first as they are critical to data integrity
- Ensure all changes maintain CQRS principles
- Document all changes in commit messages
- Add tests for new functionality
- Update documentation to reflect changes

## Next Steps
1. Remove incorrect @impl annotations in EventStore modules
2. Implement proper error handling for stream operations
3. Add comprehensive type specifications
4. Add proper documentation
5. Implement test suite 