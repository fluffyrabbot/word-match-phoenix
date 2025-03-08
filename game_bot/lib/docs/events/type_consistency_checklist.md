# Event Type Consistency Checklist

## Files to Check

### Core Event Files
- [x] `lib/game_bot/domain/events/event_structure.ex`
  - [x] Base type definitions
    - Removed round_number from base fields
    - Added proper type specs for all functions
    - Added clear type definitions for common structures
  - [x] Common types
    - Updated metadata type to match documentation
    - Added player_info type with proper fields
    - Added team_info type with numeric specifications
    - Added player_stats type with proper constraints
  - [x] Base field validations
    - Added ID field validation
    - Added timestamp validation
    - Added mode validation
    - Improved metadata validation
  - [x] Serialization
    - Added proper type specs
    - Improved nested structure handling
    - Enhanced error handling
    - Added proper DateTime handling

- [x] `lib/game_bot/domain/events/event_validator.ex`
  - [x] Protocol specifications
    - Added @type validation_error
    - Added @spec for validate/1
    - Updated callback return types
  - [x] Documentation
    - Added comprehensive module docs
    - Added detailed function docs
    - Added implementation examples
  - [x] Validation requirements
    - Clarified base field requirements
    - Added type validation requirements
    - Added numeric constraints
    - Added nested structure validation

- [x] `lib/game_bot/domain/events/event_serializer.ex`
  - [x] Protocol specifications
    - Added @type serialized_event
    - Added @spec for both functions
    - Clarified return types
  - [x] Documentation
    - Added comprehensive module docs
    - Added serialization rules
    - Added implementation examples
  - [x] Serialization rules
    - Added DateTime handling rules
    - Added atom conversion rules
    - Added complex type handling
    - Added type preservation rules
  - [x] Error handling
    - Added error handling guidance
    - Specified error conditions
    - Added validation requirements

### Event Definition Files
- [x] `lib/game_bot/domain/events/game_events.ex`
  - [x] GuessProcessed
    - [x] Type specifications match documentation
    - [x] Proper use of common types
    - [x] Validation matches type specs
    - [x] Serialization/deserialization type safety
  - [x] GuessAbandoned
    - [x] Type specifications match documentation
    - [x] Proper use of common types
    - [x] Validation matches type specs
    - [x] Serialization/deserialization type safety
  - [x] GameStarted
    - [x] Type specifications match documentation
    - [x] Proper use of common types
    - [x] Validation matches type specs
    - [x] Serialization/deserialization type safety
  - [x] GameCompleted
    - [x] Type specifications match documentation
    - [x] Proper use of common types
    - [x] Validation matches type specs
    - [x] Serialization/deserialization type safety
  - [x] RoundStarted
    - [x] Type specifications match documentation
    - [x] Proper use of common types
    - [x] Validation matches type specs
    - [x] Serialization/deserialization type safety
  - [x] RoundCompleted
    - [x] Type specifications match documentation
    - [x] Proper use of common types
    - [x] Validation matches type specs
    - [x] Serialization/deserialization type safety
  - [x] TeamEliminated
    - [x] Type specifications match documentation
    - [x] Proper use of common types
    - [x] Validation matches type specs
    - [x] Serialization/deserialization type safety

### Error Event Files
- [x] `lib/game_bot/domain/events/error_events.ex`
  - [x] GuessError
    - Added guild_id field
    - Defined specific reason type
    - Enhanced validation with pattern matching
    - Added @impl annotations
    - Improved documentation
  - [x] GuessPairError
    - Added guild_id field
    - Defined specific reason type
    - Added validation for same words
    - Added @impl annotations
    - Improved documentation
  - [x] RoundCheckError
    - Added guild_id field
    - Defined specific reason type
    - Enhanced validation
    - Added @impl annotations
    - Improved documentation

### Test Files
- [x] `test/game_bot/domain/events/event_structure_test.exs`
  - [x] Base field validation tests
  - [x] Type validation tests
  - [x] Metadata validation tests
  - [x] Serialization helper tests
  - [x] Error handling tests

- [x] `test/game_bot/domain/events/event_validator_test.exs`
  - [x] Protocol implementation tests
  - [x] Base field validation tests
  - [x] Event-specific validation tests
  - [x] Optional field handling tests
  - [x] Error message tests

- [x] `test/game_bot/domain/events/event_serializer_test.exs`
  - [x] Protocol implementation tests
  - [x] Base field serialization tests
  - [x] Complex type serialization tests
  - [x] Nested structure tests
  - [x] Error handling tests

- [ ] `test/game_bot/domain/events/game_events_test.exs`
  - [ ] Event-specific validation tests
  - [ ] Event-specific serialization tests
  - [ ] Event version tests
  - [ ] Event type tests
  - [ ] Error handling tests

- [ ] `test/game_bot/domain/events/error_events_test.exs`
  - [ ] Error event validation tests
  - [ ] Error event serialization tests
  - [ ] Error reason validation tests
  - [ ] Error message format tests

## Common Issues to Check

### Type Specifications
- [x] Use of `pos_integer()` vs `non_neg_integer()` vs `integer()`
- [x] Proper use of `metadata()` type
- [x] Proper use of `player_info()` type
- [x] Proper use of `team_info()` type
- [x] Proper use of `player_stats()` type
- [x] Consistent use of `String.t()` for IDs
- [x] Proper marking of optional fields with `| nil`

### Validations
- [x] Required field checks match type specs
- [x] Numeric validations match type specs
- [x] Proper validation of optional fields
- [x] Consistent error message format
- [x] Proper validation of nested structures

### Serialization
- [x] Proper handling of DateTime serialization
- [x] Proper handling of atom serialization
- [x] Proper handling of optional fields
- [x] Proper handling of nested structures

## Progress

### Completed Files
1. ✅ `event_structure.ex`
   - Removed round_number from base fields
   - Added proper type specifications
   - Improved validation functions
   - Enhanced serialization
   - Added comprehensive documentation

2. ✅ `event_validator.ex`
   - Added validation_error type
   - Added proper type specifications
   - Improved documentation
   - Added validation requirements
   - Added implementation examples

3. ✅ `event_serializer.ex`
   - Added serialized_event type
   - Added proper type specifications
   - Added serialization rules
   - Added error handling guidance
   - Added comprehensive documentation
   - Added implementation examples

4. ✅ `game_events.ex`
   - All events updated and validated
   - Type specifications match documentation
   - Proper validation implemented

5. ✅ `error_events.ex`
   - All error events updated
   - Added guild_id field
   - Improved validation

### In Progress
- [ ] Currently checking: Test files

### Findings and Issues
1. GuessProcessed:
   - Fixed: Changed `integer()` to `pos_integer()` for round_number
   - Fixed: Changed `map()` to `player_info()` for player info types
   - Fixed: Added match_score validation
   - Fixed: Added type checking in numeric validations

2. GuessAbandoned:
   - Fixed: Changed from `@behaviour` to `use EventStructure`
   - Fixed: Changed `integer() | nil` to `non_neg_integer() | nil` for guess_duration
   - Fixed: Added validation for last_guess structure
   - Fixed: Added type checking in numeric validations
   - Fixed: Added validation for reason enum

3. GameStarted:
   - Fixed: Changed from `@behaviour` to `use EventStructure`
   - Fixed: Added validation for round_number being 1
   - Fixed: Added comprehensive team and role validation
   - Fixed: Added DateTime validation for started_at
   - Fixed: Fixed round_number handling in serialization

4. GameCompleted:
   - Fixed: Changed from `@behaviour` to `use EventStructure`
   - Fixed: Added proper numeric types for counts
   - Fixed: Added comprehensive nested structure validation
   - Fixed: Added proper DateTime validation
   - Fixed: Added validation for winners and scores
   - Fixed: Added type definitions for nested structures

5. RoundStarted:
   - Fixed: Changed from `@behaviour` to `use EventStructure`
   - Fixed: Added proper numeric types for counts
   - Fixed: Added team_state type definition
   - Fixed: Added comprehensive validation for team states
   - Fixed: Added validation for player lists
   - Fixed: Added proper type checking for all fields

6. RoundCompleted:
   - Fixed: Changed from `@behaviour` to `use EventStructure`
   - Fixed: Added round_stats type definition
   - Fixed: Changed to proper numeric types for counts
   - Fixed: Added comprehensive validation for stats
   - Fixed: Added validation for winner_team_id
   - Fixed: Added proper type checking for all fields

7. TeamEliminated:
   - Fixed: Changed from `@behaviour` to `use EventStructure`
   - Fixed: Added proper numeric types for counts
   - Fixed: Added type definitions for nested structures
   - Fixed: Added validation for elimination reasons
   - Fixed: Added missing guild_id field
   - Fixed: Added comprehensive validation for all structures
   - Fixed: Added proper type checking for all fields

### Next Steps
1. Create test cases for event_structure.ex
2. Create test cases for event_validator.ex
3. Create test cases for event_serializer.ex
4. Update existing test files to match new specifications

## Notes
- Base fields are now consistent across all events
- Type specifications are more precise
- Validation is more comprehensive
- Documentation is clearer and more detailed
- Error handling is standardized
- Protocol implementations are better guided
- Serialization rules are well-defined
- Test coverage needs to be updated

## Test Requirements

### 1. Base Test Requirements
- All test files must:
  - Use `async: true` for concurrent testing
  - Include comprehensive docstrings
  - Follow consistent naming conventions
  - Use descriptive test names
  - Group related tests in describes

### 2. Event Test Structure
```elixir
describe "event_type/0" do
  test "returns correct event type string"
end

describe "event_version/0" do
  test "returns correct version number"
end

describe "validate/1" do
  test "validates valid event"
  test "validates required fields"
  test "validates field types"
  test "validates numeric constraints"
  test "validates nested structures"
  test "validates optional fields"
end

describe "to_map/1" do
  test "serializes all fields correctly"
  test "handles complex types"
  test "handles optional fields"
end

describe "from_map/1" do
  test "deserializes all fields correctly"
  test "reconstructs complex types"
  test "handles missing optional fields"
end

describe "error handling" do
  test "handles invalid field values"
  test "provides descriptive error messages"
end
```

### 3. Test Coverage Requirements
- Base field validation: 100%
- Type validation: 100%
- Error handling: 100%
- Serialization: 100%
- Edge cases: 100%

### 4. Test Helper Requirements
- Create valid test events
- Create invalid test events
- Create test metadata
- Create test timestamps
- Handle complex test data 