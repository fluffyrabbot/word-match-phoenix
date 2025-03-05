# Replay System Architecture

## Overview

The replay system reconstructs complete game histories from event streams for visualization and analysis. Each game mode has its own replay implementation due to different display requirements, but all follow a common interface.

## Core Components

### Base Replay Behavior
```elixir
defmodule GameBot.Replay.BaseReplay do
  @callback build_replay(event_stream :: [Event.t()]) :: 
    {:ok, replay :: Replay.t()} | {:error, term()}
  
  @callback format_embed(replay :: Replay.t()) ::
    Nostrum.Struct.Embed.t()
    
  @callback format_summary(replay :: Replay.t()) :: String.t()
  
  # Optional callback for mode-specific stats
  @callback calculate_mode_stats(replay :: Replay.t()) :: map()
end
```

### Common Types
```elixir
defmodule GameBot.Replay.Types do
  @type base_replay :: %{
    game_id: String.t(),
    mode: module(),
    start_time: DateTime.t(),
    end_time: DateTime.t(),
    events: [Event.t()],
    base_stats: base_stats()
  }
  
  @type base_stats :: %{
    duration_seconds: integer(),
    total_guesses: integer(),
    successful_matches: integer(),
    players: [String.t()]
  }
end
```

## Data Persistence Layer

### Database Schema
```sql
-- Completed game replays
CREATE TABLE game_replays (
  id SERIAL PRIMARY KEY,
  game_id TEXT NOT NULL UNIQUE,
  mode TEXT NOT NULL,
  start_time TIMESTAMP NOT NULL,
  end_time TIMESTAMP NOT NULL,
  event_stream JSONB NOT NULL,
  base_stats JSONB NOT NULL,
  mode_stats JSONB,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Replay access tracking
CREATE TABLE replay_access_logs (
  id SERIAL PRIMARY KEY,
  game_id TEXT NOT NULL,
  accessed_at TIMESTAMP NOT NULL,
  accessed_by TEXT NOT NULL,
  FOREIGN KEY (game_id) REFERENCES game_replays(game_id)
);

-- Indexes
CREATE INDEX idx_game_replays_mode ON game_replays(mode);
CREATE INDEX idx_game_replays_start_time ON game_replays(start_time);
CREATE INDEX idx_replay_access_logs_game_id ON replay_access_logs(game_id);
```

### Persistence Flow
1. **Game Completion**
   - Game completion event triggers replay persistence
   - Event stream and stats are processed and stored
   - Existing replay data is never modified (immutable)

2. **Data Management**
   - Access tracking for analytics
   - Backup integration for long-term storage

3. **Access Patterns**
   ```elixir
   defmodule GameBot.Replay.Storage do
     @doc """
     Stores a completed game replay
     """
     @spec store_replay(Replay.t()) :: {:ok, String.t()} | {:error, term()}
     
     @doc """
     Retrieves a replay by game_id
     """
     @spec get_replay(String.t()) :: {:ok, Replay.t()} | {:error, term()}
     
     @doc """
     Lists recent replays with optional filtering
     """
     @spec list_replays(opts :: keyword()) :: {:ok, [Replay.t()]} | {:error, term()}
     
     @doc """
     Manages replay retention and cleanup
     """
     @spec cleanup_old_replays() :: {:ok, integer()} | {:error, term()}
   end
   ```

4. **Performance Optimizations**
   - Caching layer for frequently accessed replays
   - Batch processing for cleanup operations
   - Streaming for large event sets
   - Compression for long-term storage

## Mode-Specific Implementations

### Two Player Mode
- Focuses on cooperative progression
- Side-by-side guess history
- Perfect match tracking
- Average guess statistics

### Knockout Mode
- Elimination tracking
- Round-by-round progression
- Team performance comparison
- Elimination cause tracking

### Race Mode
- Speed-focused metrics
- Parallel team progress
- Match rate tracking
- Time-based milestones

### Golf Race Mode
- Point-based scoring display
- Efficiency metrics
- Team comparisons
- Score progression

## Implementation Checklist

### Core Infrastructure
- [ ] Create `GameBot.Replay` namespace
- [ ] Define base behavior and types
- [ ] Implement common utilities
  - [ ] Time formatting
  - [ ] Basic statistics calculation
  - [ ] Event stream validation
  - [ ] Error handling

### Persistence Layer
- [ ] Database setup
  - [ ] Create migrations for replay tables
  - [ ] Add indexes for performance
  - [ ] Set up access logging
- [ ] Storage implementation
  - [ ] Create `GameBot.Replay.Storage` module
  - [ ] Implement CRUD operations
  - [ ] Add caching layer
  - [ ] Set up cleanup job
- [ ] Event processing
  - [ ] Game completion handlers
  - [ ] Event stream serialization
  - [ ] Stats calculation and storage
- [ ] Performance optimization
  - [ ] Implement compression
  - [ ] Add batch processing
  - [ ] Configure caching
  - [ ] Set up monitoring

### Two Player Mode Replay
- [ ] Create `GameBot.Replay.TwoPlayerReplay`
  - [ ] Event processing
  - [ ] Stats calculation
  - [ ] Guess history formatting
- [ ] Implement embed formatting
  - [ ] Side-by-side display
  - [ ] Match indicators
  - [ ] Timestamp formatting
- [ ] Add summary generation
  - [ ] Performance metrics
  - [ ] Perfect match count
  - [ ] Average guesses

### Knockout Mode Replay
- [ ] Create `GameBot.Replay.KnockoutReplay`
  - [ ] Round tracking
  - [ ] Elimination processing
  - [ ] Team progression
- [ ] Implement embed formatting
  - [ ] Round-by-round display
  - [ ] Elimination highlights
  - [ ] Team performance
- [ ] Add summary generation
  - [ ] Elimination order
  - [ ] Round statistics
  - [ ] Team metrics

### Race Mode Replay
- [ ] Create `GameBot.Replay.RaceReplay`
  - [ ] Match tracking
  - [ ] Speed metrics
  - [ ] Team progress
- [ ] Implement embed formatting
  - [ ] Progress visualization
  - [ ] Time markers
  - [ ] Team comparisons
- [ ] Add summary generation
  - [ ] Match rates
  - [ ] Speed metrics
  - [ ] Team rankings

### Golf Race Mode Replay
- [ ] Create `GameBot.Replay.GolfRaceReplay`
  - [ ] Point calculation
  - [ ] Efficiency tracking
  - [ ] Score progression
- [ ] Implement embed formatting
  - [ ] Score display
  - [ ] Efficiency metrics
  - [ ] Team standings
- [ ] Add summary generation
  - [ ] Final scores
  - [ ] Efficiency stats
  - [ ] Team rankings

### Command System Integration
- [ ] Create replay command handler
- [ ] Add command routing
- [ ] Implement permissions
- [ ] Add error handling
- [ ] Create help documentation

### Testing
- [ ] Unit tests for each replay type
- [ ] Integration tests
- [ ] Event reconstruction tests
- [ ] Display formatting tests
- [ ] Error handling tests

### Documentation
- [ ] API documentation
- [ ] Usage examples
- [ ] Error handling guide
- [ ] Command reference

## File Structure
```
lib/game_bot/replay/
├── base_replay.ex           # Base behavior and common types
├── types.ex                # Shared type definitions
├── utils/
│   ├── time_formatter.ex   # Time formatting utilities
│   ├── stats_calculator.ex # Common statistics functions
│   └── embed_formatter.ex  # Shared embed formatting
├── modes/
│   ├── two_player.ex      # Two player mode replay
│   ├── knockout.ex        # Knockout mode replay
│   ├── race.ex           # Race mode replay
│   └── golf_race.ex      # Golf race mode replay
└── command.ex            # Replay command implementation
```

## Usage Example
```elixir
# Fetching and displaying a replay
def handle_replay_command(game_id) do
  with {:ok, events} <- EventStore.read_stream_forward(game_id),
       mode = determine_game_mode(events),
       replay_module = get_replay_module(mode),
       {:ok, replay} <- replay_module.build_replay(events),
       embed = replay_module.format_embed(replay) do
    {:ok, embed}
  end
end
```

## Error Handling

### Common Error Types
- Invalid event stream
- Missing critical events
- Corrupted game state
- Invalid game mode
- Display formatting errors

### Recovery Strategies
1. Validate event stream integrity
2. Handle incomplete games gracefully
3. Provide meaningful error messages
4. Fall back to basic display when needed

## Performance Considerations

### Optimization Strategies
1. Cache processed replays
2. Lazy load detailed statistics
3. Paginate long histories
4. Batch process events
5. Optimize embed generation

### Memory Management
1. Limit event history size
2. Clean up old cached replays
3. Use streaming for large games
4. Implement timeout handling

## Future Enhancements

### Planned Features
1. Interactive navigation
2. Replay filtering
3. Statistics export
4. Custom view options
5. Replay sharing

### Extension Points
1. New game mode support
2. Custom statistics
3. Alternative display formats
4. Data export formats 