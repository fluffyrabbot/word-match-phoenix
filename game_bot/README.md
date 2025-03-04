# GameBot

A Discord bot for playing word games with your server members, built with Elixir, Phoenix, and Nostrum.

## Architecture

GameBot follows an event-sourced, domain-driven design with clean separation of concerns:

- **Bot Module**: Handles Discord interactions using Nostrum
- **Domain Module**: Implements game logic and rules
- **Infrastructure Module**: Manages persistence and caching
- **Web Module**: Optional Phoenix web interface

## Features

- Multiple game modes:
  - Two Player Mode
  - Knockout Mode
  - Race Mode
  - Golf Race Mode
  - Longform Mode
- Player statistics and leaderboards
- Event sourcing for game history

## Prerequisites

- Elixir 1.14+
- PostgreSQL 13+
- Discord Bot Token

## Getting Started

1. Clone the repository
2. Install dependencies with `mix deps.get`
3. Create and migrate your database with `mix ecto.setup`
4. Configure your Discord bot token in `config/dev.exs`
5. Start the application with `mix phx.server`

## Configuration

Set your Discord Bot Token in `config/dev.exs`:

```elixir
config :nostrum,
  token: "YOUR_DISCORD_BOT_TOKEN"
```

## Project Structure

```
project-root/                             # Root directory of the project
├── config/                               # Configuration files for different environments
│   ├── config.exs                        # General application configuration (including Ecto settings)
│   ├── dev.exs                           # Development-specific configuration (DB credentials, logging, etc.)
│   ├── prod.exs                          # Production-specific configuration (optimized settings, secrets, etc.)
│   └── test.exs                          # Test environment configuration (for running tests)
├── lib/                                  # Main source code directory
│   └── game_bot/                         # Main application namespace for the Discord game bot
│       ├── application.ex                # Application startup module and supervision tree definition
│       ├── bot/                          # Discord bot integration layer
│       │   ├── dispatcher.ex             # Routes incoming Discord events to appropriate handlers
│       │   ├── command_handler.ex        # Processes Discord commands issued by users
│       │   └── listener.ex               # Listens for Discord events (e.g., using Nostrum)
│       ├── domain/                       # Core business logic and domain models (DDD, event sourcing)
│       │   ├── game_modes/               # Modules for different game modes implementations
│       │   │   ├── base_mode.ex          # Base module defining shared functionality for game modes
│       │   │   ├── two_player_mode.ex    # Implementation of two-player game mode logic
│       │   │   ├── knockout_mode.ex      # Implementation of knockout game mode logic
│       │   │   ├── race_mode.ex          # Implementation of race game mode logic
│       │   │   ├── golf_race_mode.ex     # Implementation of golf race mode logic
│       │   │   └── longform_mode.ex      # Implementation of longform game mode logic
│       │   ├── command.ex                # Definitions for game commands used across the domain
│       │   ├── event.ex                  # Immutable event definitions for event sourcing
│       │   ├── projection.ex             # Projections (read models) for stats, history, etc.
│       │   ├── replay/                   # Domain logic related to game replays
│       │   │   ├── formation.ex          # Business logic for forming replays from event streams
│       │   │   ├── retrieval.ex          # Domain-level logic for retrieving replay data
│       │   │   └── display.ex            # Logic to format replay data for presentation
│       │   ├── user_stats/               # Domain logic for user statistics
│       │   │   ├── updater.ex            # Business logic for computing and updating user stats
│       │   │   ├── retrieval.ex          # Domain-level logic for fetching user stats
│       │   │   └── display.ex            # Logic to format user stats for display purposes
│       │   └── team/                     # Domain logic related to teams
│       │       ├── formation.ex          # Logic for team formation and membership management
│       │       ├── identity.ex           # Logic for managing team identity (names, logos, etc.)
│       │       ├── stats.ex              # Aggregation and computation of team performance data
│       │       ├── retrieval.ex          # Domain-level logic for fetching team data
│       │       └── display.ex            # Logic to format team data for presentation purposes
│       ├── infrastructure/               # Infrastructure layer for external integrations and persistence
│       │   ├── repo.ex                   # Central Ecto repository for database access (GameBot.Repo)
│       │   ├── persistence/              # Centralized persistence contexts for domain data
│       │   │   ├── replay_context.ex     # Persistence functions for replays (CRUD, queries)
│       │   │   ├── user_stats_context.ex # Persistence functions for user stats (CRUD, queries)
│       │   │   └── team_context.ex       # Persistence functions for team data (CRUD, queries)
│       │   ├── postgres/                 # PostgreSQL-specific persistence layer using Ecto
│       │   │   ├── models/               # Ecto schemas for persistent entities
│       │   │   │   ├── game_session.ex   # Schema for game session data
│       │   │   │   ├── user.ex           # Schema for user data (includes user stats fields)
│       │   │   │   ├── team.ex           # Schema for team data (formation, identity, stats)
│       │   │   │   └── replay.ex         # Schema for replay data
│       │   │   ├── queries.ex            # Shared query functions (if additional common queries are needed)
│       │   │   └── migrations/           # Database migration scripts for schema evolution
│       │   └── cache.ex                  # Caching layer implementation (e.g., using ETS)
│       └── web/                          # Optional: Phoenix web interface and real-time channels
│           ├── endpoint.ex               # Phoenix endpoint definition (web server setup)
│           ├── channels/                 # Real-time channels for WebSocket communication (if used)
│           ├── controllers/              # Controllers handling HTTP requests for data retrieval/display
│           │   ├── replay_controller.ex  # Controller for replay-related API endpoints
│           │   ├── user_stats_controller.ex  # Controller for user stats API endpoints
│           │   └── team_controller.ex    # Controller for team data API endpoints
│           ├── views/                    # View modules to render data (typically in JSON or HTML)
│           │   ├── replay_view.ex        # View for formatting replay data for web responses
│           │   ├── user_stats_view.ex    # View for formatting user stats for web responses
│           │   └── team_view.ex          # View for formatting team data for web responses
│           └── templates/                # HTML templates for the web interface (if used)
│               ├── replay/               # Templates related to replay pages
│               │   └── index.html.eex    # Template for replay index or listing page
│               ├── user_stats/           # Templates related to user stats pages
│               │   └── index.html.eex    # Template for user stats index or listing page
│               └── team/                 # Templates related to team pages
│                   └── index.html.eex    # Template for team index or listing page
├── priv/                                 # Private files that are not part of the source code
│   ├── repo/                           # Repository-related files
│   │   ├── migrations/                # Ecto migration scripts to set up and update the database schema
│   │   └── seeds.exs                  # Script for seeding the database with initial data
│   └── static/                         # Static assets for the web interface (CSS, JavaScript, images)
├── test/                                 # Test directory containing all test suites
│   ├── bot/                           # Tests for Discord bot functionality
│   ├── domain/                        # Tests for core domain logic (game modes, replays, user stats, team)
│   │   ├── replay_test.exs            # Test cases for replay domain logic
│   │   ├── user_stats_test.exs        # Test cases for user stats logic
│   │   └── team_test.exs              # Test cases for team domain logic
│   ├── infrastructure/                # Tests for the persistence layer and external integrations
│   └── web/                           # Tests for web controllers, views, and templates (if applicable)
├── mix.exs                             # Mix project file (defines project dependencies and configuration)
├── mix.lock                            # Dependency lock file (ensures consistent builds)
└── README.md                           # Project overview, documentation, and setup instructions
```

## Game Commands

- `!start [game_mode]` - Start a new game (default: two_player)
- `!join` - Join an existing game
- `!answer [word]` - Submit an answer
- `!stats` - View your statistics
- `!leaderboard` - View server leaderboard
- `!help` - Show available commands

## Development

- Run tests with `mix test`
- Format code with `mix format`
- Run static analysis with `mix credo`

## License

This project is licensed under the MIT License - see the LICENSE file for details.
