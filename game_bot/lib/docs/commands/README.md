# Command Handler Documentation

## Overview
This documentation covers the command handling system for the game bot. The system is organized into domain-specific modules, each handling a distinct aspect of the game's functionality.

## Command Modules

### [Game Commands](game_commands.md)
Core game functionality including:
- Starting new games
- Processing guesses
- Managing game state
- Handling game modes

### [Team Commands](team_commands.md)
Team management including:
- Team creation
- Team updates
- Member management
- Team permissions

### [Stats Commands](stats_commands.md)
Statistics and metrics including:
- Player stats
- Team stats
- Leaderboards
- Performance tracking

### [Replay Commands](replay_commands.md)
Game replay functionality including:
- Viewing past games
- Match history
- Game summaries
- Interactive replays

## Common Patterns

### Guild Segregation
All commands ensure proper server (guild) segregation:
```elixir
# Every command starts with metadata extraction
{:ok, metadata} <- create_metadata(interaction)
# metadata.guild_id used for scoping all operations
```

### Event Correlation
Commands maintain event chains:
```elixir
# Parent event
{:ok, parent_event} = handle_start_game(...)
# Child event uses parent's metadata
{:ok, child_event} = handle_guess(..., parent_event.metadata)
```

### Error Handling
Consistent error pattern:
```elixir
{:ok, result} | {:error, reason}
```

### Validation
Multi-step validation using with:
```elixir
with {:ok, metadata} <- create_metadata(interaction),
     {:ok, data} <- validate_input(params),
     {:ok, result} <- perform_operation(data) do
  {:ok, result}
end
```

## Command Registry

The [CommandRegistry](../lib/game_bot/bot/command_registry.ex) module:
- Routes Discord interactions to appropriate handlers
- Parses command options
- Provides consistent interface

Example:
```elixir
def handle_interaction(%Interaction{data: %{name: name}} = interaction) do
  case name do
    "start" -> GameCommands.handle_start_game(...)
    "team create" -> TeamCommands.handle_team_create(...)
    "stats player" -> StatsCommands.handle_player_stats(...)
    "replay" -> ReplayCommands.handle_view_replay(...)
  end
end
```

## Adding New Commands

1. Choose appropriate module based on domain
2. Add command handler function
3. Add to CommandRegistry routing
4. Update documentation
5. Add tests

Example:
```elixir
# In GameCommands
def handle_new_feature(interaction, params) do
  with {:ok, metadata} <- create_metadata(interaction),
       {:ok, result} <- implement_feature(params, metadata) do
    {:ok, result}
  end
end

# In CommandRegistry
"new_feature" -> GameCommands.handle_new_feature(...)
```

## Testing Commands

Each command module has corresponding tests:
- [game_commands_test.exs](../test/game_bot/bot/commands/game_commands_test.exs)
- [team_commands_test.exs](../test/game_bot/bot/commands/team_commands_test.exs)
- [stats_commands_test.exs](../test/game_bot/bot/commands/stats_commands_test.exs)
- [replay_commands_test.exs](../test/game_bot/bot/commands/replay_commands_test.exs)

## Best Practices

1. Always validate input
2. Maintain proper metadata
3. Use correlation IDs
4. Document new commands
5. Add comprehensive tests
6. Follow existing patterns
7. Keep modules focused 