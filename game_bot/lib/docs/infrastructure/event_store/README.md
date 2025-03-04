# Event Store Documentation

## Overview
The GameBot event store implements event sourcing for game state management. It uses the Elixir EventStore library with a custom serializer for game-specific events.

## Current Event Schema (v1)

All events are currently at version 1. Each event includes these base fields:
- `game_id`: String
- `mode`: atom
- `round_number`: positive integer
- `timestamp`: DateTime
- `metadata`: optional map

### Event Types

| Event Type | Version | Purpose | Key Fields |
|------------|---------|---------|------------|
| game_started | 1 | New game initialization | teams, team_ids, player_ids, roles, config |
| round_started | 1 | Round beginning | team_states |
| guess_processed | 1 | Guess attempt result | team_id, player info, words, success status |
| guess_abandoned | 1 | Failed guess attempt | team_id, player info, reason |
| team_eliminated | 1 | Team removal | team_id, reason, final state, stats |
| game_completed | 1 | Game conclusion | winners, final scores, duration |
| knockout_round_completed | 1 | Knockout round end | eliminated/advancing teams |
| race_mode_time_expired | 1 | Race mode timeout | final matches, duration |
| longform_day_ended | 1 | Longform day end | day number, standings |

## Implementation Details

### Serialization
- Events are serialized using `GameBot.Infrastructure.EventStore.Serializer`
- Each event implements the `GameBot.Domain.Events.GameEvents` behaviour
- Events are stored as JSON with type and version metadata

### Configuration
- Custom serializer configured in `GameBot.Infrastructure.EventStore.Config`
- Schema waiting enabled in test environment
- Default EventStore supervision tree used

## Development Guidelines

### Event Updates
1. Add new event struct in `GameBot.Domain.Events.GameEvents`
2. Implement required callbacks:
   - `event_type()`
   - `event_version()`
   - `to_map(event)`
   - `from_map(data)`
   - `validate(event)`
3. Add event type to serializer's `event_version/1` function
4. Update store schema in same commit

### Schema Changes
- Store can be dropped/recreated during development
- No migration scripts needed pre-production
- No backwards compatibility required
- Tests only needed for current version

### Version Control
- All events must be versioned
- Version format: v1, v2, etc.
- Store schema must match latest event version
- Document schema changes in commit messages

### Not Required (Pre-Production)
- Migration paths
- Multi-version support
- Rollback procedures
- Historical data preservation 