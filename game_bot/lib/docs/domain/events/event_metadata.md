# Event Metadata System

## Overview

Event metadata is a critical component of GameBot's event system, providing context and tracking capabilities for all events. Metadata enables auditing, debugging, correlation tracking, and causation chain analysis, making it an essential part of the event-sourced architecture.

## Metadata Structure

Each event in the system includes a metadata field with the following structure:

```elixir
@type t :: %{
  optional(:guild_id) => String.t(),          # Optional to support DMs
  required(:source_id) => String.t(),         # Source identifier (message/interaction ID)
  required(:correlation_id) => String.t(),    # For tracking related events
  optional(:causation_id) => String.t(),      # ID of event that caused this event
  optional(:actor_id) => String.t(),          # User who triggered the action
  optional(:client_version) => String.t(),    # Client version
  optional(:server_version) => String.t(),    # Server version
  optional(:user_agent) => String.t(),        # Client agent info
  optional(:ip_address) => String.t()         # IP address (for security)
}
```

## Core Components

### `Metadata` Module

The `GameBot.Domain.Events.Metadata` module provides functions for:

1. Creating metadata from various sources
2. Validating metadata structures
3. Tracking causation and correlation
4. Normalizing metadata formats

```elixir
defmodule GameBot.Domain.Events.Metadata do
  # Type definitions
  # Function implementations for metadata manipulation
end
```

## Key Functions

### Creating Metadata

#### From Arguments

```elixir
# Basic creation with minimum required fields
{:ok, metadata} = Metadata.new("source-123", correlation_id: "corr-456")

# Creating with a complete map
{:ok, metadata} = Metadata.new(%{
  source_id: "msg-123",
  guild_id: "guild-456",
  actor_id: "user-789",
  correlation_id: "corr-abc"
})
```

#### From Discord Interactions

```elixir
# From a Discord message
{:ok, metadata} = Metadata.from_discord_message(message)

# From a Discord interaction (slash command, button)
{:ok, metadata} = Metadata.from_discord_interaction(interaction)
```

#### From Parent Events

```elixir
# Generate child event metadata with correlation tracking
{:ok, child_metadata} = Metadata.from_parent_event(parent_metadata)
```

### Tracking Causation

```elixir
# Add causation information to metadata
updated_metadata = Metadata.with_causation(metadata, causing_event)
```

### Validation

```elixir
# Validate metadata structure
:ok = Metadata.validate(metadata)
```

## Use Cases

### Audit Trails

Metadata enables comprehensive audit trails:

```elixir
# Query events by actor
events = EventStore.query_events(actor_id: "user-123")

# Create reports of user actions
audit_report = events
  |> Enum.map(&{&1.metadata.actor_id, &1.metadata.timestamp, &1.type})
  |> generate_report()
```

### Correlation Tracking

Tracking related events through correlation IDs:

```elixir
# Find all events in the same logical operation
correlated_events = EventStore.query_events(correlation_id: "corr-abc")

# Reconstruct a complete operation from events
operation_events = correlated_events |> Enum.sort_by(&(&1.timestamp))
```

### Causation Chains

Following chains of cause and effect:

```elixir
# Find the event that caused this event
{:ok, causing_event} = EventStore.find_event(event.metadata.causation_id)

# Build a causation tree
causation_tree = build_causation_tree(root_event)
```

### Debugging

Using metadata for troubleshooting:

```elixir
# Find events from a specific Discord message
message_events = EventStore.query_events(source_id: "msg-123")

# Trace an event's origin
event_origin = trace_event_origin(event)
```

## Implementation Details

### Creation Process

1. **Input Normalization**: Converts string keys to atoms where possible
2. **Default Value Generation**: Adds defaults for required fields
3. **Validation**: Checks for required fields and proper formats
4. **Result**: Returns `{:ok, metadata}` or `{:error, reason}`

### Validation Logic

Metadata validation ensures:

1. **Source ID Presence**: Every event must have a source identifier
2. **Correlation ID Presence**: Every event must have a correlation ID
3. **Type Correctness**: Fields must have the correct types

### Normalization

Metadata normalization handles:

1. **String/Atom Keys**: Converting between string and atom keys
2. **Nil Values**: Removing nil values from the map
3. **String Conversion**: Ensuring IDs are stored as strings

## Best Practices

### Creating Metadata

1. **Always include source information**: Where did this event originate?
2. **Preserve correlation IDs**: Keep the correlation ID when creating child events
3. **Add causation when appropriate**: Link events in cause-effect chains
4. **Include actor information**: Who triggered this event?

### Using Metadata

1. **Query by metadata fields**: Use metadata for finding related events
2. **Build audit trails**: Use actor_id and timestamp for auditing
3. **Trace problems**: Use correlation_id to find related events
4. **Monitor versions**: Track client and server versions for debugging

## Edge Cases and Error Handling

### Missing Fields

When required fields are missing:

```elixir
{:error, :missing_field} = Metadata.new(%{}) # Missing source_id
```

### Type Errors

When fields have incorrect types:

```elixir
{:error, :invalid_type} = Metadata.validate(123) # Not a map
```

### String/Atom Key Conversion

Handling string and atom keys transparently:

```elixir
{:ok, metadata1} = Metadata.new(%{source_id: "abc"})
{:ok, metadata2} = Metadata.new(%{"source_id" => "abc"})
# metadata1 and metadata2 are functionally equivalent
```

## Testing

The metadata system includes comprehensive tests:

```elixir
# Test metadata creation
test "creates metadata from source_id" do
  {:ok, metadata} = Metadata.new("source-123", [])
  assert metadata.source_id == "source-123"
  assert is_binary(metadata.correlation_id)
end

# Test validation
test "validates required fields" do
  assert {:error, :missing_field} = Metadata.validate(%{})
end
```

## Future Enhancements

1. **Enhanced Security**: Adding more security context (IP ranges, device info)
2. **Rich Analytics**: Additional fields for analytics purposes
3. **User Context**: More information about the user context when event occurred
4. **Environment Tracking**: Track test vs. production environments
5. **Extended Validation**: More sophisticated validation rules

## Troubleshooting

### Common Issues

1. **Missing correlation**: Events not properly correlated
2. **Missing causation**: Causation chains broken
3. **Invalid source IDs**: Source IDs not properly generated
4. **String vs. atom keys**: Inconsistent key formats

### Debugging Techniques

1. Inspect raw metadata maps
2. Check correlation ID generation
3. Verify Discord message/interaction extraction
4. Test parent-child metadata inheritance 