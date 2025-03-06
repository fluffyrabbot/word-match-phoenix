# User Statistics Strategy

## Options for Cross-Guild User Statistics

There are two main approaches to handling user statistics across multiple Discord servers (guilds):

### Option 1: Reordering Data With Guild ID Included

**Approach:**
- Store all user activity with guild_id as a field
- Query across all guilds but filter/aggregate as needed
- Use the same tables/collections but include guild_id in all records

**Pros:**
- Simpler data model with fewer tables
- Easier to maintain a single schema
- Natural queries for both guild-specific and cross-guild analytics

**Cons:**
- Potentially larger indexes
- Queries might be less efficient if not properly indexed
- More complex query logic to handle both segregated and aggregated views

### Option 2: Independent User Stats Tables

**Approach:**
- Maintain completely separate tables for user stats
- One table for guild-specific stats (with guild_id)
- Another table for global/cross-guild aggregated stats

**Pros:**
- Clean separation of concerns
- Potentially more efficient queries for specific use cases
- Simpler query logic for each specific use case

**Cons:**
- Data duplication
- Synchronization challenges between tables
- More complex schema to maintain

## Recommendation

For the GameBot application, **Option 1 (Reordering Data With Guild ID)** is likely more efficient because:

1. **Simplified Data Model**: Keeping all user data in the same table with guild_id as a field creates a simpler data model.

2. **Query Flexibility**: Modern databases handle well-indexed queries efficiently across large datasets.

3. **Reduced Maintenance**: No need to maintain synchronization between multiple tables.

4. **Scalability**: As the application grows, having a unified data model with proper indexes will scale better than managing multiple parallel data structures.

### Implementation Strategy

1. **Schema Design**:
   - Include guild_id in all user activity records
   - **Add a compound index on (user_id, guild_id) for efficient filtering** 
     *(Note: This requires a database migration - not yet implemented)*

2. **Query Patterns**:
   - For guild-specific stats: `WHERE guild_id = ?`
   - For cross-guild stats: Group by user_id without guild_id filter

3. **View Creation**:
   - Create database views for common cross-guild queries
   - Use materialized views for expensive calculations

This approach provides the best balance between data integrity, query performance, and maintenance simplicity.

## Database Implementation Tasks

The following database-level changes still need to be implemented:

1. Create a migration to add compound indexes on all user-related tables:
   ```elixir
   # Example migration (needs to be created)
   def change do
     create index(:user_stats, [:user_id, :guild_id])
     create index(:user_matches, [:user_id, :guild_id])
     # Add similar indexes to other relevant tables
   end
   ```

2. Update Ecto schemas to include guild_id validation where appropriate. 