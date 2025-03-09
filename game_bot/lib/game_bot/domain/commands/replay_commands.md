# Replay Commands Implementation Roadmap

## Overview

This document outlines the steps needed to fully implement the replay system functionality in the GameBot.Domain.Commands.ReplayCommands module, replacing current placeholder implementations with production-ready code.

## Current Status

The module currently has placeholder implementations for:
- Fetching game replays
- Fetching match history
- Fetching game summaries
- Validating replay access

Many of these implementations return mocked data or simplified results, and error handling is preliminary.

## Implementation Roadmap

### 1. FetchGameReplay

**Status**: Partially implemented
- ✅ Basic structure in place
- ✅ Already uses EventStore.read_stream_forward

**TODO Items**:
- [ ] Add proper error handling for stream not found
- [ ] Implement guild_id-based access control at the query level
- [ ] Add pagination support for large game replays
- [ ] Add event filtering options

**Implementation Details**:
```elixir
def execute(%__MODULE__{} = command) do
  opts = [guild_id: command.guild_id]
  case validate_game_id(command.game_id) do
    :ok ->
      fetch_game_events(command.game_id, opts)
    {:error, _reason} = error -> 
      error
  end
end

defp fetch_game_events(game_id, opts) do
  case EventStore.read_stream_forward(game_id, 0, 1000, opts) do
    {:ok, events} when events != [] -> 
      {:ok, events}
    {:ok, []} -> 
      {:error, :game_not_found}
    {:error, _reason} = error -> 
      error
  end
end
```

### 2. FetchMatchHistory

**Status**: Placeholder implementation
- ✅ Basic structure in place
- ✅ Error handling for inputs
- ❌ Returns mock data instead of real data

**TODO Items**:
- [ ] Replace mock data with actual event store queries
- [ ] Implement filtering by date range, game mode, etc.
- [ ] Add pagination support
- [ ] Add sorting options (newest first, etc.)
- [ ] Aggregate events into meaningful match history entries

**Implementation Details**:
```elixir
def execute(%__MODULE__{} = command) do
  # Validate inputs as already implemented
  
  # Query parameters
  filter = Map.get(command.options, :filter, %{})
  limit = Map.get(command.options, :limit, 10)
  offset = Map.get(command.options, :offset, 0)
  
  # Query the event store for game completion events
  # This would use a category projection or similar to find all games
  # in the specified guild
  
  case query_completed_games(command.guild_id, filter, limit, offset) do
    {:ok, game_ids} ->
      # For each game, fetch basic summary information
      matches = Enum.map(game_ids, &fetch_basic_game_info/1)
      {:ok, matches}
    {:error, _reason} = error ->
      error
  end
end
```

### 3. FetchGameSummary

**Status**: Placeholder implementation
- ✅ Basic structure in place
- ✅ Error handling for inputs
- ❌ Returns mock data instead of aggregated summary
- ❌ Teams implementation is mocked

**TODO Items**:
- [ ] Replace mock data with proper event aggregation
- [ ] Implement real game existence verification
- [ ] Extract actual teams from events
- [ ] Calculate winner from game events
- [ ] Add game statistics (duration, scores, etc.)

**Implementation Details**:
```elixir
def execute(%__MODULE__{} = command) do
  # Input validation as already implemented
  
  # Fetch all events for the game
  case EventStore.read_stream_forward(command.game_id, 0, 1000, guild_id: command.guild_id) do
    {:ok, []} ->
      {:error, :game_not_found}
      
    {:ok, events} ->
      # Aggregate events into a game summary
      summary = %{
        game_id: command.game_id,
        mode: extract_game_mode(events),
        teams: extract_teams(events),
        winner: determine_winner(events),
        guild_id: command.guild_id,
        statistics: calculate_statistics(events)
      }
      {:ok, summary}
      
    {:error, _reason} = error ->
      error
  end
end
```

### 4. Validate Replay Access

**Status**: Basic implementation
- ✅ Structure for validation in place
- ✅ Error handling for inputs
- ❌ Actual participant extraction is mocked
- ❌ Admin rights check is mocked

**TODO Items**:
- [ ] Implement proper participant extraction from events
- [ ] Integrate with Discord role system for admin rights check
- [ ] Add guild-level permission checks
- [ ] Add channel-specific access rules if needed

**Implementation Details**:
```elixir
def validate_replay_access(user_id, game_events) do
  # Input validation as already implemented
  
  # Extract participants from events
  participants = Enum.reduce(game_events, MapSet.new(), fn event, acc ->
    case event do
      %{player_id: player_id} when not is_nil(player_id) ->
        MapSet.put(acc, player_id)
      %{participants: participants} when is_list(participants) ->
        Enum.reduce(participants, acc, &MapSet.put(&2, &1))
      _ ->
        acc
    end
  end)
  
  cond do
    MapSet.member?(participants, user_id) ->
      :ok
    check_admin_role(user_id, guild_id_from_events(game_events)) ->
      :ok
    true ->
      {:error, :unauthorized_access}
  end
end
```

## Implementation Priorities

1. **Validate Replay Access** - Critical for security
   - Ensures proper access control before exposing game data

2. **FetchGameReplay** - Core feature
   - Enables viewing of full game replays
   - Already partially implemented

3. **FetchGameSummary** - User-facing feature
   - Provides quick overview of games
   - Depends on proper event aggregation

4. **FetchMatchHistory** - Enhancement feature
   - Shows list of past games
   - Depends on proper game summary implementation

## Technical Requirements

### Event Store Integration
- Need to ensure EventStore queries are optimized for performance
- May need indexes on guild_id and other frequently queried fields

### Event Structure
- Events need consistent schema for player/team information
- Need to document required event fields for proper aggregation

### Discord Integration
- Admin rights checking requires integration with Discord role system
- User ID format must be consistent between Discord and events

## Testing Strategy

1. Unit tests for each command implementation
2. Integration tests with mock event store
3. Property-based tests for event aggregation logic
4. Performance tests for large game histories

## Deployment Considerations

- Any schema changes must be versioned
- Backward compatibility with existing event streams
- Performance monitoring for event store queries
- Consider caching strategies for frequently accessed replays

## Conclusion

Implementing these TODOs will transform the ReplayCommands module from a placeholder to a fully functional component of the game system. The implementation should be done incrementally, with each step being tested thoroughly before moving to the next. 