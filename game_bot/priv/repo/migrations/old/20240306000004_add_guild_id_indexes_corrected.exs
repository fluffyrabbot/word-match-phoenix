defmodule GameBot.Repo.Migrations.AddGuildIdIndexesCorrected do
  use Ecto.Migration

  def change do
    # Teams Table - only new compound indexes
    create index(:teams, [:guild_id, :team_id], unique: true)

    # Users Table - only new compound indexes
    create index(:users, [:guild_id, :user_id], unique: true)
    create index(:users, [:user_id, :guild_id], unique: true)

    # Games Table - only new compound indexes
    create index(:games, [:guild_id, :game_id], unique: true)
    create index(:games, [:guild_id, :status])
    create index(:games, [:guild_id, :created_at])

    # Game Rounds Table - corrected name and new indexes
    create index(:game_rounds, [:guild_id, :game_id])
    create index(:game_rounds, [:guild_id, :game_id, :round_number], unique: true)

    # Game Participants Table - new compound indexes
    create index(:game_participants, [:guild_id])
    create index(:game_participants, [:guild_id, :user_id])
    create index(:game_participants, [:guild_id, :game_id])

    # Team Invitations Table - new compound indexes
    create index(:team_invitations, [:guild_id])
    create index(:team_invitations, [:guild_id, :invitation_id], unique: true)
    create index(:team_invitations, [:guild_id, :invitee_id])
    create index(:team_invitations, [:guild_id, :inviter_id])

    # User Preferences Table - new compound indexes
    create index(:user_preferences, [:guild_id])
    create index(:user_preferences, [:guild_id, :user_id], unique: true)
  end
end
