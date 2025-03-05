# Stats Commands

## Overview
The `StatsCommands` module handles game statistics, leaderboards, and performance metrics. All stats are server-specific and provide insights into player and team performance.

## Commands

### handle_player_stats/2
Retrieves statistics for a specific player.

```elixir
handle_player_stats(%Interaction{}, player_id)
```

**Parameters:**
- `interaction`: Discord interaction containing guild_id
- `player_id`: Discord ID of player to look up

**Returns:**
- `{:ok, discord_message}`: Formatted stats message
- `{:error, reason}`: If lookup fails

**Stats Include:**
```elixir
%{
  games_played: integer(),
  wins: integer(),
  average_score: float(),
  best_partner: String.t(),
  win_rate: float()
}
```

### handle_team_stats/2
Retrieves statistics for a specific team.

```elixir
handle_team_stats(%Interaction{}, team_id)
```

**Parameters:**
- `interaction`: Discord interaction
- `team_id`: Team identifier

**Returns:**
- `{:ok, discord_message}`: Formatted team stats
- `{:error, reason}`: If lookup fails

**Stats Include:**
```elixir
%{
  games_played: integer(),
  wins: integer(),
  average_score: float(),
  best_game: game_summary(),
  win_streak: integer(),
  ranking: integer()
}
```

### handle_leaderboard/3
Generates server leaderboard based on specified criteria.

```elixir
handle_leaderboard(%Interaction{}, type, options)
```

**Parameters:**
- `interaction`: Discord interaction
- `type`: `:players` | `:teams` | `:pairs`
- `options`: Map containing:
  ```elixir
  %{
    timeframe: "all" | "month" | "week" | "day",
    limit: integer()  # Number of entries
  }
  ```

**Returns:**
- `{:ok, discord_message}`: Formatted leaderboard
- `{:error, reason}`: If generation fails

## Display Formatting

### Player Stats Format
```
Player Stats for @username
Games Played: 42
Wins: 23 (55% win rate)
Average Score: 8.5
Best Partner: @partner (12 wins together)
Preferred Role: Giver (65% of games)
```

### Team Stats Format
```
Team Stats for "Team Name"
Games Played: 30
Wins: 18 (60% win rate)
Average Score: 9.2
Best Game: 15 points vs Team X
Current Win Streak: 3
Server Ranking: #2
```

### Leaderboard Format
```
🏆 Top Players This Week 🏆
1. @player1 - 150 points
2. @player2 - 145 points
3. @player3 - 140 points
...
```

## Timeframe Handling

Stats can be filtered by timeframe:
- `all`: All-time stats
- `month`: Current calendar month
- `week`: Current week (Mon-Sun)
- `day`: Last 24 hours

## Error Handling

Common error cases:
```elixir
{:error, :player_not_found}    # Player hasn't played any games
{:error, :team_not_found}      # Team doesn't exist
{:error, :invalid_timeframe}   # Unknown time period
{:error, :no_data}            # No stats for period
```

## Metadata Handling

All stats queries include:
- `guild_id`: Server scope for stats
- `correlation_id`: For tracking related queries

## Performance Considerations

1. Stats are cached with 5-minute TTL
2. Leaderboards cache for 1 minute
3. Real-time stats may have slight delay
4. Long timeframes may take longer to compute 