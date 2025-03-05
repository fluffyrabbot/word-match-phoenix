# Team Commands

## Overview
The `TeamCommands` module handles team management functionality including team formation, invitations, and updates. All commands use a configurable prefix (default: "wm").

## Command Prefix
- Default prefix: "wm"
- Configurable per server
- Example: If prefix is "wm", commands are used as "wmteam", "wmok", etc.
- No space between prefix and command

## Commands

### Team Formation

#### Create Team Invitation
```
{prefix}team @player [teamname]
```
- Creates a pending team invitation
- Optional team name can be provided
- Invitation expires after 5 minutes
- Notifies mentioned player

Example:
```
wmteam @partner Cool Team Name
> Invitation sent to @partner! They have 5 minutes to accept with "wmok"
```

#### Accept Team Invitation
```
{prefix}ok
```
- Accepts most recent pending team invitation
- Must be used within 5 minutes
- Creates new team upon acceptance
- Previous team memberships are superseded

Example:
```
wmok
> Team "Cool Team Name" formed with @inviter!
```

### Team Management

#### Rename Team
```
{prefix}rename new_team_name
```
- Changes current team's name
- Must be a team member to rename
- Follows team name validation rules

Example:
```
wmrename Awesome Squad
> Team name updated to "Awesome Squad"
```

## Validation Rules

### Team Names
- 3-32 characters
- Alphanumeric, spaces, hyphens, and emojis allowed
- Pattern: `^[\p{L}\p{N}\p{Emoji}\s-]+$`

### Team Formation
- Cannot invite yourself
- Cannot have multiple pending invitations
- Must accept invitation within 5 minutes
- Only invitee can accept invitation

## Error Messages

### Invitation Errors
```
"You can't form a team with yourself"
"You already have a pending invitation with this player"
"That invitation has expired"
"No pending invitation"
"That invitation was for someone else"
```

### Team Management Errors
```
"You need to be in a team to rename it"
"Team names must be 3-32 characters"
"Invalid characters in team name"
```

## Examples

### Complete Team Formation Flow
```
Player1: wmteam @Player2 Dream Team
> Invitation sent to @Player2! They have 5 minutes to accept.

Player2: wmok
> Team "Dream Team" formed with @Player1!

Player1: wmrename Super Squad
> Team name updated to "Super Squad"
```

## Implementation Notes

1. Invitations are tracked in ETS for performance
2. Expired invitations are automatically cleaned up
3. Team membership changes are event sourced
4. Name history is maintained for auditing

Players join games with the command {prefix}team [@player] where @player is a discord mention of the player you want to join a team with.


