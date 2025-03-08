defmodule GameBot.Repo.Migrations.CreateEventStoreSchema do
  use Ecto.Migration

  def up do
    # Create event store schema
    execute "CREATE SCHEMA IF NOT EXISTS event_store;"

    # Create streams table
    create_if_not_exists table(:streams, prefix: "event_store", primary_key: false) do
      add :id, :text, primary_key: true
      add :version, :bigint, null: false, default: 0
    end

    # Create events table
    create_if_not_exists table(:events, prefix: "event_store", primary_key: false) do
      add :event_id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :stream_id, references(:streams, column: :id, prefix: "event_store", type: :text, on_delete: :delete_all), null: false
      add :event_type, :text, null: false
      add :event_data, :jsonb, null: false
      add :event_metadata, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :event_version, :bigint, null: false
      add :created_at, :utc_datetime, null: false, default: fragment("now()")
    end

    # Add unique constraint to prevent concurrent issues
    create_if_not_exists unique_index(:events, [:stream_id, :event_version], prefix: "event_store")

    # Create subscriptions table
    create_if_not_exists table(:subscriptions, prefix: "event_store", primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :stream_id, references(:streams, column: :id, prefix: "event_store", type: :text, on_delete: :delete_all), null: false
      add :subscriber_pid, :text, null: false
      add :options, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :created_at, :utc_datetime, null: false, default: fragment("now()")
    end
  end

  def down do
    # Drop tables in reverse order
    drop_if_exists table(:subscriptions, prefix: "event_store")
    drop_if_exists table(:events, prefix: "event_store")
    drop_if_exists table(:streams, prefix: "event_store")

    # Drop schema
    execute "DROP SCHEMA IF EXISTS event_store CASCADE;"
  end
end
