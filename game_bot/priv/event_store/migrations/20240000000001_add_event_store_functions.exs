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
