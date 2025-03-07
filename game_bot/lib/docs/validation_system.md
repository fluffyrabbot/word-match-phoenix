# Game Mode Validation System

## Overview
The validation system ensures data integrity and game rule compliance across different game modes. Each mode implements specific validation rules while sharing common validation through the BaseMode module.

## Common Validation (BaseMode)

### Team Validation
- Team count requirements (exact or minimum)
- Player count per team
- Player uniqueness
- Team ID format

### Event Validation
- Mode-specific event validation
- Required fields presence
- Field value constraints
- Metadata validation

## Knockout Mode Validation

### State Validation
- Minimum team count (2 teams)
- Team size (exactly 2 players)
- Round time limit (5 minutes)
- Maximum guess limit (12 guesses)
- Elimination thresholds
- Team status tracking

### Guess Validation
- Team existence and active status
- Player membership
- Player uniqueness
- Word restrictions
- Guess count limits
- Elimination conditions

### Event Validation
- Mode-specific fields (:knockout)
- Round completion criteria
- Elimination reasons
- Team statistics integrity
- Round duration tracking

### Elimination Validation
- Guess limit exceeded (12 guesses)
- Round time expired (5 minutes)
- Forced elimination (when >8 teams)
- Team status transitions
- Final state recording

## Race Mode Validation

### State Validation
- Time limit validation (positive integer)
- Guild ID presence
- Team positions initialization
- Match and guess count tracking

### Guess Validation
- Team existence
- Player membership
- Player uniqueness
- Give up command handling
- Word restrictions

### Event Validation
- Mode-specific fields (:race)
- Time expiry conditions
- Match count accuracy
- Team statistics integrity

## Two Player Mode Validation

### State Validation
- Single team requirement
- Round count validation
- Success threshold validation
- Completion conditions

### Guess Validation
- Team membership
- Player pairing
- Round progression
- Average guess tracking

### Event Validation
- Mode-specific fields (:two_player)
- Round completion criteria
- Success threshold compliance
- Game completion conditions

## Validation Error Types

### Common Errors
- `:invalid_team_count` - Wrong number of teams
- `:invalid_team_size` - Wrong number of players in team
- `:invalid_player` - Player not in team
- `:same_player` - Same player in multiple roles
- `:guild_mismatch` - Wrong guild context

### Knockout Mode Errors
- `:guess_limit_exceeded` - Team reached maximum guesses (12)
- `:round_time_expired` - Round time limit reached (5 minutes)
- `:team_eliminated` - Team has been eliminated
- `:invalid_elimination_reason` - Invalid reason for elimination
- `:invalid_elimination_timing` - Cannot eliminate last team
- `:invalid_round_state` - Round not properly initialized

### Race Mode Errors
- `:invalid_time_limit` - Invalid game duration
- `:missing_guild_id` - Guild ID not provided
- `:invalid_team` - Team not found
- `:word_forbidden` - Word in forbidden list

### Two Player Mode Errors
- `:invalid_rounds` - Invalid round count
- `:invalid_threshold` - Invalid success threshold
- `:round_complete` - Round already complete
- `:game_complete` - Game already complete

## Implementation Guidelines

1. Always chain validations using `with` expressions
2. Return clear, specific error messages
3. Validate at the earliest possible point
4. Include context in error messages
5. Use type specs and guard clauses
6. Document all validation functions

## Testing Strategy

1. Test all validation paths
2. Include edge cases
3. Test error messages
4. Verify error types
5. Test validation chains
6. Cover all game states

## Knockout Mode Testing Specifics

### State Tests
1. Team count validation
2. Team size validation
3. Round time tracking
4. Guess limit tracking
5. Elimination conditions

### Guess Tests
1. Team existence checks
2. Player membership
3. Guess limit enforcement
4. Word validation
5. Elimination triggers

### Round Tests
1. Time expiry handling
2. Forced eliminations
3. Team advancement
4. Round transitions
5. Game completion

### Event Tests
1. Mode-specific validation
2. Required fields
3. Elimination events
4. Round completion
5. Game completion 