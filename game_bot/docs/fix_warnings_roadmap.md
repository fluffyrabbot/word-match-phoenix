# Warning Fix Roadmap

## Phase 1: Critical Type and Function Fixes

### Event Struct Fields
- [x] Add missing `team_ids` field to GameCreated event
- [x] Add missing `started_at` field to GameStarted event
- [x] Add missing `finished_at` field to GameFinished event (already existed)
- [x] Add missing `guild_id` field to RoundStarted event
- [ ] Update all event tests to include new fields

### Event Creation Functions
- [x] Implement `GuessError.new/5`
- [x] Implement `RoundCheckError.new/2`
- [x] Implement `GameFinished.new/4` (already existed)
- [x] Implement `GuessPairError.new/5`
- [ ] Add tests for all new event creation functions

### EventStore Integration
- [x] Fix EventStore module imports and aliases
- [x] Implement missing EventStore callbacks
- [x] Add proper error handling for EventStore operations
- [ ] Add tests for EventStore operations

## Phase 2: Behaviour Implementation

### EventStore Behaviour Conflicts
- [x] Add @impl true annotations to all EventStore callbacks
- [x] Resolve conflicting behaviour implementations (removed duplicate behaviour)
- [x] Ensure proper error handling in callbacks
- [ ] Add tests for behaviour implementations

### TestEventStore Implementation
- [x] Implement `ack/2`
- [x] Implement `config/0`
- [x] Implement stream management functions
- [x] Implement subscription management functions
- [ ] Add tests for TestEventStore

## Phase 3: Deprecation Fixes

### Logger Updates
- [x] Replace Logger.warn in transaction module
- [x] Replace Logger.warn in event store adapter
- [x] Replace Logger.warn in game sessions recovery
- [x] Replace Logger.warn in other modules
- [x] Update log message formatting with proper context
- [x] Verify log levels are appropriate

### Nostrum API Updates
- [x] Update `create_message/2` to `Message.create/2` in listener module
- [x] Update `create_message/2` to `Message.create/2` in dispatcher module
- [x] Test message creation in development environment
- [x] Add error handling for API calls

## Phase 4: Code Organization

### Function Grouping
- [ ] Group `handle_event/1` implementations
- [ ] Group `handle_event/2` implementations
- [ ] Organize related functions together
- [ ] Add section comments for clarity

### Function Definition Fixes
- [x] Fix `subscribe_to_stream/4` definition
- [x] Update function heads with proper default parameters
- [x] Ensure consistent function ordering
- [ ] Add typespecs to functions

## Phase 5: Cleanup

### Unused Variable Fixes
- [ ] Add underscore prefix to unused variables in game projection
- [ ] Add underscore prefix to unused variables in command handlers
- [ ] Add underscore prefix to unused variables in event handlers
- [ ] Review and document intentionally unused variables

### Unused Alias Cleanup
- [ ] Remove unused aliases from game modes
- [ ] Remove unused aliases from event store
- [ ] Remove unused aliases from command handlers
- [ ] Update documentation to reflect removed aliases

## Testing and Deployment

### Testing
- [ ] Create baseline test suite
- [ ] Add tests for each phase
- [ ] Create integration tests
- [ ] Set up CI/CD pipeline

### Deployment
- [ ] Create feature flags
- [ ] Plan deployment schedule
- [ ] Create rollback procedures
- [ ] Set up monitoring

## Progress Tracking

### Completed Items
- Created error events module with GuessError, GuessPairError, and RoundCheckError
- Added missing fields to GameCreated, GameStarted, and RoundStarted events
- Updated Session module to use new error events
- Implemented all missing EventStore behaviour callbacks
- Fixed function definitions with default parameters
- Added proper @impl annotations
- Removed conflicting behaviour implementation
- Implemented complete TestEventStore with all required callbacks
- Added in-memory event storage and subscription management to TestEventStore
- Updated Logger.warn to Logger.warning in transaction module
- Updated Logger.warn to Logger.warning in event store adapter
- Updated Logger.warn to Logger.warning in game sessions recovery
- Updated Nostrum.Api.create_message to Nostrum.Api.Message.create in listener and dispatcher modules
- Added proper error handling for Nostrum API calls with logging
- Completed all Logger deprecation fixes with proper context

### In Progress
- Test coverage for new events and EventStore operations
- Function grouping and organization

### Blocked Items
- None

### Notes
- The GameFinished event already had all required fields
- Some event store fixes may require coordination with the EventStore library maintainers
- Need to verify all event fields are being properly used in projections
- Added all missing EventStore behaviour callbacks to ensure proper implementation
- Removed duplicate behaviour implementation to resolve conflicts
- All EventStore functions now have proper default parameters and @impl annotations
- TestEventStore implementation uses GenServer for proper state management
- TestEventStore provides in-memory event storage and subscription management
- Next focus should be on implementing comprehensive tests for all components
- Logger.warn deprecation fixes are being done module by module to ensure proper context is maintained
- All critical Logger.warn usages have been updated to Logger.warning
- Nostrum API deprecation fixes have been completed for message creation
- Added proper error handling for Nostrum API calls with structured logging
- All Logger calls now include proper context for better debugging 