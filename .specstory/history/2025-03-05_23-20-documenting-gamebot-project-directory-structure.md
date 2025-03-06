## SpecStory

## Documenting GameBot Project Directory Structure (3/5/2025, 11:20:06 PM)

_**User**_

@game_bot can you document this project directory structure in as concise a way as possible to feed as ai guidance to help it locate files

---

_**Assistant**_

# GameBot Project Directory Structure

Here's a concise overview of the project directory structure:

```
game_bot/
├── .formatter.exs          # Elixir code formatting rules
├── .gitattributes          # Git line ending configuration (LF normalization)
├── .gitignore              # Standard Elixir project gitignore
├── config/                 # Configuration files
│   ├── config.exs          # Main application config
│   ├── dev.exs             # Development environment config
│   ├── prod.exs            # Production environment config
│   ├── runtime.exs         # Runtime configuration
│   ├── test.exs            # Test environment config
│   └── test_event_store.exs # Event store test configuration
├── deps/                   # Dependencies (managed by Mix)
│   ├── backoff/            # Exponential backoff library
│   ├── bandit/             # HTTP server for Plug & WebSock apps
│   └── ...                 # Other dependencies
├── lib/                    # Main application code
│   └── game_bot/           # Core application logic
│       ├── bot/            # Discord bot integration
│       │   ├── commands/   # Command implementations
│       │   ├── dispatcher.ex # Routes Discord events
│       │   └── listener.ex # Listens for Discord events
│       ├── domain/         # Core business logic
│       │   ├── aggregates/ # Aggregate roots
│       │   ├── commands/   # Command definitions and validation
│       │   └── events/     # Event definitions
│       ├── game_sessions/  # Game session management (GenServers)
│       │   ├── cleanup.ex  # Periodic cleanup of completed sessions
│       │   ├── session.ex  # Individual game session GenServer
│       │   └── supervisor.ex # Dynamic supervisor for sessions
│       └── infrastructure/ # Persistence and external services
│           ├── repo.ex     # Database repository
│           └── event_store/ # Event sourcing implementation
└── test/                   # Test files
```

## Key Architectural Components:

1. **Bot Layer**: Discord integration using Nostrum
2. **Domain Layer**: Game logic with CQRS and event sourcing
3. **Game Sessions**: GenServer-based game state management
4. **Infrastructure**: Persistence with EventStore

The project follows a functional design with clear module boundaries, using GenServers for stateful game sessions and event sourcing for persistence.

---

_**User**_

@20240305000000_create_base_tables.exs @20240306000001_add_missing_columns.exs @20240306000002_create_additional_tables.exs @20240306000003_add_guild_id_to_game_rounds.exs @20240306000004_add_guild_id_indexes_corrected.exs can these migrations be safely squashed

---

_**Assistant**_

# Migration Squashing Analysis

Yes, these migrations can be safely squashed into a single migration file since:

1. They appear to be sequential and related
2. They're all creating the initial database schema
3. There's no evidence of the migrations being deployed to production yet
4. The changes are additive rather than transformative

Here's how you could squash them:

```elixir:game_bot/priv/repo/migrations/20240305000000_create_initial_schema.exs
defmodule GameBot.Infrastructure.Repo.Migrations.CreateInitialSchema do
  use Ecto.Migration

  def change do
    # Teams table
    create table(:teams) do
      add :name, :string, null: false
      add :guild_id, :string, null: false
      add :team_id, :string, null: false  # Discord snowflake ID
      add :active, :boolean, default: true
      add :score, :integer, default: 0

      timestamps()
    end

    create index(:teams, [:guild_id])
    create unique_index(:teams, [:team_id])
    create index(:teams, [:guild_id, :team_id], unique: true)

    # Users table
    create table(:users) do
      add :discord_id, :string, null: false
      add :guild_id, :string, null: false
      add :user_id, :string, null: false  # Discord snowflake ID
      add :username, :string
      add :active, :boolean, default: true

      timestamps()
    end

    create index(:users, [:discord_id])
    create index(:users, [:guild_id])
    create unique_index(:users, [:user_id])
    create index(:users, [:guild_id, :user_id], unique: true)
    create index(:users, [:user_id, :guild_id], unique: true)

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
    create index(:games, [:guild_id, :game_id], unique: true)
    create index(:games, [:guild_id, :status])
    create index(:games, [:guild_id, :created_at])

    # Game rounds
    create table(:game_rounds) do
      add :game_id, references(:games, column: :id, type: :bigint, on_delete: :delete_all), null: false
      add :round_number, :integer, null: false
      add :status, :string, default: "active"
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime
      add :guild_id, :string, null: false

      timestamps()
    end

    create index(:game_rounds, [:game_id])
    create unique_index(:game_rounds, [:game_id, :round_number])
    create index(:game_rounds, [:guild_id, :game_id])
    create index(:game_rounds, [:guild_id, :game_id, :round_number], unique: true)

    # Game participants table
    create table(:game_participants) do
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :guild_id, :string, null: false
      add :active, :boolean, default: true

      timestamps()
    end

    create index(:game_participants, [:game_id])
    create index(:game_participants, [:user_id])
    create index(:game_participants, [:guild_id])
    create index(:game_participants, [:guild_id, :user_id])
    create index(:game_participants, [:guild_id, :game_id])

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

    create unique_index(:team_invitations, [:invitation_id])
    create index(:team_invitations, [:team_id])
    create index(:team_invitations, [:inviter_id])
    create index(:team_invitations, [:invitee_id])
    create index(:team_invitations, [:guild_id])
    create index(:team_invitations, [:guild_id, :invitation_id], unique: true)
    create index(:team_invitations, [:guild_id, :invitee_id])
    create index(:team_invitations, [:guild_id, :inviter_id])

    # User preferences table
    create table(:user_preferences) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :guild_id, :string, null: false
      add :preferences, :map, default: %{}

      timestamps()
    end

    create unique_index(:user_preferences, [:user_id, :guild_id])
    create index(:user_preferences, [:guild_id])
    create index(:user_preferences, [:guild_id, :user_id], unique: true)
  end
end
```

## Implementation Steps

To safely squash these migrations:

1. Create the new consolidated migration file as shown above
2. Delete the original migration files
3. If the database has already been created in development:
   - Drop and recreate the database with `mix ecto.reset`
   - Or, if you want to preserve data, make sure all migrations have been run first

## Benefits of Squashing

1. **Simplified Schema Management**: A single file makes it easier to understand the complete database structure
2. **Faster Setup**: New developers will run a single migration instead of five
3. **Cleaner Migration History**: Removes intermediate steps that aren't needed
4. **Reduced Complexity**: Eliminates potential issues with migration ordering

Since these appear to be initial migrations that haven't been deployed to production yet, squashing them now will save future maintenance effort.

---



---

