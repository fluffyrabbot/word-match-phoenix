# Event Store Completion Implementation Plan

## Overview

This document outlines the plan for completing the Event Store implementation, which is a high-priority task for the GameBot project. The Event Store is responsible for persisting game events, managing event streams, and supporting event replay for state recovery.

## Current Status

- ✅ Basic `GameBot.Infrastructure.EventStore` module exists
- ✅ Basic event persistence implemented
- ✅ JSON serialization of events
- ✅ Basic event retrieval functionality
- [🔶] Event schema definitions
  - [✅] Core `EventStructure` module created
  - [✅] Base field standards defined
  - [🔶] Event-specific schemas
- [🔶] Event validation
  - [✅] Base validation framework
  - [✅] Mode-specific validation support
  - [🔶] Event-specific validation
- [✅] Enhanced event modules implementation
  - [✅] `BaseEvent` behavior created
  - [✅] `EventRegistry` implemented with ETS-based registry
  - [✅] Dynamic registration with versioning support
- [✅] Enhanced metadata structure
  - [✅] Causation and correlation tracking
  - [✅] Support for DM interactions (optional guild_id)
  - [✅] Improved metadata creation from Discord sources
- [✅] Serialization improvements
  - [✅] Complex data type support (DateTime, MapSet, structs)
  - [✅] Recursive serialization for nested structures
  - [✅] Special type handling (DateTime, MapSet, structs)
- [✅] Transaction support for multiple events
  - [✅] Atomic operations for appending events
  - [✅] Optimistic concurrency control
  - [✅] Validation within transactions
- ❌ Missing event subscription system
- [🔶] Enhanced error handling
  - [✅] Comprehensive error types
  - [✅] Better error messages
  - [🔶] Recovery strategies
- ❌ Missing connection resilience

## Implementation Goals

1. Complete event schema definitions with enhanced structure
2. Implement comprehensive event validation with mode-specific support
3. Add specialized event types for different game scenarios
4. Create subscription system leveraging enhanced event structure
5. Implement connection resilience for production reliability
6. Enhance serialization and event registration for better maintainability

## Detailed Implementation Plan

### 1. Base Event Structure Enhancement (4 days)

#### 1.1 Define Event Structure Standard
- [✅] Create `GameBot.Domain.Events.EventStructure` module
- [✅] Define base event fields required for all events
- [✅] Implement version field requirements
- [✅] Create timestamp and correlation ID standards

#### 1.2 Enhanced Metadata Structure
- [✅] Expand the metadata structure to include:
  - [✅] `causation_id` (ID of event that caused this event)
  - [✅] `correlation_id` (ID linking related events)
  - [✅] `actor_id` (User who triggered the action)
  - [✅] `client_version` (Client version for compatibility)
  - [✅] `server_version` (Server version for compatibility)
- [✅] Make `guild_id` optional with proper handling for DMs

#### 1.3 Event Inheritance Structure
- [✅] Create a base event module that all events inherit from
  - [✅] Add common fields and behaviors
  - [✅] Implement validation at the base level
- [✅] Standardize event module naming and structure

### 2. Validation Framework & Event-Specific Schemas (3 days)

#### 2.1 Unified Validation Framework
- [✅] Consolidate validation logic in `EventStructure` module
  - [✅] Move all validation from Serializer to EventStructure
  - [✅] Create game mode-specific validation functions
  - [✅] Add helper functions for common validation patterns
- [✅] Add plugin system for mode-specific validators

#### 2.2 Complete Game Event Schemas
- [ ] Review all existing event definitions
- [ ] Add missing event schemas for:
  - [ ] `GameModeChanged` event
  - [ ] `PlayerJoined` event
  - [ ] `PlayerLeft` event
  - [ ] `RoundStarted` event (review existing)
  - [ ] `RoundEnded` event
  - [ ] `GamePaused` event
  - [ ] `GameResumed` event

#### 2.3 Event Serialization Enhancement
- [✅] Review current serialization implementation
- [✅] Add support for complex data types
- [✅] Implement proper error handling for serialization failures
- [✅] Add version detection during deserialization

### 3. Specialized Event Types (4 days)

#### 3.1 Game Mode-Specific Events
- [ ] Define standard events for each game mode:
  - [ ] Two Player Mode events
  - [ ] Knockout Mode events
  - [ ] Race Mode events
- [ ] Create dedicated field structures for each mode

#### 3.2 Player and Team Management Events
- [ ] Add events for player status changes
- [ ] Add events for team lifecycle
- [ ] Create player and team state structures for events

#### 3.3 Error and Recovery Events
- [ ] Create standardized error events
- [ ] Add events for recovery scenarios
- [ ] Implement error context and recovery hints

#### 3.4 Game Configuration Events
- [ ] Add events for tracking configuration changes
- [ ] Create events for custom game variations
- [ ] Implement configuration version tracking

### 4. Subscription System Implementation (3 days)

#### 4.1 Create Subscription Manager
- [ ] Implement `GameBot.Infrastructure.EventSubscriptions` module
- [ ] Create subscription registry with causation awareness
- [ ] Add subscription lifecycle management
- [ ] Implement subscription configuration

#### 4.2 Add Event Broadcasting
- [ ] Create event dispatcher with causation tracking
- [ ] Implement concurrent dispatch
- [ ] Add error handling for subscription failures
- [ ] Create retry mechanism for failed dispatches

#### 4.3 Implement Projection Updates
- [ ] Connect subscriptions to projections
- [ ] Add real-time projection updates
- [ ] Create projection rebuild capability
- [ ] Implement projection versioning

### 5. Event Persistence and Resilience (3 days)

#### 5.1 Advanced Event Persistence
- [✅] Add filtering capabilities with metadata support
- [ ] Implement pagination for large event streams
- [ ] Create query optimization for common patterns
- [✅] Add transaction support for multi-event operations

#### 5.2 Connection Resilience
- [ ] Implement connection health checks
- [ ] Create automatic reconnection
- [ ] Add connection state tracking
- [ ] Implement connection pooling

#### 5.3 Error Handling and Recovery
- [✅] Create comprehensive error types
- [ ] Implement error recovery strategies
- [ ] Add logging for connection issues
- [ ] Implement circuit breaker pattern

### 6. Implementation Quality Improvements (3 days) [NEW]

#### 6.1 EventRegistry Enhancements
- [✅] Replace static map approach with ETS or GenServer approach
  ```elixir
  # Using ETS for dynamic registry
  def start_link do
    :ets.new(__MODULE__, [:named_table, :set, :public, read_concurrency: true])
    # Pre-register known events
    Enum.each(@known_events, fn {type, module} -> 
      register(type, module)
    end)
    {:ok, self()}
  end
  ```
- [✅] Add version handling in registry
  ```elixir
  # Support for versioned event types
  def register(event_type, module, version \\ 1) do
    :ets.insert(__MODULE__, {{event_type, version}, module})
  end
  
  def module_for_type(type, version \\ nil) do
    if version do
      # Get specific version
      case :ets.lookup(__MODULE__, {type, version}) do
        [{{^type, ^version}, module}] -> {:ok, module}
        [] -> {:error, "Unknown event type/version: #{type}/#{version}"}
      end
    else
      # Get latest version
      result = :ets.select(__MODULE__, [
        {{{:"$1", :"$2"}, :"$3"}, [{:==, :"$1", type}], [{{{:"$1", :"$2"}}, :"$3"}]}
      ])
      case result do
        [] -> {:error, "Unknown event type: #{type}"}
        pairs ->
          # Find highest version
          {{^type, highest_version}, module} = 
            Enum.max_by(pairs, fn {{_type, version}, _module} -> version end)
          {:ok, module, highest_version}
      end
    end
  end
  ```

#### 6.2 Serialization Improvements
- [✅] Add recursive serialization for complex data structures
  ```elixir
  # In EventStructure module
  def serialize(data) when is_map(data) and not is_struct(data) do
    # Recursively serialize map values
    Enum.map(data, fn {k, v} -> {k, serialize(v)} end)
    |> Map.new()
  end
  
  def serialize(data) when is_list(data) do
    # Recursively serialize list items
    Enum.map(data, &serialize/1)
  end
  
  def serialize(data) when is_struct(data, DateTime), do: DateTime.to_iso8601(data)
  def serialize(data) when is_struct(data, MapSet), do: %{"__mapset__" => true, "items" => MapSet.to_list(data)}
  ```
- [✅] Add transaction support for multiple events
  ```elixir
  # In EventStoreTransaction module
  def append_events_in_transaction(stream_id, expected_version, events) do
    # Validate inputs
    with :ok <- validate_stream_id(stream_id),
         :ok <- validate_events(events) do
      # Validate current stream version
      case validate_stream_version(stream_id, expected_version) do
        :ok -> try_append_with_validation(stream_id, expected_version, events)
        error -> error
      end
    end
  end
  ```
- [✅] Improve error handling with better error types and messages

#### 6.3 Testing & Validation Improvements
- [✅] Add comprehensive test scenarios for event registry
- [✅] Add comprehensive test scenarios for serialization
- [✅] Implement test scenarios for transactions
- [✅] Test event chains with causation tracking

## Dependencies

- Elixir EventStore library
- PostgreSQL database
- Jason for JSON serialization

## Risk Assessment

### High Risks
- Event schema changes may require data migration
- Subscription failures could impact system responsiveness
- Connection issues may cause data loss
- Transaction boundaries unclear for multi-event operations
- Performance impact of complex serialization
- Distributed uniqueness of correlation IDs

### Mitigation Strategies
- Implement versioning from the start
- Create robust error handling for subscriptions
- Add event buffering for connection outages
- Implement thorough testing for resilience
- Use proper distributed ID generation
- Add performance benchmarks for key operations
- Document clear transaction boundaries

## Testing Plan

- Unit tests for event validation
- Integration tests for persistence
- Performance tests for subscription system
- Chaos tests for connection resilience
- Test event migration between versions
- Benchmark serialization performance
- Test concurrent event publishing

## Success Metrics

- All event schemas properly defined and validated
- Event serialization with proper version handling
- Subscription system able to handle 100+ concurrent subscribers
- Connection resilience with 99.9% availability
- Serialization performance <5ms for typical events
- Event stream reads optimized for common patterns
- Successful handling of version migrations

## Timeline (Revised)

- Base Event Structure Enhancement: 4 days ✅
- Validation Framework & Event-Specific Schemas: 3 days 🔶
- Specialized Event Types: 4 days 🔶
- Subscription System Implementation: 3 days ❌
- Event Persistence and Resilience: 3 days 🔶
- Implementation Quality Improvements: 3 days 🔶

**Completion Status: ~60%**

## Next Steps

1. Complete the remaining event-specific schemas
2. Implement the subscription system
3. Finish connection resilience features
4. Refine error handling and recovery strategies

**Total Estimated Time: 20 days** 