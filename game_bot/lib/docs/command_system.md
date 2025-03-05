# Command System Architecture

## Overview

The command system is split into three layers:
1. Dispatcher (Entry Point)
2. Command Handler (Message Commands)
3. Game Commands (Implementation)

## Components

### Dispatcher (`GameBot.Bot.Dispatcher`)

The dispatcher is the entry point for all Discord events. It handles:

1. **Slash Commands** (directly routes to GameCommands):
   ```elixir
   /start [mode] [options]  # Start a new game
   /team create [options]   # Create team via slash command
   /guess [game_id] [word] # Submit guess via slash command
   ```

2. **Message Events**:
   - Routes all message events to CommandHandler
   - Maintains clean separation between Discord events and command processing

### Command Handler (`GameBot.Bot.CommandHandler`)

Handles text-based commands and DM interactions:

1. **Prefix Commands** (using "!" prefix):
   ```elixir
   !team @user  # Create team with mentioned user
   ```

2. **DM Guesses**:
   - Any message in a DM is treated as a guess
   - Uses ETS to track active games per user

3. **Active Game Tracking**:
   ```elixir
   # ETS table for fast user->game lookups
   @active_games_table :active_games
   
   # Public API
   set_active_game(user_id, game_id)    # Associate user with game
   clear_active_game(user_id)           # Remove user's game association
   ```

### Game Commands (`GameBot.Bot.Commands.GameCommands`)

Implementation layer that:
- Processes both slash commands and message commands
- Generates appropriate game events
- Handles core game logic

## Command Flow

1. **Slash Commands**:
   ```
   Discord → Dispatcher → GameCommands
   ```

2. **Message Commands**:
   ```
   Discord → Dispatcher → CommandHandler → GameCommands
   ```

3. **DM Guesses**:
   ```
   Discord → Dispatcher → CommandHandler → [ETS Lookup] → GameCommands
   ```

## Active Game State Management

Currently using ETS for active game tracking:

- **Table**: Named `:active_games`
- **Structure**: `{user_id, game_id}`
- **Access**: Public table for fast lookups
- **Lifecycle**: Initialized in CommandHandler.init/0

## Future Considerations

1. **Game Sessions**:
   - Planned to be implemented as GenServers
   - May switch from ETS to Registry when implemented
   - Could maintain both for different purposes:
     - ETS for fast lookups
     - Registry for process management

2. **Additional Commands**:
   - More prefix commands can be added in CommandHandler
   - More slash commands can be added in Dispatcher

3. **Error Handling**:
   - Need to implement proper error responses
   - Should add command validation
   - Consider adding rate limiting

## Command Reference

### Slash Commands
```elixir
/start
  mode: String    # Game mode to start
  options: Map    # Game configuration options

/team create
  name: String    # Team name
  players: List   # Player IDs

/guess
  game_id: String # ID of active game
  word: String    # Word to submit
```

### Message Commands
```elixir
!team @user       # Create team with mentioned user
```

### DM Commands
```elixir
any_text         # Treated as guess for active game
``` 