defmodule GameBot.Infrastructure.Repo.Migrations.SquashedMigrations do
  use Ecto.Migration

  def change do
    # First, drop the tables if they exist (for clean reset)
    execute "DROP TABLE IF EXISTS team_members CASCADE"
    execute "DROP TABLE IF EXISTS game_rounds CASCADE"
    execute "DROP TABLE IF EXISTS games CASCADE"
    execute "DROP TABLE IF EXISTS teams CASCADE"
    execute "DROP TABLE IF EXISTS users CASCADE"
    execute "DROP TABLE IF EXISTS game_configs CASCADE"
    execute "DROP TABLE IF EXISTS player_stats CASCADE"
    execute "DROP TABLE IF EXISTS round_stats CASCADE"
    execute "DROP TABLE IF EXISTS guesses CASCADE"
    execute "DROP TABLE IF EXISTS team_invitations CASCADE"
    execute "DROP SCHEMA IF EXISTS event_store CASCADE"

    # Create event store schema
    execute "CREATE SCHEMA IF NOT EXISTS event_store"

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
      add :guild_id, :string, null: false
      add :round_number, :integer, null: false
      add :status, :string, default: "active"
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime

      timestamps()
    end

    create index(:game_rounds, [:game_id])
    create index(:game_rounds, [:guild_id])
    create unique_index(:game_rounds, [:game_id, :round_number])

    # Game configs
    create table(:game_configs) do
      add :guild_id, :string, null: false
      add :mode, :string, null: false
      add :config, :map, null: false
      add :created_by, :string
      add :active, :boolean, default: true

      timestamps()
    end

    create index(:game_configs, [:guild_id])
    create unique_index(:game_configs, [:guild_id, :mode])


    # Player stats
    create table(:player_stats) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :guild_id, :string, null: false
      add :games_played, :integer, default: 0
      add :games_won, :integer, default: 0
      add :total_score, :integer, default: 0
      add :average_score, :float, default: 0.0
      add :best_score, :integer, default: 0
      add :total_guesses, :integer, default: 0
      add :correct_guesses, :integer, default: 0
      add :guess_accuracy, :float, default: 0.0
      add :total_matches, :integer, default: 0
      add :best_match_score, :integer, default: 0
      add :match_percentage, :float, default: 0.0
      add :last_played_at, :utc_datetime

      timestamps()
    end

    create index(:player_stats, [:user_id])
    create index(:player_stats, [:guild_id])
    create unique_index(:player_stats, [:user_id, :guild_id])

    # Round stats
    create table(:round_stats) do
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :guild_id, :string, null: false
      add :round_number, :integer, null: false
      add :team_id, references(:teams, on_delete: :nilify_all)
      add :total_guesses, :integer, default: 0
      add :correct_guesses, :integer, default: 0
      add :guess_accuracy, :float, default: 0.0
      add :best_match_score, :integer, default: 0
      add :average_match_score, :float, default: 0.0
      add :round_duration, :integer
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime

      timestamps()
    end

    create index(:round_stats, [:game_id])
    create index(:round_stats, [:guild_id])
    create index(:round_stats, [:team_id])
    create unique_index(:round_stats, [:game_id, :round_number, :team_id])

    # Guesses table to store individual guess events for replay functionality
    create table(:guesses) do
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :round_id, references(:game_rounds, on_delete: :delete_all), null: false
      add :guild_id, :string, null: false
      add :team_id, references(:teams, on_delete: :nilify_all), null: false
      add :player1_id, references(:users, on_delete: :nilify_all), null: false
      add :player2_id, references(:users, on_delete: :nilify_all), null: false
      add :player1_word, :string, null: false
      add :player2_word, :string, null: false
      add :successful, :boolean, null: false
      add :match_score, :integer
      add :guess_number, :integer, null: false  # Sequential number within game
      add :round_guess_number, :integer, null: false  # Sequential number within round
      add :guess_duration, :integer  # Time taken in milliseconds
      add :player1_duration, :integer  # Time taken by player 1 in milliseconds
      add :player2_duration, :integer  # Time taken by player 2 in milliseconds
      add :event_id, :uuid  # Reference to the original event in event store

      timestamps()
    end

    create index(:guesses, [:game_id])
    create index(:guesses, [:round_id])
    create index(:guesses, [:guild_id])
    create index(:guesses, [:team_id])
    create index(:guesses, [:player1_id, :player2_id])
    create index(:guesses, [:successful])
    create index(:guesses, [:event_id])

    # Team invitations
    create table(:team_invitations) do
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :guild_id, :string, null: false
      add :invited_user_id, references(:users, on_delete: :delete_all), null: false
      add :invited_by_id, references(:users, on_delete: :nilify_all)
      add :status, :string, default: "pending"
      add :expires_at, :utc_datetime

      timestamps()
    end

    create index(:team_invitations, [:team_id])
    create index(:team_invitations, [:guild_id])
    create index(:team_invitations, [:invited_user_id])
    create unique_index(:team_invitations, [:team_id, :invited_user_id])

    # Create event store tables
    create table(:streams, prefix: "event_store", primary_key: false) do
      add :id, :text, primary_key: true
      add :version, :bigint, null: false, default: 0
    end

    create table(:events, prefix: "event_store", primary_key: false) do
      add :event_id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :stream_id, references(:streams, column: :id, prefix: "event_store", type: :text, on_delete: :delete_all), null: false
      add :event_type, :text, null: false
      add :event_data, :jsonb, null: false
      add :event_metadata, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :event_version, :bigint, null: false
      add :created_at, :utc_datetime, null: false, default: fragment("now()")
    end

    create unique_index(:events, [:stream_id, :event_version], prefix: "event_store")

    create table(:subscriptions, prefix: "event_store", primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :stream_id, references(:streams, column: :id, prefix: "event_store", type: :text, on_delete: :delete_all), null: false
      add :subscriber_pid, :text, null: false
      add :options, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :created_at, :utc_datetime, null: false, default: fragment("now()")
    end
  end
end
