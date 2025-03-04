# Game Commands

## Overview
The `GameCommands` module handles core game functionality including game creation, guess processing, and game state management. All game commands ensure proper guild segregation and event correlation tracking.

## Commands

### handle_start_game/3
Initiates a new game session.

```elixir
handle_start_game(%Interaction{}, mode, options)
```

**Parameters:**
- `interaction`: Discord interaction containing guild_id and user info
- `mode`: Atom representing game mode (`:classic`, etc.)
- `options`: Map containing:
  ```elixir
  %{
    teams: %{
      team_map: %{team_id => [player_ids]},
      team_ids: [String.t()],
      player_ids: [String.t()],
      roles: %{player_id => role}
    },
    time_limit: integer() | nil,
    max_rounds: integer() | nil
  }
  ```

**Returns:**
- `{:ok, %GameEvents.GameStarted{}}`: On successful game creation
- `{:error, reason}`: If validation fails

**Event Chain:**
```
GameStarted
└─> RoundStarted (automatic)
```

### handle_guess/4
Processes a player's guess during an active game.

```elixir
handle_guess(%Interaction{}, game_id, word, parent_metadata)
```

**Parameters:**
- `interaction`: Discord interaction
- `game_id`: String identifying the active game
- `word`: The guessed word
- `parent_metadata`: Metadata from parent game event for correlation

**Returns:**
- `{:ok, %GameEvents.GuessProcessed{}}`: On successful guess
- `{:error, reason}`: If validation fails

**Event Chain:**
```
GuessProcessed
└─> (Conditional Events)
    ├─> TeamEliminated (if team fails)
    └─> GameCompleted (if game ends)
```

## Validation Rules

### Team Validation
- Teams must have exactly 2 players
- Players can't be in multiple teams
- Each team must have one giver and one guesser

### Game Mode Validation
- Classic mode: No special requirements
- Race mode: Requires time_limit
- Knockout mode: Requires min_teams and max_rounds

## Example Usage

```elixir
# Starting a classic game
{:ok, event} = GameCommands.handle_start_game(
  interaction,
  :classic,
  %{
    teams: %{
      team_map: %{"team_1" => ["user_1", "user_2"]},
      team_ids: ["team_1"],
      player_ids: ["user_1", "user_2"],
      roles: %{"user_1" => :giver, "user_2" => :guesser}
    }
  }
)

# Processing a guess
{:ok, event} = GameCommands.handle_guess(
  interaction,
  "game_123",
  "test_word",
  parent_metadata
)
```

## Error Handling

Common error cases:
```elixir
{:error, :invalid_team_structure}  # Team validation failed
{:error, :game_not_found}         # Game ID not found
{:error, :invalid_turn}           # Not player's turn
{:error, :game_completed}         # Game already ended
```

## Metadata Handling

All game events include:
- `guild_id`: Server where game is played
- `correlation_id`: Links related game events
- `causation_id`: Tracks event chain relationships 