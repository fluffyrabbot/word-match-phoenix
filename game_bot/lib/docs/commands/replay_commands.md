# Replay Commands

## Overview
The `ReplayCommands` module handles game replay functionality, allowing users to review past games, analyze match history, and view game summaries. All replay data is server-specific and respects user privacy settings.

## Commands

### handle_view_replay/2
Provides a detailed replay of a specific game.

```elixir
handle_view_replay(%Interaction{}, game_id)
```

**Parameters:**
- `interaction`: Discord interaction containing guild_id
- `game_id`: Identifier of game to replay

**Returns:**
- `{:ok, discord_message}`: Formatted replay view
- `{:error, reason}`: If replay unavailable

**Replay Features:**
- Turn-by-turn breakdown
- Word pairs and match scores
- Team performance metrics
- Interactive navigation (buttons)

### handle_match_history/2
Shows recent games for player or team.

```elixir
handle_match_history(%Interaction{}, options)
```

**Parameters:**
- `interaction`: Discord interaction
- `options`: Map containing:
  ```elixir
  %{
    player_id: String.t() | nil,  # Optional player filter
    team_id: String.t() | nil,    # Optional team filter
    limit: integer()              # Number of matches to show
  }
  ```

**Returns:**
- `{:ok, discord_message}`: Formatted match history
- `{:error, reason}`: If history unavailable

### handle_game_summary/2
Provides quick overview of a game.

```elixir
handle_game_summary(%Interaction{}, game_id)
```

**Parameters:**
- `interaction`: Discord interaction
- `game_id`: Game to summarize

**Returns:**
- `{:ok, discord_message}`: Formatted game summary
- `{:error, reason}`: If game not found

## Display Formatting

### Replay View Format
```
Game Replay: Classic Mode
Started: 2024-03-15 20:00 UTC

Round 1:
Team A (@player1, @player2)
- Giver: "cat" → Guesser: "dog" ❌
- Score: 0

Team B (@player3, @player4)
- Giver: "sun" → Guesser: "sun" ✅
- Score: 1

[◀️ Prev] [▶️ Next] [⏹️ Exit]
```

### Match History Format
```
Recent Games for @player
1. vs Team B - Won (10-8) - 2024-03-15
2. vs Team C - Lost (5-7) - 2024-03-14
3. vs Team A - Won (12-6) - 2024-03-13
...
```

### Game Summary Format
```
Game Summary #12345
Mode: Classic
Duration: 15 minutes
Teams:
- Team A: 8 points (Winners!)
  @player1 (Giver) - 5 successful matches
  @player2 (Guesser) - Avg 2.3 guesses
- Team B: 6 points
  @player3 (Giver) - 4 successful matches
  @player4 (Guesser) - Avg 2.8 guesses
```

## Privacy and Permissions

### Viewing Rules
1. Public games:
   - Anyone in server can view
   - Basic stats always visible
2. Private games:
   - Only participants can view details
   - Server admins can view all games

### Data Retention
- Replays stored for 30 days
- Basic game records kept indefinitely
- Personal stats respect user privacy settings

## Error Handling

Common error cases:
```elixir
{:error, :game_not_found}     # Game doesn't exist
{:error, :unauthorized}        # No permission to view
{:error, :replay_expired}     # Replay no longer available
{:error, :invalid_options}    # Bad history filter options
```

## Metadata Handling

All replay operations include:
- `guild_id`: Server scope for replays
- `correlation_id`: For tracking related queries
- `user_id`: For permission checking

## Performance Considerations

1. Replay data is paginated
2. Match history uses cursor-based pagination
3. Summaries are cached for 1 hour
4. Interactive replays timeout after 10 minutes

## Usage Examples

```elixir
# Viewing a replay
{:ok, replay} = ReplayCommands.handle_view_replay(
  interaction,
  "game_123"
)

# Getting match history
{:ok, history} = ReplayCommands.handle_match_history(
  interaction,
  %{
    player_id: "user_1",
    limit: 5
  }
)

# Getting game summary
{:ok, summary} = ReplayCommands.handle_game_summary(
  interaction,
  "game_123"
) 