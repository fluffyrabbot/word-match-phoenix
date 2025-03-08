# Warning Fix Roadmap

This document outlines the remaining critical and high priority warnings to address in the GameBot codebase.

## Priority 0: Architectural Issues

### 0.1 EventStore Architecture Inconsistencies
- [ ] Resolve layering violations:
  - [ ] Move EventStore.Serializer to Infrastructure layer
  - [ ] Remove direct EventStructure dependency from adapter
  - [ ] Create proper boundary between Domain and Infrastructure layers
- [ ] Consolidate error handling:
  - [ ] Create unified error type system across all EventStore modules
  - [ ] Move Error module to separate file
  - [ ] Standardize error conversion from EventStore to domain
- [ ] Fix transaction management:
  - [ ] Remove redundant validation in transaction module
  - [ ] Implement proper transaction boundaries
  - [ ] Add transaction logging and monitoring
- [ ] Improve configuration management:
  - [ ] Centralize configuration in single location
  - [ ] Add runtime configuration validation
  - [ ] Document all configuration options

### 0.2 EventStore Integration Design
- [ ] Implement proper event versioning:
  - [ ] Add event schema versioning
  - [ ] Add event upgrade mechanisms
  - [ ] Add version validation on read/write
- [ ] Improve concurrency handling:
  - [ ] Add proper stream locking mechanisms
  - [ ] Implement retry strategies with backoff
  - [ ] Add deadlock detection
- [ ] Add proper monitoring:
  - [ ] Implement comprehensive telemetry
  - [ ] Add performance metrics
  - [ ] Add health checks
- [ ] Improve error recovery:
  - [ ] Add event replay capability
  - [ ] Implement proper cleanup on failures
  - [ ] Add automatic recovery strategies

### 0.3 Code Organization
- [ ] Reorganize EventStore modules:
  - [ ] Split adapter into smaller focused modules
  - [ ] Create proper type specifications
  - [ ] Add comprehensive documentation
- [ ] Implement proper testing infrastructure:
  - [ ] Add integration test helpers
  - [ ] Add proper mocking support
  - [ ] Add performance test suite

## Priority 1: Critical Functionality Issues

### 1.1 EventStore Integration (CRITICAL)
- [ ] Fix EventStore API compatibility issues:
  - [ ] Replace `EventStore.Config.parse/2` with `parse/1` in migrate.ex and event_store.ex
  - [ ] Fix `EventStore.Storage.Initializer.migrate/2` usage in migrate.ex
  - [ ] Update `EventStore.Storage.Initializer.reset!/1` to use correct arity
  - [ ] Fix undefined `Ecto.Repo.transaction/3` in postgres.ex
- [ ] Implement proper stream versioning and concurrency control
- [ ] Add proper error handling for EventStore operations

### 1.2 Critical Type and Function Violations
- [ ] Fix DateTime API usage:
  ```elixir
  DateTime.from_iso8601!/1 is undefined or private
  ```
- [ ] Fix undefined event functions:
  ```elixir
  GameBot.Domain.Events.GameCompleted.new/5 is undefined
  GameBot.Domain.Events.EventStructure.validate/1 is undefined
  ```
- [ ] Fix undefined error event functions:
  ```elixir
  GuessError.new/5 is undefined (should be new/6)
  RoundCheckError.new/2 is undefined (should be new/3)
  GuessPairError.new/5 is undefined (should be new/6)
  ```

### 1.3 Critical Behaviour Conflicts
- [ ] Fix conflicting behaviours in TestEventStore:
  ```elixir
  warning: conflicting behaviours found. Callback function init/1 is defined by both EventStore and GenServer
  ```
- [ ] Fix missing @impl annotations for EventStore callbacks:
  - [ ] `ack/2` in GameBot.Infrastructure.EventStore
  - [ ] `ack/2` in GameBot.Infrastructure.Persistence.EventStore.Postgres

### 1.4 Deprecated API Usage
- [ ] Replace deprecated System calls:
  ```elixir
  System.get_pid/0 is deprecated. Use System.pid/0 instead
  ```
- [ ] Fix range syntax warnings:
  ```elixir
  1..-1 has a default step of -1, please write 1..-1//-1 instead
  ```

## Priority 2: High Priority Issues

### 2.1 Function Organization and Documentation
- [ ] Group related function clauses together:
  - [ ] `handle_event/1` and `handle_event/2` in UserProjection
  - [ ] `handle_game_summary/2` in ReplayCommands
  - [ ] `handle_call/3` in TestEventStore
  - [ ] `init/1` in TestEventStore
- [ ] Fix duplicate @doc attributes:
  - [ ] Remove duplicate docs in ReplayCommands.handle_game_summary/2

### 2.2 Function Signature Issues
- [ ] Fix unused default arguments:
  ```elixir
  fetch_game_events/2 default values are never used
  ```
- [ ] Fix function arity mismatches:
  - [ ] GuessError.new/5 vs new/6
  - [ ] RoundCheckError.new/2 vs new/3
  - [ ] GuessPairError.new/5 vs new/6

### 2.3 Unused Code Cleanup (High Priority)
- [ ] Clean up unused functions in EventStore.Adapter:
  - [ ] Error handling functions (validation_error, timeout_error, etc.)
  - [ ] Helper functions (prepare_events, extract_event_data, etc.)
  - [ ] Retry mechanism functions (exponential_backoff, do_append_with_retry)
- [ ] Remove unused module attributes:
  - [ ] `@min_word_length` and `@max_word_length` in Listener
- [ ] Clean up unused imports and aliases:
  - [ ] `Mix.Ecto` in migrate.ex
  - [ ] `Message` in team_commands.ex
  - [ ] `EventStore` in stats_commands.ex
  - [ ] `BaseEvent` in event_store/serializer.ex

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