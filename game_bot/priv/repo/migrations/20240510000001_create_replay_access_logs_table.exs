defmodule GameBot.Repo.Migrations.CreateReplayAccessLogsTable do
  use Ecto.Migration

  def change do
    create table(:replay_access_logs) do
      add :replay_id, references(:game_replays, column: :replay_id, type: :uuid), null: false
      add :user_id, :string, null: false
      add :guild_id, :string, null: false
      add :access_type, :string, null: false
      add :client_info, :map
      add :ip_address, :string
      add :accessed_at, :utc_datetime_usec, null: false

      timestamps()
    end

    # Indexes for common query patterns
    create index(:replay_access_logs, [:replay_id])
    create index(:replay_access_logs, [:user_id])
    create index(:replay_access_logs, [:guild_id])
    create index(:replay_access_logs, [:access_type])
    create index(:replay_access_logs, [:accessed_at])
  end
end
