# Team Management Architecture

## Overview

The team management system follows CQRS (Command Query Responsibility Segregation) and Event Sourcing patterns. Teams are fundamental units in the game system, consisting of exactly two players. Team formation requires explicit acceptance from both players, with a configurable command prefix (default: "wm") used without spaces before commands.

## Core Components

### 1. Events (`GameBot.Domain.Events.TeamEvents`)

#### TeamInvitationCreated
- **Purpose**: Records a team invitation
- **Properties**:
  - `invitation_id`: Unique identifier
  - `inviter_id`: Player sending invitation
  - `invitee_id`: Player receiving invitation
  - `proposed_name`: Optional team name
  - `created_at`: Timestamp
  - `expires_at`: Expiration timestamp (5 minutes from creation)

#### TeamInvitationAccepted
- **Purpose**: Records acceptance of team invitation
- **Properties**:
  - `invitation_id`: Reference to invitation
  - `team_id`: New team's ID
  - `accepted_at`: Timestamp

#### TeamCreated
- **Purpose**: Records the creation of a team or new team membership
- **Properties**:
  - `team_id`: Unique identifier for the team (derived from sorted player IDs)
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

#### CreateTeamInvitation
- **Purpose**: Initiate team formation
- **Trigger**: `{prefix}team @mention [teamname]` (default: "wmteam")
- **Behavior**: 
  - Creates pending invitation
  - Notifies mentioned player
  - Expires after 5 minutes
- **Validation Rules**:
  - Both players must exist
  - Players must be different users
  - No pending invitations between players
  - Name validation if provided

#### AcceptTeamInvitation
- **Purpose**: Accept pending team invitation
- **Trigger**: `{prefix}ok` (default: "wmok")
- **Behavior**:
  - Validates invitation exists and hasn't expired
  - Creates new team
  - Previous team memberships are naturally superseded
  - Uses default or proposed name
- **Validation Rules**:
  - Valid invitation must exist
  - Invitation must not be expired
  - Accepting player must be invitee

#### RenameTeam
- **Purpose**: Update team name
- **Trigger**: `{prefix}rename teamname` (default: "wmrename")
- **Behavior**:
  - Updates name of requester's current team
  - Only team members can rename
- **Validation Rules**:
  - Requester must be in a team
  - Name must meet validation rules

### 3. Aggregate (`GameBot.Domain.Aggregates.TeamAggregate`)

The team aggregate manages team consistency and handles command processing.

#### State
- Maintains current team state:
  - `team_id`
  - `name`
  - `player_ids`
  - `created_at`
  - `updated_at`

#### Command Handlers
- **JoinTeam**:
  - Validates player combination
  - Generates team ID
  - Emits TeamCreated event
- **RenameTeam**:
  - Validates requester membership
  - Validates name
  - Emits TeamUpdated event if name changed

#### Event Handlers
- **TeamCreated**: Initializes or reforms team
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

#### PendingInvitationView
- Tracks active team invitations:
  - `invitation_id`
  - `inviter_id`
  - `invitee_id`
  - `proposed_name`
  - `created_at`
  - `expires_at`

#### PlayerTeamView
- Tracks current team membership:
  - `player_id`
  - `current_team_id`
  - `joined_at`

#### TeamNameHistory
- Optimized historical record containing:
  - `team_id`: Team identifier
  - `previous_name`: Previous name (nil for creation)
  - `new_name`: New name after change
  - `changed_at`: When the change occurred
  - `changed_by`: Who made the change
  - `sequence_no`: Ordered index of change
  - `event_type`: Type of change ("created" or "updated")

## Validation Rules

### Team Names
- Minimum length: 3 characters
- Maximum length: 32 characters
- Allowed characters: alphanumeric, spaces, hyphens, and emojis
- Pattern: `^[\p{L}\p{N}\p{Emoji}\s-]+$`

### Team Composition
- Exactly 2 players
- Players can only be in one active team
- Joining a new team supersedes previous team membership

## Team ID Generation
```elixir
def generate_team_id(player1_id, player2_id) do
  # Sort player IDs to ensure consistent team_id
  [p1, p2] = Enum.sort([player1_id, player2_id])
  "team-#{p1}-#{p2}"
end
```

## Usage Examples

### Forming a Team
```elixir
# User types: !team @partner Cool Team Name
command = %JoinTeam{
  initiator_id: "user1",
  partner_id: "user2",
  name: "Cool Team Name"  # Optional
}
```

### Renaming a Team
```elixir
# User types: !rename Awesome Squad
command = %RenameTeam{
  team_id: "team-user1-user2",
  new_name: "Awesome Squad",
  requester_id: "user1"
}
```

## Integration Points

1. **Game System**:
   - Teams participate in games
   - Team IDs are referenced in game events
   - Team state affects game mechanics

2. **Player System**:
   - Players can only be in one active team
   - New team formation invalidates previous teams
   - Team membership affects player capabilities

3. **Event Store**:
   - All team events are persisted
   - Events are used for state reconstruction
   - Projections subscribe to team events

## Command Flow Examples

### Team Formation
```
1. Invitation Phase:
User Command ({prefix}team @partner TeamName)
  -> Parse mention and name
  -> Validate invitation request
  -> Create invitation
  -> Emit TeamInvitationCreated event
  -> Notify mentioned user with "Use {prefix}ok to accept"
  -> Start 5-minute expiration timer

2. Acceptance Phase:
User Command ({prefix}ok)
  -> Validate invitation exists and is valid
  -> Generate team_id from sorted user IDs
  -> Create new team
  -> Emit TeamCreated event
  -> Projection updates player->team mappings
  -> Send confirmation to both players
```

### Team Rename
```
User Command ({prefix}rename NewName)
  -> Find user's current team
  -> Validate membership
  -> Validate new name
  -> Update team name
  -> Emit TeamUpdated event
  -> Update projections
  -> Send confirmation
```

## Error Handling

### Common Error Cases
- Invalid team name format
- User not found
- Self-mention
- No active team (for rename)
- Invalid characters in name
- No pending invitation
- Invitation expired
- Wrong invitee

### Error Responses
- "Team names must be 3-32 characters"
- "You can't form a team with yourself"
- "You need to be in a team to rename it"
- "Couldn't find the mentioned user"
- "Invalid characters in team name"
- "No pending invitation"
- "That invitation has expired"
- "That invitation was for someone else" 