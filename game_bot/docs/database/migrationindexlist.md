# Database Index Analysis

This document analyzes all indexes created in the `20240308000000_squashed_migrations.exs` migration file, evaluating their utility and providing recommendations for potential optimization.

## Index Evaluation Criteria

Each index is evaluated based on:

1. **Query Pattern Support**: How well the index supports common query patterns
2. **Selectivity**: How effectively the index narrows down results
3. **Overhead**: The storage and maintenance cost of the index
4. **Redundancy**: Whether the index duplicates functionality of other indexes
5. **Utility Rating**: Overall usefulness on a scale of:
   - **High**: Essential for performance, should be kept
   - **Medium**: Useful for some operations, consider keeping
   - **Low**: Limited utility, consider removing
   - **Redundant**: Duplicates functionality of another index, should be removed

## Teams Table Indexes

| Index | Columns | Type | Utility | Analysis |
|-------|---------|------|---------|----------|
| teams_guild_id_index | `[:guild_id]` | Standard | Medium | Useful for filtering teams by guild, but likely not highly selective if most queries also filter by other criteria. Consider keeping if you frequently query all teams in a guild. |

## Users Table Indexes

| Index | Columns | Type | Utility | Analysis |
|-------|---------|------|---------|----------|
| users_discord_id_index | `[:discord_id]` | Standard | High | Essential for looking up users by Discord ID, which is likely a very common operation. Highly selective. |
| users_guild_id_index | `[:guild_id]` | Standard | Medium | Useful for filtering users by guild, but less selective than discord_id. Keep if you frequently query all users in a guild. |

## Team Members Table Indexes

| Index | Columns | Type | Utility | Analysis |
|-------|---------|------|---------|----------|
| team_members_team_id_index | `[:team_id]` | Standard | High | Essential for finding all members of a team, which is likely a common operation. |
| team_members_user_id_index | `[:user_id]` | Standard | High | Essential for finding all teams a user belongs to. |
| team_members_team_id_user_id_index | `[:team_id, :user_id]` | Unique | High | Critical for enforcing uniqueness and for lookups by both team and user. |

## Games Table Indexes

| Index | Columns | Type | Utility | Analysis |
|-------|---------|------|---------|----------|
| games_game_id_index | `[:game_id]` | Unique | High | Essential for looking up games by their unique identifier. |
| games_guild_id_index | `[:guild_id]` | Standard | Medium | Useful for filtering games by guild. Keep if you frequently list all games in a guild. |
| games_status_index | `[:status]` | Standard | Medium | Useful for filtering games by status (e.g., active games). Keep if this is a common query pattern. |

## Game Rounds Table Indexes

| Index | Columns | Type | Utility | Analysis |
|-------|---------|------|---------|----------|
| game_rounds_game_id_index | `[:game_id]` | Standard | High | Essential for finding all rounds in a game. |
| game_rounds_guild_id_index | `[:guild_id]` | Standard | Low | Low selectivity and likely redundant with game filtering. Consider removing unless you frequently query rounds directly by guild without knowing the game. |
| game_rounds_game_id_round_number_index | `[:game_id, :round_number]` | Unique | High | Critical for enforcing uniqueness and for looking up specific rounds within a game. |

## Game Configs Table Indexes

| Index | Columns | Type | Utility | Analysis |
|-------|---------|------|---------|----------|
| game_configs_guild_id_index | `[:guild_id]` | Standard | Medium | Useful for finding all configs for a guild. |
| game_configs_guild_id_mode_index | `[:guild_id, :mode]` | Unique | High | Critical for enforcing uniqueness and for looking up specific mode configs for a guild. |

## Player Stats Table Indexes

| Index | Columns | Type | Utility | Analysis |
|-------|---------|------|---------|----------|
| player_stats_user_id_index | `[:user_id]` | Standard | High | Essential for looking up stats for a specific user. |
| player_stats_guild_id_index | `[:guild_id]` | Standard | Low | Low selectivity. Consider removing unless you frequently query all player stats for a guild. |
| player_stats_user_id_guild_id_index | `[:user_id, :guild_id]` | Unique | High | Critical for enforcing uniqueness and for looking up specific user stats in a guild. |

## Round Stats Table Indexes

| Index | Columns | Type | Utility | Analysis |
|-------|---------|------|---------|----------|
| round_stats_game_id_index | `[:game_id]` | Standard | High | Essential for finding all round stats for a game. |
| round_stats_guild_id_index | `[:guild_id]` | Standard | Low | Low selectivity and likely redundant. Consider removing unless you query round stats directly by guild without knowing the game. |
| round_stats_team_id_index | `[:team_id]` | Standard | Medium | Useful for finding all round stats for a team. Keep if this is a common query pattern. |
| round_stats_game_id_round_number_team_id_index | `[:game_id, :round_number, :team_id]` | Unique | High | Critical for enforcing uniqueness and for looking up specific round stats. |

## Guesses Table Indexes

| Index | Columns | Type | Utility | Analysis |
|-------|---------|------|---------|----------|
| guesses_game_id_index | `[:game_id]` | Standard | Medium | Partially redundant with the composite index. Consider removing if the composite index covers most query patterns. |
| guesses_round_id_index | `[:round_id]` | Standard | Medium | Partially redundant with the composite index. Consider removing if the composite index covers most query patterns. |
| guesses_guild_id_index | `[:guild_id]` | Standard | Low | Low selectivity and likely redundant. Consider removing unless you query guesses directly by guild without knowing the game or round. |
| guesses_team_id_index | `[:team_id]` | Standard | Medium | Useful for finding all guesses for a team. Keep if this is a common query pattern. |
| guesses_player1_id_player2_id_index | `[:player1_id, :player2_id]` | Standard | Medium | Useful for finding guesses by player pair. Keep if you frequently look up guesses by both players together. |
| guesses_successful_index | `[:successful]` | Standard | Low | Very low selectivity (boolean field). Consider removing unless you frequently filter only by success status without other criteria. |
| guesses_event_id_index | `[:event_id]` | Standard | High | Essential for linking guesses to events in the event store. |
| guesses_game_round_index | `[:game_id, :round_id, :guess_number]` | Standard | High | Critical for the replay system to efficiently retrieve guesses in order for a specific game and round. |

## Team Invitations Table Indexes

| Index | Columns | Type | Utility | Analysis |
|-------|---------|------|---------|----------|
| team_invitations_team_id_index | `[:team_id]` | Standard | High | Essential for finding all invitations for a team. |
| team_invitations_guild_id_index | `[:guild_id]` | Standard | Low | Low selectivity and likely redundant. Consider removing unless you query invitations directly by guild without other criteria. |
| team_invitations_invited_user_id_index | `[:invited_user_id]` | Standard | High | Essential for finding all invitations for a user. |
| team_invitations_team_id_invited_user_id_index | `[:team_id, :invited_user_id]` | Unique | High | Critical for enforcing uniqueness and for looking up specific invitations. |

## Event Store Tables Indexes

| Index | Columns | Type | Utility | Analysis |
|-------|---------|------|---------|----------|
| event_store.events_stream_id_event_version_index | `[:stream_id, :event_version]` | Unique | High | Critical for the event store to efficiently retrieve events in order for a specific stream. |

## Recommendations for Index Optimization

### Indexes to Consider Removing

1. **game_rounds_guild_id_index**: Low selectivity and likely redundant with game filtering.
2. **player_stats_guild_id_index**: Low selectivity and covered by the composite index.
3. **round_stats_guild_id_index**: Low selectivity and likely redundant.
4. **guesses_guild_id_index**: Low selectivity and likely redundant.
5. **guesses_successful_index**: Very low selectivity (boolean field).
6. **team_invitations_guild_id_index**: Low selectivity and likely redundant.

### Indexes to Consider Consolidating

1. **guesses_game_id_index** and **guesses_round_id_index**: These are partially covered by the composite index `guesses_game_round_index`. If most queries use both game_id and round_id together, these individual indexes may be redundant.

### Indexes to Keep

1. All unique indexes: These are essential for data integrity.
2. All high-utility indexes: These support critical query patterns.
3. Medium-utility indexes that support specific query patterns in your application.

## Performance Testing Recommendation

Before removing any indexes, it's recommended to:

1. Analyze your application's actual query patterns using PostgreSQL's query analyzer.
2. Test the performance impact of removing indexes in a staging environment.
3. Monitor query performance after changes to ensure no degradation.

Remember that the optimal index strategy depends on your specific application's query patterns and data volume. This analysis provides general guidance based on common patterns, but your actual usage may vary. 