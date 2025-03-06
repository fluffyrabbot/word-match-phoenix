# Guild ID Segregation Implementation Checklist

This document outlines the comprehensive plan to ensure proper Discord server (guild) segregation across the application.

## Event Structures

- [x] `GameBot.Domain.Commands.TeamCommandStructs` - Updated ✓
- [x] `GameBot.Domain.Events.GameEvents` modules - Add `guild_id` to all event structs ✓
- [x] `GameBot.Domain.Events.TeamEvents` modules - Add `guild_id` to all event structs ✓
- [x] `GameBot.Domain.Events` (guess events) - Add `guild_id` to all event structs ✓

## Command Handlers

- [x] `GameBot.Bot.Commands.GameCommands` - Ensure all commands include guild_id in validation ✓
- [x] `GameBot.Bot.Commands.ReplayCommands` - Filter replay data by guild_id ✓
- [x] `GameBot.Bot.Commands.StatsCommands` - Filter statistics by guild_id ✓
- [x] `GameBot.Bot.CommandHandler` - Update ETS storage to include guild context ✓

## Aggregates and Domain Logic

- [x] `GameBot.Domain.Aggregates.TeamAggregate` - Updated ✓ 
- [x] `GameBot.Domain.GameState` - Ensure all state operations validate guild_id ✓
- [x] `GameBot.Domain.GameModes.RaceMode` - Pass guild_id in all operations ✓
- [x] Other game modes - Pass guild_id in all operations ✓

## Game Sessions

- [x] `GameBot.GameSessions.Session` - Update to validate guild_id consistency ✓
- [x] `GameBot.GameSessions.Recovery` - Update to include guild_id in recovery process ✓

## Persistence Layer

- [x] `GameBot.Infrastructure.Persistence.EventStore.Postgres` - Filter events by guild_id ✓
- [x] `GameBot.Infrastructure.Persistence.Repo.Transaction` - Include guild context in logging ✓
- [x] Any query functions across repositories - Add guild_id filters ✓

## Projections

- [x] `GameBot.Domain.Projections.TeamProjection` - Partition data by guild_id ✓
- [x] Other projections - Add guild_id partitioning ✓

## Database Updates

- [x] Create migrations for adding proper indexes on (user_id, guild_id) for all relevant tables ✓
- [x] Create migration script to run database updates ✓
- [ ] Run migrations to update the database

## Implementation Steps (In Order)

1. **Update Event Structures** ✓
   - Add `guild_id` field to all event structs ✓
   - Update validation to require guild_id ✓
   - Update serialization/deserialization ✓

2. **Update Command Structures** ✓
   - Add `guild_id` field to all command structs ✓
   - Update validation to require guild_id ✓

3. **Update Aggregates** ✓
   - Ensure all aggregate functions validate guild_id ✓
   - Pass guild_id through all command handling ✓

4. **Update Session Management** ✓
   - Update session creation to require guild_id ✓
   - Add validation to ensure operations happen in correct guild ✓

5. **Update Projections** ✓
   - Modify projections to partition by guild_id ✓
   - Update queries to filter by guild_id ✓

6. **Update Persistence Layer** ✓
   - Add guild_id to query filters ✓
   - Include guild_id in error contexts ✓

7. **Database Migration** ✓
   - Create migrations for proper indexes ✓
   - Create migration script ✓
   - Run migrations to update the database

8. **Testing** (In Progress) ✓
   - Add tests that verify guild isolation ✓
   - Test cross-guild access attempts ✓

## Running the Migrations

To run the migrations and apply the database updates, use the following command:

```bash
mix game_bot.migrate
```

This will run all pending migrations in both the main repository and the event store, adding the necessary indexes for guild_id segregation.

## Key Guidelines

1. Every entity creation/command must include guild_id ✓
2. Every query must filter by guild_id ✓
3. All validations should check guild_id matches expected context ✓
4. All permissions should be scoped to guild ✓
5. Log guild_id with all errors for debugging ✓
6. Data cleanup/retention policies should be guild-aware ✓

The only exception is user stats that need to be aggregated across guilds, which should have their own dedicated collection/storage mechanism that explicitly allows cross-guild queries. ✓ 