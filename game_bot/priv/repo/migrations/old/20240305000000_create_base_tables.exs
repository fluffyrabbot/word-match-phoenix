defmodule GameBot.Infrastructure.Repo.Migrations.CreateBaseTables do
  use Ecto.Migration

  def change do
    # Teams table
    create table(:teams) do
      add :name, :string, null: false
      add :guild_id, :string, null: false
      add :active, :boolean, default: true
      add :score, :integer, default: 0

      timestamps()
    end

    create index(:teams, [:guild_id])

    # Users table
    create table(:users) do
      add :discord_id, :string, null: false
      add :guild_id, :string, null: false
      add :username, :string
      add :active, :boolean, default: true

      timestamps()
    end

    create index(:users, [:discord_id])
    create index(:users, [:guild_id])

    # Team memberships (join table)
    create table(:team_members) do
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :active, :boolean, default: true

      timestamps()
    end

    create index(:team_members, [:team_id])
    create index(:team_members, [:user_id])
    create unique_index(:team_members, [:team_id, :user_id])

    # Games table
    create table(:games) do
      add :game_id, :string, null: false
      add :guild_id, :string, null: false
      add :mode, :string, null: false
      add :status, :string, default: "created"
      add :created_by, :string
      add :created_at, :utc_datetime
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime
      add :winner_team_id, references(:teams, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:games, [:game_id])
    create index(:games, [:guild_id])
    create index(:games, [:status])

    # Game rounds
    create table(:game_rounds) do
      add :game_id, references(:games, column: :id, type: :bigint, on_delete: :delete_all), null: false
      add :round_number, :integer, null: false
      add :status, :string, default: "active"
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime

      timestamps()
    end

    create index(:game_rounds, [:game_id])
    create unique_index(:game_rounds, [:game_id, :round_number])
  end
end
