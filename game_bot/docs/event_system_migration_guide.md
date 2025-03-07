# Event System Migration Guide

This guide provides instructions for migrating existing event modules to use the new BaseEvent behavior and related components.

## Table of Contents

1. [Overview](#overview)
2. [Benefits](#benefits)
3. [Migration Steps](#migration-steps)
4. [Example Migration](#example-migration)
5. [Testing](#testing)
6. [Troubleshooting](#troubleshooting)

## Overview

The GameBot event system has been enhanced with several new modules:

- **BaseEvent**: A behavior that standardizes event handling
- **EventRegistry**: Maps event types to their modules
- **EventStructure**: Provides validation and structure standards
- **Enhanced Metadata**: Improves causation and correlation tracking

These changes make events more consistent, provide better tracking, and simplify serialization/deserialization.

## Benefits

- **Cleaner Code**: Standard patterns for all events
- **Improved Tracing**: Track event chains with correlation/causation IDs
- **Better Validation**: Consistent validation across all events
- **Extensibility**: Easier to add new event types
- **Simplified Testing**: Standard interfaces make mocking easier

## Migration Steps

### 1. Register the Event in EventRegistry

First, make sure your event is registered in the `EventRegistry`:

```elixir
# In lib/game_bot/domain/events/event_registry.ex
@event_types %{
  # ...existing events...
  "your_event_name" => GameBot.Domain.Events.GameEvents.YourEvent
}
```

### 2. Update the Event Module

Convert the event module to use the BaseEvent behavior:

1. Replace the `@behaviour GameBot.Domain.Events.GameEvents` with `use GameBot.Domain.Events.BaseEvent`
2. Add event type and version configuration
3. Implement the required callbacks
4. Update the struct definition if needed
5. Add helper functions for creating events

### 3. Use Metadata Functions

Update any event creation to use the enhanced Metadata functions:

- `Metadata.new/2`: Create new metadata
- `Metadata.from_parent_event/2`: Create metadata for follow-up events
- `Metadata.from_discord_message/2`: Create metadata from Discord messages
- `Metadata.from_discord_interaction/2`: Create metadata from Discord interactions

## Example Migration

### Before

```elixir
defmodule GameBot.Domain.Events.GameEvents.ExampleEvent do
  @behaviour GameBot.Domain.Events.GameEvents

  @type t :: %__MODULE__{
    game_id: String.t(),
    guild_id: String.t(),
    player_id: String.t(),
    action: String.t(),
    timestamp: DateTime.t(),
    metadata: GameBot.Domain.Events.GameEvents.metadata()
  }
  defstruct [:game_id, :guild_id, :player_id, :action, :timestamp, :metadata]

  def event_type(), do: "example_event"
  def event_version(), do: 1

  def validate(%__MODULE__{} = event) do
    GameBot.Domain.Events.EventStructure.validate(event)
  end

  def to_map(%__MODULE__{} = event) do
    %{
      "game_id" => event.game_id,
      "guild_id" => event.guild_id,
      "player_id" => event.player_id,
      "action" => event.action,
      "timestamp" => DateTime.to_iso8601(event.timestamp),
      "metadata" => event.metadata
    }
  end

  def from_map(data) do
    %__MODULE__{
      game_id: data["game_id"],
      guild_id: data["guild_id"],
      player_id: data["player_id"],
      action: data["action"],
      timestamp: GameBot.Domain.Events.GameEvents.parse_timestamp(data["timestamp"]),
      metadata: data["metadata"]
    }
  end
end
```

### After

```elixir
defmodule GameBot.Domain.Events.GameEvents.ExampleEvent do
  use GameBot.Domain.Events.BaseEvent, event_type: "example_event", version: 1

  alias GameBot.Domain.Events.{Metadata, EventStructure}

  @type t :: %__MODULE__{
    game_id: String.t(),
    guild_id: String.t(),
    player_id: String.t(),
    action: String.t(),
    data: map(),
    timestamp: DateTime.t(),
    metadata: map()
  }
  defstruct [:game_id, :guild_id, :player_id, :action, :data, :timestamp, :metadata]

  @doc """
  Creates a new ExampleEvent.
  """
  def new(game_id, guild_id, player_id, action, data, metadata) do
    %__MODULE__{
      game_id: game_id,
      guild_id: guild_id,
      player_id: player_id,
      action: action,
      data: data,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }
  end

  @doc """
  Creates a new ExampleEvent from a parent event.
  """
  def from_parent(parent_event, player_id, action, data) do
    metadata = Metadata.from_parent_event(parent_event, %{actor_id: player_id})
    
    %__MODULE__{
      game_id: parent_event.game_id,
      guild_id: parent_event.guild_id,
      player_id: player_id,
      action: action,
      data: data,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }
  end

  @impl true
  def validate(event) do
    with :ok <- EventStructure.validate(event) do
      cond do
        is_nil(event.player_id) -> {:error, "player_id is required"}
        is_nil(event.action) -> {:error, "action is required"}
        is_nil(event.data) -> {:error, "data is required"}
        true -> :ok
      end
    end
  end

  @impl true
  def serialize(event) do
    Map.from_struct(event)
    |> Map.put(:timestamp, DateTime.to_iso8601(event.timestamp))
  end

  @impl true
  def deserialize(data) do
    %__MODULE__{
      game_id: data.game_id,
      guild_id: data.guild_id,
      player_id: data.player_id,
      action: data.action,
      data: data.data,
      timestamp: EventStructure.parse_timestamp(data.timestamp),
      metadata: data.metadata
    }
  end

  @impl true
  def apply(event, state) do
    # Implementation of how to apply the event to a state
    {:ok, updated_state}
  end
end
```

## Testing

1. Create a test file for your event
2. Test all common event operations:
   - Creation
   - Validation
   - Serialization/deserialization
   - Application to state (if implemented)
   - Event chaining with correlation/causation

Example test:

```elixir
defmodule GameBot.Domain.Events.GameEvents.ExampleEventTest do
  use ExUnit.Case, async: true
  
  alias GameBot.Domain.Events.GameEvents.ExampleEvent
  alias GameBot.Domain.Events.Metadata
  
  test "creates a valid event" do
    metadata = Metadata.new("source_123", %{actor_id: "player_123"})
    event = ExampleEvent.new("game_123", "guild_123", "player_123", "do_something", %{extra: "data"}, metadata)
    
    assert :ok = ExampleEvent.validate(event)
    assert event.game_id == "game_123"
    assert event.player_id == "player_123"
  end
  
  test "serializes and deserializes" do
    metadata = Metadata.new("source_123", %{actor_id: "player_123"})
    event = ExampleEvent.new("game_123", "guild_123", "player_123", "do_something", %{extra: "data"}, metadata)
    
    serialized = ExampleEvent.serialize(event)
    assert is_binary(serialized.timestamp)
    
    deserialized = ExampleEvent.deserialize(serialized)
    assert deserialized.game_id == event.game_id
    assert deserialized.player_id == event.player_id
  end
end
```

## Troubleshooting

### Common Issues

1. **Event not found in registry**
   - Ensure the event is registered in `EventRegistry`
   - Check for typos in the event type string

2. **Validation errors**
   - Ensure all required fields are set
   - Check field types match the expected types
   - Verify metadata has required fields

3. **Serialization errors**
   - Ensure your `serialize/1` function handles all fields
   - Handle special types like DateTime properly

4. **Deserialization errors**
   - Make sure `deserialize/1` properly converts string timestamps to DateTime
   - Check for missing fields in the serialized data

### Getting Help

If you encounter issues during migration, consult:
- The example event implementation
- The test suite for existing migrated events
- Documentation for each component
- The original issue descriptions and requirements 