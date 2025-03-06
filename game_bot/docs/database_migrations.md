# Database Migrations Documentation

## Overview

The database schema is designed to support a Discord-based word game with teams, users, and game sessions. The schema uses PostgreSQL and follows event sourcing principles for game state management.

## Base Tables (20240305000000)

### Teams
- Primary table for team management
- Fields:
  - `id`: bigint (primary key)
  - `name`: string (required)
  - `guild_id`: string (required) - Discord server ID
  - `active`: boolean (default: true)
  - `score`: integer (default: 0)
  - timestamps
- Indexes:
  - `teams_guild_id_index`: Simple index on guild_id

### Users
- Stores Discord user information
- Fields:
  - `id`: bigint (primary key)
  - `discord_id`: string (required) - Discord user ID
  - `guild_id`: string (required) - Discord server ID
  - `username`: string (optional)
  - `active`: boolean (default: true)
  - timestamps
- Indexes:
  - `users_discord_id_index`: Simple index on discord_id
  - `users_guild_id_index`: Simple index on guild_id

### Team Members
- Join table for team-user relationships
- Fields:
  - `id`: bigint (primary key)
  - `team_id`: bigint (required, foreign key to teams)
  - `user_id`: bigint (required, foreign key to users)
  - `active`: boolean (default: true)
  - timestamps
- Indexes:
  - `team_members_team_id_index`: Simple index on team_id
  - `team_members_user_id_index`: Simple index on user_id
  - `team_members_team_id_user_id_index`: Unique compound index

### Games
- Core table for game sessions
- Fields:
  - `id`: bigint (primary key)
  - `game_id`: string (required) - Unique game identifier
  - `guild_id`: string (required) - Discord server ID
  - `mode`: string (required) - Game mode type
  - `status`: string (default: "created")
  - `created_by`: string
  - `created_at`: utc_datetime
  - `started_at`: utc_datetime
  - `finished_at`: utc_datetime
  - `winner_team_id`: bigint (foreign key to teams, nullable)
  - timestamps
- Indexes:
  - `games_game_id_index`: Unique index on game_id
  - `games_guild_id_index`: Simple index on guild_id
  - `games_status_index`: Simple index on status

### Game Rounds
- Tracks individual rounds within games
- Fields:
  - `id`: bigint (primary key)
  - `game_id`: bigint (required, foreign key to games)
  - `round_number`: integer (required)
  - `status`: string (default: "active")
  - `started_at`: utc_datetime
  - `finished_at`: utc_datetime
  - timestamps
- Indexes:
  - `game_rounds_game_id_index`: Simple index on game_id
  - `game_rounds_game_id_round_number_index`: Unique compound index

## Additional Columns (20240306000001)

### Teams Additional Columns
- Added:
  - `team_id`: string (required) - Discord snowflake ID
- New Indexes:
  - `teams_team_id_index`: Unique index on team_id

### Users Additional Columns
- Added:
  - `user_id`: string (required) - Discord snowflake ID
- New Indexes:
  - `users_user_id_index`: Unique index on user_id

## Additional Tables (20240306000002)

### Game Participants
- Tracks active participants in games
- Fields:
  - `id`: bigint (primary key)
  - `game_id`: bigint (required, foreign key to games)
  - `user_id`: bigint (required, foreign key to users)
  - `guild_id`: string (required)
  - `active`: boolean (default: true)
  - timestamps
- Indexes:
  - `game_participants_game_id_index`: Simple index on game_id
  - `game_participants_user_id_index`: Simple index on user_id

### Team Invitations
- Manages team invitation system
- Fields:
  - `id`: bigint (primary key)
  - `invitation_id`: string (required)
  - `guild_id`: string (required)
  - `team_id`: bigint (required, foreign key to teams)
  - `inviter_id`: bigint (required, foreign key to users)
  - `invitee_id`: bigint (required, foreign key to users)
  - `status`: string (default: "pending")
  - `expires_at`: utc_datetime
  - timestamps
- Indexes:
  - `team_invitations_invitation_id_index`: Unique index on invitation_id
  - `team_invitations_team_id_index`: Simple index on team_id
  - `team_invitations_inviter_id_index`: Simple index on inviter_id
  - `team_invitations_invitee_id_index`: Simple index on invitee_id

### User Preferences
- Stores user-specific settings
- Fields:
  - `id`: bigint (primary key)
  - `user_id`: bigint (required, foreign key to users)
  - `guild_id`: string (required)
  - `preferences`: map (default: {})
  - timestamps
- Indexes:
  - `user_preferences_user_id_guild_id_index`: Unique compound index

## Game Rounds Guild ID (20240306000003)

### Game Rounds Additional Columns
- Added:
  - `guild_id`: string (required) - Discord server ID

## Guild ID Indexes (20240306000004)

Added compound indexes for efficient guild-based queries:

### Teams
- `teams_guild_id_team_id_index`: Unique compound index

### Users
- `users_guild_id_user_id_index`: Unique compound index
- `users_user_id_guild_id_index`: Unique compound index

### Games
- `games_guild_id_game_id_index`: Unique compound index
- `games_guild_id_status_index`: Compound index
- `games_guild_id_created_at_index`: Compound index

### Game Rounds
- `game_rounds_guild_id_game_id_index`: Compound index
- `game_rounds_guild_id_game_id_round_number_index`: Unique compound index

### Game Participants
- `game_participants_guild_id_index`: Simple index
- `game_participants_guild_id_user_id_index`: Compound index
- `game_participants_guild_id_game_id_index`: Compound index

### Team Invitations
- `team_invitations_guild_id_index`: Simple index
- `team_invitations_guild_id_invitation_id_index`: Unique compound index
- `team_invitations_guild_id_invitee_id_index`: Compound index
- `team_invitations_guild_id_inviter_id_index`: Compound index

### User Preferences
- `user_preferences_guild_id_index`: Simple index
- `user_preferences_guild_id_user_id_index`: Unique compound index

## Foreign Key Constraints

The schema enforces referential integrity through foreign key constraints:

1. `team_members.team_id` references `teams.id` (ON DELETE: CASCADE)
2. `team_members.user_id` references `users.id` (ON DELETE: CASCADE)
3. `games.winner_team_id` references `teams.id` (ON DELETE: SET NULL)
4. `game_rounds.game_id` references `games.id` (ON DELETE: CASCADE)
5. `game_participants.game_id` references `games.id` (ON DELETE: CASCADE)
6. `game_participants.user_id` references `users.id` (ON DELETE: CASCADE)
7. `team_invitations.team_id` references `teams.id` (ON DELETE: CASCADE)
8. `team_invitations.inviter_id` references `users.id` (ON DELETE: CASCADE)
9. `team_invitations.invitee_id` references `users.id` (ON DELETE: CASCADE)
10. `user_preferences.user_id` references `users.id` (ON DELETE: CASCADE)

## Query Optimization

The index strategy is optimized for:
1. Guild-based queries (all tables have guild_id indexes)
2. User lookups (by discord_id and user_id)
3. Game session queries (by game_id and status)
4. Team membership queries
5. Round tracking within games
6. Invitation management

Most queries should include guild_id to take advantage of the compound indexes. 