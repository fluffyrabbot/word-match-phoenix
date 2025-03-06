defmodule GameBot.Repo.Migrations.CreateAdditionalTables do
  use Ecto.Migration

  def change do
    # Game participants table
    create table(:game_participants) do
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :guild_id, :string, null: false
      add :active, :boolean, default: true

      timestamps()
    end

    # Team invitations table
    create table(:team_invitations) do
      add :invitation_id, :string, null: false
      add :guild_id, :string, null: false
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :inviter_id, references(:users, on_delete: :delete_all), null: false
      add :invitee_id, references(:users, on_delete: :delete_all), null: false
      add :status, :string, default: "pending"
      add :expires_at, :utc_datetime

      timestamps()
    end

    # User preferences table
    create table(:user_preferences) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :guild_id, :string, null: false
      add :preferences, :map, default: %{}

      timestamps()
    end

    # Add basic indexes for the new tables
    create index(:game_participants, [:game_id])
    create index(:game_participants, [:user_id])
    create unique_index(:team_invitations, [:invitation_id])
    create index(:team_invitations, [:team_id])
    create index(:team_invitations, [:inviter_id])
    create index(:team_invitations, [:invitee_id])
    create unique_index(:user_preferences, [:user_id, :guild_id])
  end
end
