# Event Migration Graph System

This document provides a detailed explanation of the graph-based event migration system used in GameBot's `EventTranslator`. The migration system allows for versioning and upgrading event data between different schema versions.

## Overview

The event migration system uses a directed graph to represent possible migration paths between different versions of event types. This graph-based approach allows for:

- Defining direct migrations between adjacent versions
- Automatically discovering paths between non-adjacent versions
- Validating that migrations are properly connected
- Efficient path finding for complex version chains

## Graph Structure

### Vertices

Each vertex in the migration graph represents a specific version of an event type:

- Vertices are represented as tuples: `{event_type, version}`
- Example: `{"player_joined", 1}`, `{"player_joined", 2}`, etc.
- A vertex exists for each registered event type and version

### Edges

Each edge in the graph represents a direct migration between two versions of the same event type:

- Edges connect from a source version to a target version
- Edges are directed (indicating one-way migration paths)
- Each edge corresponds to a registered migration function
- Example: Edge from `{"player_joined", 1}` to `{"player_joined", 2}`

### Migration Functions

Each edge in the graph is associated with a migration function that:

- Takes data in the source version format
- Returns data in the target version format
- Returns `{:ok, transformed_data}` on success
- Returns `{:error, reason}` on failure

## Implementation Details

### Graph Construction

The migration graph is built at compile time using the following process:

1. The `build_migration_graph/0` function creates a new directed graph using `:digraph`
2. Vertices are added for each event type and version from the event registry
3. Edges are added for each registered migration between versions
4. Debug information is logged during construction to aid troubleshooting

```elixir
defp build_migration_graph do
  # Create a new directed graph
  graph = Graph.new()
  
  # Add vertices for all event types and versions
  event_types = Enum.map(@event_registry, fn {type, _module, version} -> {type, version} end)
  
  # Add each vertex
  graph = Enum.reduce(event_types, graph, fn {type, max_version}, g ->
    Enum.reduce(1..max_version, g, fn version, acc_g ->
      Graph.add_vertex(acc_g, {type, version})
    end)
  end)
  
  # Add edges for migrations
  graph = Enum.reduce(@migrations, graph, fn {type, from, to, _fun}, g ->
    Graph.add_edge(g, {type, from}, {type, to})
  end)
  
  graph
end
```

### Path Finding

The system finds migration paths between versions using the following process:

1. The `find_path/3` function searches for a path between source and target versions
2. It first checks that both source and target vertices exist
3. It uses `Graph.get_shortest_path/3` to find the shortest path
4. The path is converted to migration steps using `path_to_migration_steps/2`

```elixir
defp find_path(graph, type, from_version, to_version) do
  source = {type, from_version}
  target = {type, to_version}
  
  # Check if vertices exist
  case {Graph.has_vertex?(graph, source), Graph.has_vertex?(graph, target)} do
    {false, _} -> {:error, :source_not_found}
    {_, false} -> {:error, :target_not_found}
    {true, true} ->
      # Find shortest path
      case Graph.get_shortest_path(graph, source, target) do
        nil -> {:error, :no_path}
        path -> 
          # Convert path to migration steps
          migration_steps = path_to_migration_steps(path, type)
          if Enum.empty?(migration_steps), do: {:error, :no_migrations}, else: {:ok, migration_steps}
      end
  end
end
```

### Migration Execution

Once a path is found, migrations are applied sequentially:

1. The `apply_migrations/3` function takes the event data and migration path
2. It applies each migration function in sequence
3. If any migration fails, the process is halted and an error is returned
4. On success, the fully migrated data is returned

## Registration

Migrations are registered during module definition using macros:

```elixir
# Register event types
register_event("player_joined", PlayerEvents, 3)

# Register migrations between versions
register_migration("player_joined", 1, 2, &PlayerMigrations.v1_to_v2/1)
register_migration("player_joined", 2, 3, &PlayerMigrations.v2_to_v3/1)
```

These registrations:
1. Store information in module attributes (`@event_registry` and `@migrations`)
2. Make migration functions available for the graph system
3. Define the maximum version for each event type

## Debugging

The migration system includes extensive debug logging to help troubleshoot issues:

- Graph construction is logged including vertices and edges added
- Path finding operations log the search process and results
- Migration steps are logged during execution

### Common Debugging Commands

When troubleshooting migration issues, these debug logs can help:

```
DEBUG: Event types and versions: [{"test_event", 3}, {"other_event", 2}]
DEBUG: Graph now has 5 vertices
DEBUG: Graph now has 3 edges
DEBUG: Searching for path from {"test_event", 1} to {"test_event", 3}
DEBUG: Found path: [{"test_event", 1}, {"test_event", 2}, {"test_event", 3}]
```

## Common Issues

### No Migration Path Found

If a migration fails with "No migration path found", check:

1. Verify both source and target event versions are registered
2. Confirm all intermediate migrations are registered
3. Check the graph has the expected vertices and edges
4. Confirm migration functions are properly registered

### Migration Function Errors

If a migration fails during execution:

1. Check the migration function implementation
2. Verify data format at each migration step
3. Ensure consistent key naming in migration functions
4. Add debug statements to migration functions

### Empty Graph

If the graph is empty (no vertices or edges):

1. Verify event registrations are correctly implemented
2. Check that module attribute accumulation is working
3. Ensure `@before_compile` hook is properly set up
4. Check for macro usage issues preventing registration

## Testing

The event migration system can be tested using:

1. Isolated graph tests that verify graph construction
2. Migration path tests that check path discovery
3. Full migration tests that verify data transformation
4. Error handling tests for edge cases

See `graph_test.exs` and `event_translator_test.exs` for examples of these test patterns.

## Erlang Digraph API Notes

The migration system uses Erlang's `:digraph` module which has some particular API characteristics:

- `Graph.new()` creates a new directed graph
- `Graph.add_vertex(graph, vertex)` adds a vertex
- `Graph.add_edge(graph, v1, v2)` adds a directed edge
- `Graph.vertex(graph, vertex)` checks if a vertex exists
- `Graph.get_path(graph, v1, v2)` finds a path between vertices
- `Graph.edges(graph)` returns all edges
- `Graph.no_vertices(graph)` and `Graph.no_edges(graph)` return counts

Edge data structure:
- An edge is represented as `{edge_id, from_vertex, to_vertex, label}`
- When inspecting edges, note the edge_id is the first element

## Performance Considerations

The graph is built at compile time, so there is no runtime overhead for graph construction. Path finding is very efficient as it uses Erlang's built-in graph algorithms.

For systems with many event types and versions, be mindful of:

1. Memory usage from storing the graph
2. CPU usage during complex path finding
3. Ensuring migration functions are performant for large data sets 