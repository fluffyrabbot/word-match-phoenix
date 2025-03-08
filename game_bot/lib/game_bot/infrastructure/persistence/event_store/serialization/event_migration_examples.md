# Event Migration Examples

This document provides practical examples of how to use the graph-based event migration system in GameBot.

## Basic Migration Setup

The following example shows how to set up a simple event translator with migrations:

```elixir
defmodule GameBot.Events.PlayerEventTranslator do
  use GameBot.Infrastructure.Persistence.EventStore.Serialization.EventTranslator

  # Register event types with their current version
  register_event("player_joined", GameBot.Events.PlayerEvents, 3)
  register_event("player_left", GameBot.Events.PlayerEvents, 2)
  
  # Register migrations for player_joined
  register_migration("player_joined", 1, 2, &PlayerMigrations.join_v1_to_v2/1)
  register_migration("player_joined", 2, 3, &PlayerMigrations.join_v2_to_v3/1)
  
  # Register migrations for player_left
  register_migration("player_left", 1, 2, &PlayerMigrations.left_v1_to_v2/1)
end

defmodule PlayerMigrations do
  # Migration from v1 to v2 for player_joined event
  def join_v1_to_v2(data) do
    # Transform data from v1 to v2 format
    {:ok, %{
      player_id: data["player_id"],
      joined_at: data["timestamp"],  # Renamed field
      metadata: %{source: "v1"}      # Additional metadata
    }}
  end
  
  # Migration from v2 to v3 for player_joined event
  def join_v2_to_v3(data) do
    # Transform data from v2 to v3 format
    {:ok, %{
      player_id: data.player_id,
      joined_at: data.joined_at,
      username: Map.get(data, :username, "unknown"),  # New field with default
      metadata: Map.get(data, :metadata, %{})
    }}
  end
  
  # Migration from v1 to v2 for player_left event
  def left_v1_to_v2(data) do
    # Transform data from v1 to v2 format
    {:ok, %{
      player_id: data["player_id"],
      left_at: data["timestamp"],
      reason: Map.get(data, "reason", "unknown")
    }}
  end
end
```

## Using the Event Translator

Here's how to use the event translator to migrate event data:

```elixir
# Migrate a player_joined event from version 1 to version 3
old_event = %{
  "type" => "player_joined",
  "version" => 1,
  "data" => %{
    "player_id" => "player123",
    "timestamp" => "2023-01-01T12:00:00Z"
  }
}

case GameBot.Events.PlayerEventTranslator.migrate("player_joined", old_event["data"], 1, 3) do
  {:ok, migrated_data} ->
    # Successfully migrated to version 3
    IO.puts("Migrated data: #{inspect(migrated_data)}")
    
  {:error, error} ->
    # Handle migration error
    IO.puts("Migration failed: #{error.message}")
end
```

## Event Migration Error Handling

Example of error handling during event migration:

```elixir
defmodule GameBot.Events.ErrorHandlingExample do
  alias GameBot.Infrastructure.Error
  
  def process_event(event) do
    event_type = Map.get(event, "type")
    event_version = Map.get(event, "version")
    event_data = Map.get(event, "data")
    
    # Get the current version for this event type
    case GameBot.Events.PlayerEventTranslator.get_version(event_type) do
      {:ok, current_version} ->
        if event_version < current_version do
          # Need to migrate the event
          case GameBot.Events.PlayerEventTranslator.migrate(
            event_type, 
            event_data, 
            event_version, 
            current_version
          ) do
            {:ok, migrated_data} ->
              # Process the migrated event
              process_migrated_event(event_type, migrated_data)
              
            {:error, %Error{type: :not_found}} ->
              # No migration path available
              {:error, :migration_path_not_found}
              
            {:error, %Error{type: :validation}} ->
              # Migration validation failed
              {:error, :invalid_event_data}
              
            {:error, error} ->
              # Other migration error
              {:error, {:migration_failed, error}}
          end
        else
          # Event is already at current version
          process_migrated_event(event_type, event_data)
        end
        
      {:error, _} ->
        # Unknown event type
        {:error, :unknown_event_type}
    end
  end
  
  defp process_migrated_event(type, data) do
    # Process the migrated event data
    {:ok, {type, data}}
  end
end
```

## Testing Migration Paths

Example of how to test the migration paths:

```elixir
defmodule GameBot.Test.MigrationTests do
  use ExUnit.Case
  
  alias GameBot.Events.PlayerEventTranslator
  
  test "migration path exists from v1 to v3 for player_joined event" do
    # Directly access the find_path function for testing
    result = PlayerEventTranslator.test_find_migration_path("player_joined", 1, 3)
    assert {:ok, path} = result
    
    # Verify we have the expected path
    assert length(path) == 2  # Two migration steps
    
    # Verify first migration step
    assert {1, 2, migration_fn_1} = Enum.at(path, 0)
    assert is_function(migration_fn_1, 1)
    
    # Verify second migration step
    assert {2, 3, migration_fn_2} = Enum.at(path, 1)
    assert is_function(migration_fn_2, 1)
  end
  
  test "migration actually transforms data" do
    # Original v1 data
    v1_data = %{"player_id" => "player123", "timestamp" => "2023-01-01T12:00:00Z"}
    
    # Migrate to v3
    {:ok, v3_data} = PlayerEventTranslator.migrate("player_joined", v1_data, 1, 3)
    
    # Verify v3 format
    assert v3_data.player_id == "player123"
    assert v3_data.joined_at == "2023-01-01T12:00:00Z"
    assert v3_data.username == "unknown"  # Default from v2 to v3 migration
    assert Map.has_key?(v3_data, :metadata)
  end
end
```

## Advanced Migration Graph

For complex event systems, you can create more sophisticated migration graphs:

```elixir
defmodule GameBot.Events.ComplexEventTranslator do
  use GameBot.Infrastructure.Persistence.EventStore.Serialization.EventTranslator

  # Register event with multiple versions
  register_event("match_result", GameBot.Events.MatchEvents, 5)
  
  # Register direct migrations between versions
  register_migration("match_result", 1, 2, &MatchMigrations.v1_to_v2/1)
  register_migration("match_result", 2, 3, &MatchMigrations.v2_to_v3/1)
  register_migration("match_result", 3, 4, &MatchMigrations.v3_to_v4/1)
  register_migration("match_result", 4, 5, &MatchMigrations.v4_to_v5/1)
  
  # Register shortcut migration (optimization for common path)
  register_migration("match_result", 1, 3, &MatchMigrations.v1_to_v3_direct/1)
  
  # Register backward compatibility migration
  register_migration("match_result", 5, 3, &MatchMigrations.v5_to_v3_backward/1)
end
```

With this setup, the migration graph would look like:

```
v1 --> v2 --> v3 --> v4 --> v5
 |      ^      ^      ^
 |      |      |      |
 +------+      |      |
        |      |      |
        +------+      |
               |      |
               +------+
```

This allows the system to find the most efficient path between any two versions.

## Debugging Migration Issues

Here's an example of how to debug migration issues:

```elixir
defmodule GameBot.Events.MigrationDebugger do
  def debug_migration_path(type, from_version, to_version) do
    IO.puts("Debugging migration path for #{type} from v#{from_version} to v#{to_version}")
    
    # Get all event types and versions
    translator = GameBot.Events.PlayerEventTranslator
    IO.puts("Event types: #{inspect(translator.event_versions())}")
    
    # Try to find the migration path
    case translator.test_find_migration_path(type, from_version, to_version) do
      {:ok, path} ->
        IO.puts("Found migration path with #{length(path)} steps:")
        Enum.with_index(path, 1) |> Enum.each(fn {{from, to, _fun}, index} ->
          IO.puts("  Step #{index}: v#{from} -> v#{to}")
        end)
        
      {:error, error} ->
        IO.puts("No migration path found: #{inspect(error)}")
        
        # Print possible reasons
        cond do
          not Map.has_key?(translator.event_versions(), type) ->
            IO.puts("Event type '#{type}' is not registered")
            
          Map.get(translator.event_versions(), type) < to_version ->
            IO.puts("Target version #{to_version} exceeds maximum version #{Map.get(translator.event_versions(), type)}")
            
          from_version <= 0 ->
            IO.puts("Source version must be greater than 0")
            
          true ->
            IO.puts("Missing migration between versions")
        end
    end
  end
end
```

Usage:

```elixir
# Debug why a specific migration is failing
GameBot.Events.MigrationDebugger.debug_migration_path("player_joined", 1, 4)
``` 