# Event Store Migration Implementation Steps

## Step 1: Initial Setup (Estimated time: 1 hour)

### 1.1 Create Migration Directory
```bash
mkdir -p priv/event_store/migrations
```

### 1.2 Add Mix Tasks
Add to `mix.exs`:
```elixir
def project do
  [
    # ...
    aliases: [
      "event_store.setup": ["event_store.create", "event_store.migrate"],
      "event_store.reset": ["event_store.drop", "event_store.setup"],
      test: ["event_store.reset", "test"]
    ]
  ]
end
```

## Step 2: Base Migration (Estimated time: 2 hours)

### 2.1 Create Initial Migration
```bash
mix event_store.gen.migration create_event_store_schema
```

### 2.2 Implement Migration
In `priv/event_store/migrations/YYYYMMDDHHMMSS_create_event_store_schema.exs`:
```elixir
defmodule GameBot.Infrastructure.EventStore.Migrations.CreateEventStoreSchema do
  use Ecto.Migration

  def up do
    # Create schema
    execute "CREATE SCHEMA IF NOT EXISTS game_events"

    # Switch to event store schema
    execute "SET search_path TO game_events"

    # Create tables
    create_event_streams_table()
    create_events_table()
    create_subscriptions_table()
    create_indexes()
  end

  def down do
    execute "DROP SCHEMA IF EXISTS game_events CASCADE"
  end

  # Private functions for table creation
  defp create_event_streams_table do
    create table(:event_streams, primary_key: false) do
      add :stream_id, :text, primary_key: true
      add :stream_version, :bigint, null: false, default: 0
      add :created_at, :timestamp, null: false, default: fragment("now()")
      add :updated_at, :timestamp, null: false, default: fragment("now()")
      add :deleted_at, :timestamp
      add :metadata, :jsonb
    end
  end

  defp create_events_table do
    create table(:events) do
      add :stream_id, references(:event_streams, type: :text, on_delete: :restrict), null: false
      add :stream_version, :bigint, null: false
      add :event_type, :text, null: false
      add :event_version, :integer, null: false, default: 1
      add :data, :jsonb, null: false
      add :metadata, :jsonb
      add :created_at, :timestamp, null: false, default: fragment("now()")
    end

    create unique_index(:events, [:stream_id, :stream_version])
  end

  defp create_subscriptions_table do
    create table(:subscriptions, primary_key: false) do
      add :subscription_id, :text, null: false
      add :stream_id, references(:event_streams, type: :text, on_delete: :restrict), null: false
      add :last_seen_event_id, :bigint
      add :last_seen_stream_version, :bigint
      add :created_at, :timestamp, null: false, default: fragment("now()")
      add :updated_at, :timestamp, null: false, default: fragment("now()")
      add :metadata, :jsonb

      primary_key [:subscription_id, :stream_id]
    end
  end

  defp create_indexes do
    # Event streams indexes
    create index(:event_streams, [:created_at])
    create index(:event_streams, [:updated_at])
    create index(:event_streams, [:metadata], using: :gin)

    # Events indexes
    create index(:events, [:stream_id])
    create index(:events, [:created_at])
    create index(:events, [:event_type])
    create index(:events, [:data], using: :gin)
    create index(:events, [:metadata], using: :gin)

    # Subscriptions indexes
    create index(:subscriptions, [:stream_id])
    create index(:subscriptions, [:last_seen_event_id])
  end
end
```

## Step 3: Database Functions (Estimated time: 2 hours)

### 3.1 Create Functions Migration
```bash
mix event_store.gen.migration add_event_store_functions
```

### 3.2 Implement Functions
In `priv/event_store/migrations/YYYYMMDDHHMMSS_add_event_store_functions.exs`:
```elixir
defmodule GameBot.Infrastructure.EventStore.Migrations.AddEventStoreFunctions do
  use Ecto.Migration

  def up do
    # Switch to event store schema
    execute "SET search_path TO game_events"

    # Create functions
    create_append_events_function()
    create_read_events_function()
    create_subscription_functions()
  end

  def down do
    execute """
    DROP FUNCTION IF EXISTS append_to_stream;
    DROP FUNCTION IF EXISTS read_stream_forward;
    DROP FUNCTION IF EXISTS create_subscription;
    DROP FUNCTION IF EXISTS update_subscription;
    """
  end

  defp create_append_events_function do
    execute """
    CREATE OR REPLACE FUNCTION append_to_stream(
      p_stream_id text,
      p_expected_version bigint,
      p_events jsonb[]
    ) RETURNS TABLE (
      event_id bigint,
      stream_version bigint
    ) AS $$
    DECLARE
      v_stream_version bigint;
      v_event jsonb;
    BEGIN
      -- Get or create stream
      INSERT INTO event_streams (stream_id)
      VALUES (p_stream_id)
      ON CONFLICT (stream_id) DO UPDATE
      SET updated_at = now()
      RETURNING stream_version INTO v_stream_version;

      -- Check expected version
      IF p_expected_version IS NOT NULL AND p_expected_version != v_stream_version THEN
        RAISE EXCEPTION 'Wrong expected version: got %, but stream is at %',
          p_expected_version, v_stream_version;
      END IF;

      -- Append events
      FOR v_event IN SELECT jsonb_array_elements(p_events::jsonb)
      LOOP
        v_stream_version := v_stream_version + 1;
        
        INSERT INTO events (
          stream_id,
          stream_version,
          event_type,
          event_version,
          data,
          metadata
        )
        VALUES (
          p_stream_id,
          v_stream_version,
          v_event->>'event_type',
          (v_event->>'event_version')::integer,
          v_event->'data',
          v_event->'metadata'
        )
        RETURNING event_id, stream_version;
      END LOOP;

      -- Update stream version
      UPDATE event_streams
      SET stream_version = v_stream_version
      WHERE stream_id = p_stream_id;

      RETURN QUERY
      SELECT e.event_id, e.stream_version
      FROM events e
      WHERE e.stream_id = p_stream_id
      ORDER BY e.stream_version DESC
      LIMIT array_length(p_events, 1);
    END;
    $$ LANGUAGE plpgsql;
    """
  end

  defp create_read_events_function do
    execute """
    CREATE OR REPLACE FUNCTION read_stream_forward(
      p_stream_id text,
      p_start_version bigint DEFAULT 0,
      p_count integer DEFAULT 1000
    ) RETURNS TABLE (
      event_id bigint,
      stream_version bigint,
      event_type text,
      event_version integer,
      data jsonb,
      metadata jsonb,
      created_at timestamp
    ) AS $$
    BEGIN
      RETURN QUERY
      SELECT
        e.event_id,
        e.stream_version,
        e.event_type,
        e.event_version,
        e.data,
        e.metadata,
        e.created_at
      FROM events e
      WHERE e.stream_id = p_stream_id
        AND e.stream_version >= p_start_version
      ORDER BY e.stream_version ASC
      LIMIT p_count;
    END;
    $$ LANGUAGE plpgsql;
    """
  end

  defp create_subscription_functions do
    execute """
    CREATE OR REPLACE FUNCTION create_subscription(
      p_subscription_id text,
      p_stream_id text,
      p_metadata jsonb DEFAULT NULL
    ) RETURNS void AS $$
    BEGIN
      INSERT INTO subscriptions (
        subscription_id,
        stream_id,
        metadata
      )
      VALUES (
        p_subscription_id,
        p_stream_id,
        p_metadata
      )
      ON CONFLICT (subscription_id, stream_id)
      DO UPDATE SET
        updated_at = now(),
        metadata = COALESCE(p_metadata, subscriptions.metadata);
    END;
    $$ LANGUAGE plpgsql;

    CREATE OR REPLACE FUNCTION update_subscription(
      p_subscription_id text,
      p_stream_id text,
      p_last_seen_event_id bigint,
      p_last_seen_stream_version bigint
    ) RETURNS void AS $$
    BEGIN
      UPDATE subscriptions
      SET
        last_seen_event_id = p_last_seen_event_id,
        last_seen_stream_version = p_last_seen_stream_version,
        updated_at = now()
      WHERE subscription_id = p_subscription_id
        AND stream_id = p_stream_id;
    END;
    $$ LANGUAGE plpgsql;
    """
  end
end
```

## Step 4: Testing (Estimated time: 2 hours)

### 4.1 Create Test Helper
Create `test/support/event_store_case.ex`:
```elixir
defmodule GameBot.EventStoreCase do
  use ExUnit.CaseTemplate

  setup do
    :ok = GameBot.Infrastructure.EventStore.reset!()
    :ok
  end
end
```

### 4.2 Create Test Files
1. Create basic event store tests
2. Create migration tests
3. Create function tests
4. Create integration tests

## Step 5: Validation (Estimated time: 1 hour)

### 5.1 Manual Testing
```bash
# Reset and run migrations
mix event_store.reset

# Verify schema
mix event_store.status

# Run tests
mix test test/game_bot/infrastructure/event_store
```

### 5.2 Verification Checklist
- [ ] All migrations run successfully
- [ ] Schema matches specifications
- [ ] Functions work as expected
- [ ] All tests pass
- [ ] Performance is acceptable

## Total Estimated Time: 8 hours

## Next Steps After Implementation
1. Document any schema changes
2. Update event store documentation
3. Begin implementing game modes
4. Add monitoring and metrics 