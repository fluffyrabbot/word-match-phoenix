defmodule GameBot.Infrastructure.Persistence.EventStore.Serialization.GraphTest do
  use ExUnit.Case, async: false

  alias GameBot.Infrastructure.Persistence.EventStore.Serialization.EventTranslator
  alias GameBot.Infrastructure.Error
  alias :digraph, as: Graph

  # Define test migrations
  defmodule TestMigrations do
    def v1_to_v2(data), do: {:ok, data}
    def v2_to_v3(data), do: {:ok, data}
    def other_v1_to_v2(data), do: {:ok, data}
  end

  # Define a simple translator module that uses the EventTranslator
  defmodule SimpleTranslator do
    @migrations [
      {"test_event", 1, 2, &TestMigrations.v1_to_v2/1},
      {"test_event", 2, 3, &TestMigrations.v2_to_v3/1},
      {"other_event", 1, 2, &TestMigrations.other_v1_to_v2/1}
    ]

    @event_registry [
      {"test_event", 1},
      {"test_event", 2},
      {"test_event", 3},
      {"other_event", 1},
      {"other_event", 2}
    ]

    # Expose registered migrations for testing
    def migrations, do: @migrations
    def event_registry, do: @event_registry

    # Direct function to test graph building
    def test_build_graph do
      migrations = migrations()
      IO.puts("DEBUG: SimpleTranslator migrations: #{inspect(migrations)}")

      # Build the graph directly without using __before_compile__
      graph = Graph.new()

      # Add vertices for all event types and versions
      event_types = event_registry()
      IO.puts("DEBUG: Event types: #{inspect(event_types)}")

      # Add vertices for all event types and versions
      Enum.each(event_types, fn {type, version} ->
        vertex = {type, version}
        Graph.add_vertex(graph, vertex)
        IO.puts("DEBUG: Added vertex #{inspect(vertex)}")
      end)

      # Add edges for migrations
      Enum.each(migrations, fn {type, from_version, to_version, _migration_fn} ->
        from_vertex = {type, from_version}
        to_vertex = {type, to_version}
        edge = Graph.add_edge(graph, from_vertex, to_vertex)
        IO.puts("DEBUG: Added edge #{inspect(edge)} from #{inspect(from_vertex)} to #{inspect(to_vertex)}")
      end)

      # Print all edges for debugging
      edges = Graph.edges(graph)
      IO.puts("DEBUG: All edges in graph: #{inspect(edges)}")

      # Print graph info for debugging
      IO.puts("DEBUG: Vertices: #{inspect(Graph.vertices(graph))}")

      # Verify specific edges
      test_edge = {"test_event", 1, "test_event", 2}
      IO.puts("DEBUG: Looking for edge from test_event 1->2")
      verify_test_edge = has_edge?(graph, {"test_event", 1}, {"test_event", 2})
      IO.puts("DEBUG: Edge exists? #{inspect(verify_test_edge)}")

      graph
    end

    # Custom function to check if an edge exists between vertices
    def has_edge?(graph, v1, v2) do
      IO.puts("DEBUG: Checking edge from #{inspect(v1)} to #{inspect(v2)}")

      # Get out edges from v1
      out_edges = Graph.out_edges(graph, v1)
      IO.puts("DEBUG: Out edges for #{inspect(v1)}: #{inspect(out_edges)}")

      # Check each edge
      result = Enum.any?(out_edges, fn edge_id ->
        edge_info = Graph.edge(graph, edge_id)
        IO.puts("DEBUG: Edge info for #{inspect(edge_id)}: #{inspect(edge_info)}")

        case edge_info do
          {_edge_id, ^v1, destination, _data} ->
            IO.puts("DEBUG: Comparing #{inspect(destination)} with #{inspect(v2)}")
            destination == v2
          other ->
            IO.puts("DEBUG: Unexpected edge format: #{inspect(other)}")
            false
        end
      end)

      IO.puts("DEBUG: has_edge? result: #{inspect(result)}")
      result
    end

    # Helper function to find path for testing
    def test_find_path(type, from_version, to_version) do
      graph = test_build_graph()

      from_vertex = {type, from_version}
      to_vertex = {type, to_version}

      # Check vertices and find paths
      cond do
        # Source vertex doesn't exist
        !Graph.vertex(graph, from_vertex) ->
          {:error, %Error{
            type: :not_found,
            context: __MODULE__,
            message: "No migration path found",
            details: %{type: type, from: from_version, to: to_version}
          }}

        # Target vertex doesn't exist
        !Graph.vertex(graph, to_vertex) ->
          {:error, %Error{
            type: :not_found,
            context: __MODULE__,
            message: "No migration path found",
            details: %{type: type, from: from_version, to: to_version}
          }}

        # Both vertices exist, try to find a path
        true ->
          case Graph.get_path(graph, from_vertex, to_vertex) do
            false ->
              {:error, %Error{
                type: :not_found,
                context: __MODULE__,
                message: "No migration path found",
                details: %{type: type, from: from_version, to: to_version}
              }}

            path ->
              {:ok, path}
          end
      end
    end
  end

  describe "migration graph creation" do
    test "graph is created with correct vertices and edges" do
      graph = SimpleTranslator.test_build_graph()

      # Verify the graph has the expected number of vertices
      assert Graph.no_vertices(graph) == 5

      # Verify some specific vertices exist
      assert Graph.vertex(graph, {"test_event", 1}) != nil
      assert Graph.vertex(graph, {"test_event", 2}) != nil
      assert Graph.vertex(graph, {"test_event", 3}) != nil

      # Verify the graph has the expected number of edges
      assert Graph.no_edges(graph) == 3

      # Print all edges for debugging
      all_edges = Graph.edges(graph)
      IO.puts("DEBUG: Test - All edges: #{inspect(all_edges)}")

      # Check edges manually by iterating through all edges
      test_edges = all_edges
        |> Enum.map(fn edge_id ->
          Graph.edge(graph, edge_id)
        end)
      IO.puts("DEBUG: Test - All edge info: #{inspect(test_edges)}")

      # Directly check presence of edges
      found_test_edge_1_2 = Enum.any?(test_edges, fn
        {_edge_id, {t1, v1}, {t2, v2}, _} -> t1 == "test_event" && v1 == 1 && t2 == "test_event" && v2 == 2
        _ -> false
      end)

      found_test_edge_2_3 = Enum.any?(test_edges, fn
        {_edge_id, {t1, v1}, {t2, v2}, _} -> t1 == "test_event" && v1 == 2 && t2 == "test_event" && v2 == 3
        _ -> false
      end)

      found_other_edge_1_2 = Enum.any?(test_edges, fn
        {_edge_id, {t1, v1}, {t2, v2}, _} -> t1 == "other_event" && v1 == 1 && t2 == "other_event" && v2 == 2
        _ -> false
      end)

      # Assert edges exist
      assert found_test_edge_1_2, "Edge from test_event 1->2 not found"
      assert found_test_edge_2_3, "Edge from test_event 2->3 not found"
      assert found_other_edge_1_2, "Edge from other_event 1->2 not found"
    end

    test "path finding returns correct paths" do
      # Find a simple one-step path
      {:ok, path} = SimpleTranslator.test_find_path("test_event", 1, 2)
      assert path == [{"test_event", 1}, {"test_event", 2}]

      # Find a two-step path
      {:ok, path} = SimpleTranslator.test_find_path("test_event", 1, 3)
      assert path == [{"test_event", 1}, {"test_event", 2}, {"test_event", 3}]

      # Find a path for a different event type
      {:ok, path} = SimpleTranslator.test_find_path("other_event", 1, 2)
      assert path == [{"other_event", 1}, {"other_event", 2}]

      # Verify non-existent path
      result = SimpleTranslator.test_find_path("test_event", 3, 1)
      assert {:error, %Error{type: :not_found}} = result
    end
  end
end
