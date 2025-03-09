defmodule GameBot.Repo.Migrations.CreateGameReplaysTable do
  use Ecto.Migration

  def change do
    create table(:game_replays, primary_key: false) do
      add :replay_id, :uuid, primary_key: true
      add :game_id, :string, null: false
      add :display_name, :string, null: false
      add :mode, :string, null: false
      add :start_time, :utc_datetime_usec, null: false
      add :end_time, :utc_datetime_usec, null: false
      add :event_count, :integer, null: false
      add :base_stats, :map, null: false
      add :mode_stats, :map, null: false
      add :version_map, :map, null: false
      add :created_at, :utc_datetime_usec, null: false

      timestamps()
    end

    # Indexes for common query patterns
    create index(:game_replays, [:game_id])
    create unique_index(:game_replays, [:display_name])
    create index(:game_replays, [:mode])
    create index(:game_replays, [:created_at])
  end
end
