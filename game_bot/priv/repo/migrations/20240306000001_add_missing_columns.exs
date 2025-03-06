defmodule GameBot.Repo.Migrations.AddMissingColumns do
  use Ecto.Migration

  def change do
    # Add missing columns to teams table
    alter table(:teams) do
      add :team_id, :string, null: false  # Discord snowflake ID
    end

    # Add missing columns to users table
    alter table(:users) do
      add :user_id, :string, null: false  # Discord snowflake ID
    end

    # Create unique constraints for new IDs
    create unique_index(:teams, [:team_id])
    create unique_index(:users, [:user_id])
  end
end
