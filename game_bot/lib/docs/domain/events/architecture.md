# Event Architecture

## Overview

The event system is built on a robust architecture using Elixir's powerful macro system and Ecto's schema capabilities. It provides a consistent, type-safe, and maintainable way to define and handle events throughout the application.

## Core Components

### BaseEvent Module

```elixir
defmodule GameBot.Domain.Events.BaseEvent do
  # Base fields that all events must have
  @base_fields [
    :game_id,
    :guild_id,
    :mode,
    :round_number,
    :timestamp,
    :metadata
  ]

  # Required fields for all events
  @base_required_fields [
    :game_id,
    :guild_id,
    :mode,
    :round_number,
    :timestamp
  ]
end
```

The BaseEvent module provides:
- Common field definitions
- Shared validation logic
- Serialization capabilities
- Metadata handling
- Type specifications

### Event Definition Pattern

Events are defined using the `use GameBot.Domain.Events.BaseEvent` macro:

```elixir
use GameBot.Domain.Events.BaseEvent,
  event_type: "event_name",
  version: 1,
  fields: [
    field(:custom_field, :type)
    # Additional fields...
  ]
```

### Validation Chain

1. Base field validation
2. Required field validation
3. Metadata validation
4. Custom field validation

## Implementation Guidelines

### 1. Event Module Structure

```elixir
defmodule MyEvent do
  use GameBot.Domain.Events.BaseEvent,
    event_type: "my_event",
    version: 1,
    fields: [...]

  @impl true
  def required_fields do
    GameBot.Domain.Events.BaseEvent.base_required_fields() ++ [
      # Additional required fields
    ]
  end

  @impl true
  def validate_custom_fields(changeset) do
    super(changeset)
    |> validate_custom_logic()
  end
end
```

### 2. Field Definition Best Practices

- Use explicit types
- Group related fields
- Document constraints
- Provide default values when appropriate

### 3. Validation Rules

- Always call `super(changeset)` in custom validation
- Use Ecto's built-in validators
- Add custom validation functions for complex rules
- Validate related fields together

### 4. Type Safety

- Use specific types instead of generic ones
- Define comprehensive @type specs
- Document field relationships
- Use Ecto's type system

## Event Lifecycle

1. **Creation**
   - Event struct created with required fields
   - Timestamp automatically added
   - Metadata validated

2. **Validation**
   - Base fields checked
   - Required fields verified
   - Custom validation rules applied
   - Metadata structure validated

3. **Serialization**
   - Event converted to map format
   - Timestamps formatted
   - Custom field handling

4. **Processing**
   - Event validated
   - Business logic applied
   - State updates performed
   - Side effects executed

## Best Practices

### DO
- Use the `fields` option in `use BaseEvent`
- Override `required_fields/0` for custom requirements
- Implement custom validation in `validate_custom_fields/1`
- Document field constraints and relationships
- Use proper type specifications

### DON'T
- Define schema directly in event modules
- Skip calling `super` in overridden functions
- Hardcode base field lists
- Implement custom serialization without need

## Error Prevention

1. **Schema Conflicts**
   - Use `fields` option only
   - Let BaseEvent handle schema
   - Avoid direct schema definitions

2. **Validation Chain**
   - Maintain proper order
   - Call super in overrides
   - Handle all error cases

3. **Field Access**
   - Use BaseEvent helper functions
   - Avoid direct field access
   - Validate field presence

## Testing

1. **Required Tests**
   - Valid event creation
   - Field validation
   - Custom validation rules
   - Serialization roundtrip

2. **Test Cases**
   - Happy path
   - Missing required fields
   - Invalid field values
   - Edge cases

## Example Implementation

```elixir
defmodule GameBot.Domain.Events.GameEvents.GuessProcessed do
  use GameBot.Domain.Events.BaseEvent,
    event_type: "guess_processed",
    version: 1,
    fields: [
      field(:team_id, :string),
      field(:player1_info, :map),
      # ... additional fields
    ]

  @impl true
  def required_fields do
    GameBot.Domain.Events.BaseEvent.base_required_fields() ++ [
      :team_id,
      :player1_info,
      # ... additional required fields
    ]
  end

  @impl true
  def validate_custom_fields(changeset) do
    super(changeset)
    |> validate_number(:guess_count, greater_than: 0)
    # ... additional validation
  end
end
```

## Migration Guide

When converting existing events to use this architecture:

1. Replace direct schema definitions with `use BaseEvent`
2. Move custom fields to the `fields` option
3. Implement required callbacks
4. Update validation logic
5. Remove redundant serialization code
6. Update tests to match new structure

## Future Considerations

- Event versioning strategy
- Schema evolution
- Performance optimization
- Additional validation rules
- Extended metadata support 