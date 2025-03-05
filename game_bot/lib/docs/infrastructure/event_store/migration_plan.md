# Event Store Migration Plan

## Overview

This document outlines the implementation plan for setting up the event store database schema and migrations. The event store is a critical infrastructure component that will support all game modes and provide event sourcing capabilities.

## Phase 1: Database Schema Setup

### 1.1 Base Schema Structure
```sql
-- Event streams table
CREATE TABLE event_streams (
  stream_id text NOT NULL,
  stream_version bigint NOT NULL DEFAULT 0,
  created_at timestamp NOT NULL DEFAULT now(),
  updated_at timestamp NOT NULL DEFAULT now(),
  deleted_at timestamp,
  metadata jsonb,
  CONSTRAINT pk_event_streams PRIMARY KEY (stream_id)
);

-- Events table
CREATE TABLE events (
  event_id bigserial NOT NULL,
  stream_id text NOT NULL,
  stream_version bigint NOT NULL,
  event_type text NOT NULL,
  event_version integer NOT NULL DEFAULT 1,
  data jsonb NOT NULL,
  metadata jsonb,
  created_at timestamp NOT NULL DEFAULT now(),
  CONSTRAINT pk_events PRIMARY KEY (event_id),
  CONSTRAINT fk_events_stream FOREIGN KEY (stream_id) 
    REFERENCES event_streams(stream_id),
  CONSTRAINT uq_events_stream_version UNIQUE (stream_id, stream_version)
);

-- Subscriptions table
CREATE TABLE subscriptions (
  subscription_id text NOT NULL,
  stream_id text NOT NULL,
  last_seen_event_id bigint,
  last_seen_stream_version bigint,
  created_at timestamp NOT NULL DEFAULT now(),
  updated_at timestamp NOT NULL DEFAULT now(),
  metadata jsonb,
  CONSTRAINT pk_subscriptions PRIMARY KEY (subscription_id, stream_id),
  CONSTRAINT fk_subscriptions_stream FOREIGN KEY (stream_id) 
    REFERENCES event_streams(stream_id)
);
```

### 1.2 Indexes
```sql
-- Event streams indexes
CREATE INDEX idx_event_streams_created_at ON event_streams(created_at);
CREATE INDEX idx_event_streams_updated_at ON event_streams(updated_at);
CREATE INDEX idx_event_streams_metadata ON event_streams USING gin (metadata);

-- Events indexes
CREATE INDEX idx_events_stream_id ON events(stream_id);
CREATE INDEX idx_events_created_at ON events(created_at);
CREATE INDEX idx_events_type ON events(event_type);
CREATE INDEX idx_events_data ON events USING gin (data);
CREATE INDEX idx_events_metadata ON events USING gin (metadata);

-- Subscriptions indexes
CREATE INDEX idx_subscriptions_stream_id ON subscriptions(stream_id);
CREATE INDEX idx_subscriptions_last_seen ON subscriptions(last_seen_event_id);
```

## Phase 2: Migration Implementation

### 2.1 Migration Files
1. **Initial Setup** (`priv/event_store/migrations/20240000000000_initial_setup.exs`)
   - Create event_streams table
   - Create events table
   - Create subscriptions table
   - Add base indexes

2. **Schema Functions** (`priv/event_store/migrations/20240000000001_schema_functions.exs`)
   - Add append_to_stream function
   - Add read_stream_forward function
   - Add subscription management functions

### 2.2 Migration Commands
```bash
# Create migration
mix event_store.gen.migration create_event_store

# Run migrations
mix event_store.migrate

# Reset database (development only)
mix event_store.reset

# Drop database
mix event_store.drop
```

## Phase 3: Testing Infrastructure

### 3.1 Test Helpers (`test/support/event_store_case.ex`)
```elixir
defmodule GameBot.EventStoreCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias GameBot.Infrastructure.EventStore

      # Helper to create test events
      def create_test_event(type, data) do
        %{
          event_type: type,
          data: data,
          metadata: %{test: true}
        }
      end

      # Helper to create test stream
      def create_test_stream(stream_id, events) do
        EventStore.append_to_stream(stream_id, :any, events)
      end
    end
  end

  setup do
    # Clean event store before each test
    :ok = EventStore.reset!()
    :ok
  end
end
```

### 3.2 Test Files Structure
```
test/
└── game_bot/
    └── infrastructure/
        └── event_store/
            ├── event_store_test.exs       # Core functionality tests
            ├── serializer_test.exs        # Serialization tests
            ├── subscription_test.exs      # Subscription tests
            └── integration/
                ├── persistence_test.exs   # Event persistence tests
                └── replay_test.exs        # Event replay tests
```

## Phase 4: Implementation Steps

1. **Database Setup**
   - [ ] Create event store database
   - [ ] Configure connection settings
   - [ ] Set up test database

2. **Migration Files**
   - [ ] Create initial migration
   - [ ] Add schema functions
   - [ ] Test migrations up/down

3. **Test Infrastructure**
   - [ ] Set up test helpers
   - [ ] Create base test cases
   - [ ] Add integration tests

4. **Validation**
   - [ ] Verify schema creation
   - [ ] Test event persistence
   - [ ] Validate subscriptions
   - [ ] Check performance

## Success Criteria

1. **Database Operations**
   - All migrations run successfully
   - Schema matches specifications
   - Indexes are properly created
   - Functions work as expected

2. **Testing**
   - All tests pass
   - Coverage is adequate
   - Edge cases are handled
   - Performance is acceptable

3. **Integration**
   - Event store works with game modes
   - Subscriptions function properly
   - Error handling is robust
   - Recovery works as expected

## Notes

1. **Schema Versioning**
   - All events include version number
   - No backward compatibility needed yet
   - Version 1 for all current events
   - Migration path for future versions

2. **Performance Considerations**
   - Proper indexing for common queries
   - Batch operations for efficiency
   - Connection pooling configuration
   - Monitoring setup

3. **Security**
   - Schema permissions
   - Connection encryption
   - Environment variables for credentials
   - Audit logging capability

4. **Maintenance**
   - Regular cleanup process
   - Monitoring queries
   - Backup procedures
   - Recovery testing 