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
