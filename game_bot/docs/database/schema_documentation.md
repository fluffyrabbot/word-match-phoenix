# GameBot Database Schema Documentation

## Overview

This document provides a comprehensive overview of the GameBot database schema, including tables, relationships, and naming conventions. The schema is designed to support a Discord-based game bot with potential future expansion to web applications.

## Naming Conventions

The schema follows these standardized naming conventions:

1. **Primary Keys**: Default auto-incrementing integers named `id`
2. **Foreign Keys**: Named with the pattern `[entity]_id` (e.g., `user_id`, `team_id`)
3. **Discord Identifiers**: Stored as `discord_id` in the users table
4. **User References**: Consistently named `user_id` when referencing the users table
5. **Timestamps**: All tables include `inserted_at` and `updated_at` timestamps

## Tables and Relationships

### Users

The central table for user information.

| Column | Type | Description |
|--------|------|-------------|
| id | bigint | Primary key |
| discord_id | string | Discord's unique identifier for the user |
| guild_id | string | Discord guild (server) ID |
| username | string | User's Discord username |
| active | boolean | Whether the user is active |
| inserted_at | datetime | Creation timestamp |
| updated_at | datetime | Last update timestamp |

**Indexes:**
- `discord_id`: For looking up users by Discord ID
- `discord_id, guild_id` (unique): Ensures a user can only exist once per guild

### Teams

Represents teams of users who play together.

| Column | Type | Description |
|--------|------|-------------|
| id | bigint | Primary key |
| name | string | Team name |
| guild_id | string | Discord guild ID |
| active | boolean | Whether the team is active |
| score | integer | Team's cumulative score |
| inserted_at | datetime | Creation timestamp |
| updated_at | datetime | Last update timestamp |

**Indexes:**
- `guild_id`: For filtering teams by guild

### Team Members

Join table connecting users to teams.

| Column | Type | Description |
|--------|------|-------------|
| id | bigint | Primary key |
| team_id | bigint | Reference to teams table |
| user_id | bigint | Reference to users table |
| active | boolean | Whether the membership is active |
| inserted_at | datetime | Creation timestamp |
| updated_at | datetime | Last update timestamp |

**Indexes:**
- `team_id`: For finding all members of a team
- `user_id`: For finding all teams a user belongs to
- `team_id, user_id` (unique): Ensures a user can only be in a team once

### Games

Represents individual game sessions.

| Column | Type | Description |
|--------|------|-------------|
| id | bigint | Primary key |
| game_id | string | Unique identifier for the game |
| guild_id | string | Discord guild ID |
| mode | string | Game mode (e.g., "two_player", "knockout") |
| status | string | Game status (e.g., "created", "active", "completed") |
| created_by_user_id | bigint | Reference to the user who created the game |
| created_at | datetime | When the game was created |
| started_at | datetime | When the game started |
| finished_at | datetime | When the game finished |
| winner_team_id | bigint | Reference to the winning team |
| inserted_at | datetime | Creation timestamp |
| updated_at | datetime | Last update timestamp |

**Indexes:**
- `game_id` (unique): For looking up games by their unique identifier
- `guild_id`: For filtering games by guild
- `status`: For filtering games by status
- `created_by_user_id`: For finding games created by a specific user

### Game Rounds

Represents rounds within a game.

| Column | Type | Description |
|--------|------|-------------|
| id | bigint | Primary key |
| game_id | bigint | Reference to games table |
| guild_id | string | Discord guild ID |
| round_number | integer | Sequential round number within the game |
| status | string | Round status (e.g., "active", "completed") |
| started_at | datetime | When the round started |
| finished_at | datetime | When the round finished |
| inserted_at | datetime | Creation timestamp |
| updated_at | datetime | Last update timestamp |

**Indexes:**
- `game_id`: For finding all rounds in a game
- `game_id, round_number` (unique): For looking up specific rounds within a game

### Game Configs

Stores configuration settings for different game modes.

| Column | Type | Description |
|--------|------|-------------|
| id | bigint | Primary key |
| guild_id | string | Discord guild ID |
| mode | string | Game mode |
| config | map | JSON configuration data |
| created_by_user_id | bigint | Reference to the user who created the config |
| active | boolean | Whether the config is active |
| inserted_at | datetime | Creation timestamp |
| updated_at | datetime | Last update timestamp |

**Indexes:**
- `guild_id`: For finding all configs for a guild
- `created_by_user_id`: For finding configs created by a specific user
- `guild_id, mode` (unique): For looking up specific mode configs for a guild

### Player Stats

Stores statistics for individual players.

| Column | Type | Description |
|--------|------|-------------|
| id | bigint | Primary key |
| user_id | bigint | Reference to users table |
| guild_id | string | Discord guild ID |
| games_played | integer | Number of games played |
| games_won | integer | Number of games won |
| total_score | integer | Cumulative score |
| average_score | float | Average score per game |
| best_score | integer | Highest score achieved |
| total_guesses | integer | Total number of guesses made |
| correct_guesses | integer | Number of correct guesses |
| guess_accuracy | float | Percentage of correct guesses |
| total_matches | integer | Total number of matches played |
| best_match_score | integer | Highest match score achieved |
| match_percentage | float | Match success percentage |
| last_played_at | datetime | When the player last played |
| inserted_at | datetime | Creation timestamp |
| updated_at | datetime | Last update timestamp |

**Indexes:**
- `user_id`: For looking up stats for a specific user
- `user_id, guild_id` (unique): For looking up specific user stats in a guild

### Round Stats

Stores statistics for individual rounds.

| Column | Type | Description |
|--------|------|-------------|
| id | bigint | Primary key |
| game_id | bigint | Reference to games table |
| guild_id | string | Discord guild ID |
| round_number | integer | Round number within the game |
| team_id | bigint | Reference to teams table |
| total_guesses | integer | Total number of guesses in the round |
| correct_guesses | integer | Number of correct guesses |
| guess_accuracy | float | Percentage of correct guesses |
| best_match_score | integer | Highest match score in the round |
| average_match_score | float | Average match score |
| round_duration | integer | Duration of the round in milliseconds |
| started_at | datetime | When the round started |
| finished_at | datetime | When the round finished |
| inserted_at | datetime | Creation timestamp |
| updated_at | datetime | Last update timestamp |

**Indexes:**
- `game_id`: For finding all round stats for a game
- `team_id`: For finding all round stats for a team
- `game_id, round_number, team_id` (unique): For looking up specific round stats

### Guesses

Stores individual guess events for replay functionality.

| Column | Type | Description |
|--------|------|-------------|
| id | bigint | Primary key |
| game_id | bigint | Reference to games table |
| round_id | bigint | Reference to game_rounds table |
| guild_id | string | Discord guild ID |
| team_id | bigint | Reference to teams table |
| player1_user_id | bigint | Reference to first player |
| player2_user_id | bigint | Reference to second player |
| player1_word | string | Word provided by player 1 |
| player2_word | string | Word provided by player 2 |
| successful | boolean | Whether the guess was successful |
| match_score | integer | Score for this guess |
| guess_number | integer | Sequential number within game |
| round_guess_number | integer | Sequential number within round |
| guess_duration | integer | Time taken in milliseconds |
| player1_duration | integer | Time taken by player 1 |
| player2_duration | integer | Time taken by player 2 |
| event_id | uuid | Reference to the original event in event store |
| inserted_at | datetime | Creation timestamp |
| updated_at | datetime | Last update timestamp |

**Indexes:**
- `team_id`: For finding all guesses for a team
- `player1_user_id, player2_user_id`: For finding guesses by player pair
- `event_id`: For linking guesses to events in the event store
- `game_id, round_id, guess_number`: For the replay system to efficiently retrieve guesses in order

### Game Replays

Stores game replay data for later viewing and analysis.

| Column | Type | Description |
|--------|------|-------------|
| replay_id | uuid | Primary key |
| game_id | string | Reference to games table (game_id column) |
| display_name | string | User-friendly name for the replay |
| mode | string | Game mode of the replay |
| guild_id | string | Discord guild ID |
| start_time | datetime | When the game started |
| end_time | datetime | When the game ended |
| event_count | integer | Number of events in the replay |
| base_stats | map | Basic statistics about the game |
| mode_stats | map | Mode-specific statistics |
| version_map | map | Version information for compatibility |
| created_at | datetime | When the replay was created |
| inserted_at | datetime | Creation timestamp |
| updated_at | datetime | Last update timestamp |

**Indexes:**
- `game_id`: For finding replays for a specific game
- `display_name` (unique): For looking up replays by name
- `mode`: For filtering replays by game mode
- `guild_id`: For filtering replays by guild
- `created_at`: For sorting replays by creation time

### Replay Access Logs

Tracks access to game replays for analytics and security.

| Column | Type | Description |
|--------|------|-------------|
| id | bigint | Primary key |
| replay_id | uuid | Reference to game_replays table |
| user_id | bigint | Reference to users table |
| guild_id | string | Discord guild ID |
| access_type | string | Type of access (e.g., "view", "download") |
| client_info | map | Information about the client |
| ip_address | string | IP address of the client |
| accessed_at | datetime | When the replay was accessed |
| inserted_at | datetime | Creation timestamp |
| updated_at | datetime | Last update timestamp |

**Indexes:**
- `replay_id`: For finding all access logs for a replay
- `user_id`: For finding all replays accessed by a user
- `guild_id`: For filtering access logs by guild
- `access_type`: For filtering by access type
- `accessed_at`: For sorting access logs by time

### Team Invitations

Manages invitations to join teams.

| Column | Type | Description |
|--------|------|-------------|
| id | bigint | Primary key |
| team_id | bigint | Reference to teams table |
| guild_id | string | Discord guild ID |
| invited_user_id | bigint | Reference to the invited user |
| inviter_user_id | bigint | Reference to the user who sent the invitation |
| status | string | Invitation status (e.g., "pending", "accepted", "rejected") |
| expires_at | datetime | When the invitation expires |
| inserted_at | datetime | Creation timestamp |
| updated_at | datetime | Last update timestamp |

**Indexes:**
- `team_id`: For finding all invitations for a team
- `invited_user_id`: For finding all invitations for a user
- `inviter_user_id`: For finding all invitations sent by a user
- `team_id, invited_user_id` (unique): For looking up specific invitations

## Event Store

The event store is implemented in a separate schema and follows the Event Sourcing pattern.

### Streams

Represents event streams.

| Column | Type | Description |
|--------|------|-------------|
| id | text | Primary key, stream identifier |
| version | bigint | Current version of the stream |

### Events

Stores individual events.

| Column | Type | Description |
|--------|------|-------------|
| event_id | uuid | Primary key |
| stream_id | text | Reference to streams table |
| event_type | text | Type of event |
| event_data | jsonb | Event payload |
| event_metadata | jsonb | Event metadata |
| event_version | bigint | Sequential version within the stream |
| created_at | datetime | When the event was created |

**Indexes:**
- `stream_id, event_version` (unique): For retrieving events in order for a specific stream

### Subscriptions

Manages subscriptions to event streams.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| stream_id | text | Reference to streams table |
| subscriber_pid | text | Process ID of the subscriber |
| options | jsonb | Subscription options |
| created_at | datetime | When the subscription was created |

## Future Extensibility

The schema is designed to support future extensions:

1. **Web Application Users**: The users table can be extended with additional authentication methods
2. **Additional Game Modes**: The flexible game_configs table allows for new game modes
3. **Analytics**: The comprehensive stats tables enable detailed analytics
4. **Replay System**: The game_replays and replay_access_logs tables support a full replay system

## Index Optimization

The schema has been optimized by removing low-utility indexes:
- Removed redundant guild_id indexes with low selectivity
- Removed the boolean successful index on guesses
- Consolidated redundant indexes where a composite index provides the same functionality

This optimization reduces database size and improves write performance while maintaining query efficiency for common access patterns. 