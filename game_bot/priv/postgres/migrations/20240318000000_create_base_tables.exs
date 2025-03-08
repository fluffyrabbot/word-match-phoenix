defmodule GameBot.Infrastructure.Persistence.Repo.Postgres.Migrations.CreateBaseTables do
  use Ecto.Migration

  def up do
    # Create schema for game events
    execute "CREATE SCHEMA IF NOT EXISTS game_events"

    # Create base tables
    create_if_not_exists table(:projections, primary_key: false) do
      add :projection_name, :string, primary_key: true
      add :last_seen_event_number, :bigint
      add :last_updated_at, :naive_datetime_usec
      timestamps()
    end

    create_if_not_exists table(:snapshots) do
      add :source_uuid, :string, null: false
      add :source_version, :bigint, null: false
      add :source_type, :string, null: false
      add :data, :map, null: false
      add :metadata, :map, null: false
      add :created_at, :naive_datetime_usec, null: false
      timestamps()
    end

    create_if_not_exists index(:snapshots, [:source_uuid])
    create_if_not_exists index(:snapshots, [:source_type, :source_version])
  end

  def down do
    drop_if_exists table(:snapshots)
    drop_if_exists table(:projections)
    execute "DROP SCHEMA IF EXISTS game_events CASCADE"
  end
end
