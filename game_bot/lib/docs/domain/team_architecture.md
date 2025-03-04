# Team Management Architecture

## Overview

The team management system follows CQRS (Command Query Responsibility Segregation) and Event Sourcing patterns. Teams are fundamental units in the game system, consisting of exactly two players and maintaining persistent identities across games. The system includes comprehensive historical tracking of team changes, with optimized storage for name modifications.

## Core Components

### 1. Events (`GameBot.Domain.Events.TeamEvents`)

#### TeamCreated
- **Purpose**: Records the creation of a new team
- **Properties**:
  - `team_id`: Unique identifier for the team
  - `name`: Team's display name
  - `player_ids`: List of exactly 2 player IDs
  - `created_at`: Timestamp of creation
  - `metadata`: Additional context information (including `changed_by`)

#### TeamUpdated
- **Purpose**: Records changes to team details
- **Properties**:
  - `team_id`: Team identifier
  - `name`: New team name
  - `updated_at`: Timestamp of update
  - `metadata`: Additional context information (including `changed_by`)

### 2. Commands (`GameBot.Domain.Commands.TeamCommands`)

#### CreateTeam
- **Purpose**: Request to create a new team
- **Validation Rules**:
  - Team ID must be provided
  - Name must be 3-32 characters
  - Name must contain only alphanumeric characters, spaces, and hyphens
  - Must have exactly 2 players

#### UpdateTeam
- **Purpose**: Request to update team details
- **Validation Rules**:
  - Team ID must be provided
  - Name must be 3-32 characters
  - Name must contain only alphanumeric characters, spaces, and hyphens

### 3. Aggregate (`GameBot.Domain.Aggregates.TeamAggregate`)

The team aggregate is the consistency boundary for team-related operations.

#### State
- Maintains current team state:
  - `team_id`
  - `name`
  - `player_ids`
  - `created_at`
  - `updated_at`

#### Command Handlers
- **CreateTeam**:
  - Validates team doesn't already exist
  - Validates command data
  - Emits TeamCreated event
- **UpdateTeam**:
  - Validates team exists
  - Validates command data
  - Emits TeamUpdated event if name changed

#### Event Handlers
- **TeamCreated**: Initializes team state
- **TeamUpdated**: Updates team name and timestamp

### 4. Projection (`GameBot.Domain.Projections.TeamProjection`)

Builds and maintains read models for efficient querying of team data.

#### TeamView
- Read model containing:
  - `team_id`
  - `name`
  - `player_ids`
  - `created_at`
  - `updated_at`

#### TeamNameHistory
- Optimized historical record containing:
  - `team_id`: Team identifier
  - `previous_name`: Previous name (nil for creation)
  - `new_name`: New name after change
  - `changed_at`: When the change occurred
  - `changed_by`: Who made the change (if available)
  - `sequence_no`: Ordered index of change
  - `event_type`: Type of change ("created" or "updated")

#### Storage Optimizations
- **Delta-Based Storage**: Only stores actual changes rather than full state
- **Sequence Numbering**: Uses integer sequence for efficient ordering
- **Change Validation**: Only creates history entries for actual name changes
- **Efficient Reconstruction**: Can rebuild full timeline from change records
- **Minimal Redundancy**: Previous name tracking eliminates need for lookups

#### Event Handlers
- Processes TeamCreated and TeamUpdated events
- Maintains current state of teams
- Records only actual name changes
- Maintains sequential ordering of changes

#### Query Interface
- `get_team(team_id)`: Retrieve team by ID
- `list_teams()`: List all teams
- `find_team_by_player(player_id)`: Find team containing player
- `get_team_name_history(team_id)`: Get complete name history
- `get_team_name_history(team_id, opts)`: Get filtered history with options:
  - `from`: Start of time range
  - `to`: End of time range
  - `limit`: Maximum number of entries
  - `order`: Sort order (`:asc` or `:desc`)
- `reconstruct_name_timeline(history)`: Build complete timeline from changes

## Data Flow

1. **Command Flow**:
   ```
   Command -> TeamAggregate -> Event(s) -> EventStore
   ```

2. **Query Flow**:
   ```
   Event -> TeamProjection -> {TeamView, TeamNameHistory} -> Query Result
   ```

## Historical Tracking

### Name History
- Changes are stored as transitions:
  - From previous name to new name
  - Sequential ordering for efficient retrieval
  - Only actual changes are recorded
  - Creation events marked with nil previous name

### Storage Efficiency
- **Space Optimization**:
  - Only stores actual changes
  - No redundant full state copies
  - Integer-based sequence ordering
  - Minimal metadata per change

- **Query Optimization**:
  - Fast ordering by sequence number
  - Efficient filtering by timestamp
  - Direct access to previous states
  - Minimal reconstruction overhead

### Query Capabilities
- Full history retrieval
- Time-range filtering
- Result limiting
- Chronological ordering
- Attribution tracking
- Timeline reconstruction

## Validation Rules

### Team Names
- Minimum length: 3 characters
- Maximum length: 32 characters
- Allowed characters: alphanumeric, spaces, hyphens
- Pattern: `^[a-zA-Z0-9\s-]+$`

### Team Composition
- Exactly 2 players per team
- Players must have valid IDs
- Team IDs must be unique and persistent

## Event Versioning

All events include:
- `event_type()`: String identifier
- `event_version()`: Integer version number
- `validate()`: Validation rules
- `to_map()`: Serialization
- `from_map()`: Deserialization

## Usage Examples

### Creating a Team
```elixir
command = %CreateTeam{
  team_id: "team-123",
  name: "Awesome Team",
  player_ids: ["player1", "player2"]
}
TeamAggregate.execute(%State{}, command)
```

### Updating a Team
```elixir
command = %UpdateTeam{
  team_id: "team-123",
  name: "New Team Name"
}
TeamAggregate.execute(existing_state, command)
```

### Querying Name History
```elixir
# Get complete history
TeamProjection.get_team_name_history("team-123")

# Get filtered history
TeamProjection.get_team_name_history("team-123", 
  from: ~U[2024-01-01 00:00:00Z],
  to: ~U[2024-12-31 23:59:59Z],
  limit: 10,
  order: :desc
)

# Reconstruct timeline
history = TeamProjection.get_team_name_history("team-123")
timeline = TeamProjection.reconstruct_name_timeline(history)
```

## Integration Points

1. **Game System**:
   - Teams participate in games
   - Team IDs are referenced in game events
   - Team state affects game mechanics

2. **Player System**:
   - Players are assigned to teams
   - Player IDs are validated during team creation
   - Team membership affects player capabilities

3. **Event Store**:
   - All team events are persisted
   - Events are used for state reconstruction
   - Projections subscribe to team events

## Future Considerations

1. **Storage Implementation**:
   - Implement persistence with optimized indices
   - Use materialized views for common queries
   - Implement efficient archival strategy
   - Consider compression for old records

2. **Performance Optimizations**:
   - Cache frequently accessed histories
   - Batch timeline reconstructions
   - Implement pagination for large histories
   - Add composite indices for common queries

3. **Command Router Integration**:
   - Add team commands to router
   - Implement command middleware
   - Add command logging
   - Track command attribution for history

4. **Discord Integration**:
   - Create team management commands
   - Add team-related notifications
   - Implement team permission checks
   - Display team history in Discord
   - Add timeline visualization 