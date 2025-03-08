defmodule GameBot.Infrastructure.Persistence.EventStore.Serialization.EventTranslator do
  @moduledoc """
  Handles event translation and version mapping between different event versions.

  This module provides a system for:
  - Registering event types and their versions
  - Mapping between different versions of events
  - Finding migration paths between versions
  - Applying migrations to event data

  It uses a directed graph approach to represent migration paths between different
  versions of the same event type.
  """

  alias GameBot.Infrastructure.Error
  alias :digraph, as: Graph

  @doc """
  Register an event type with its module and current version.
  """
  defmacro register_event(type, module, version) do
    quote do
      @event_registry {unquote(type), unquote(module), unquote(version)}
    end
  end

  @doc """
  Register a migration function between two versions of an event type.
  """
  defmacro register_migration(type, from_version, to_version, fun) do
    quote do
      @migrations {unquote(type), unquote(from_version), unquote(to_version), unquote(fun)}
    end
  end

  defmacro __using__(_opts) do
    quote do
      import GameBot.Infrastructure.Persistence.EventStore.Serialization.EventTranslator,
        only: [register_event: 3, register_migration: 4]

      @before_compile GameBot.Infrastructure.Persistence.EventStore.Serialization.EventTranslator

      # Register module attributes with accumulate: true to properly collect multiple registrations
      Module.register_attribute(__MODULE__, :event_registry, accumulate: true)
      Module.register_attribute(__MODULE__, :migrations, accumulate: true)

      # Fix: Add Erlang :digraph alias to each using module as well
      alias :digraph, as: Graph
      alias GameBot.Infrastructure.Error

      @doc """
      Looks up the module for a given event type.
      """
      @spec lookup_module(String.t()) :: {:ok, module()} | {:error, Error.t()}
      def lookup_module(type) do
        case Enum.find(event_modules(), fn {t, _module} -> t == type end) do
          {^type, module} -> {:ok, module}
          nil -> {:error, Error.not_found_error(__MODULE__, "Unknown event type", type)}
        end
      end

      @doc """
      Gets the current version for an event type.
      """
      @spec get_version(String.t()) :: {:ok, pos_integer()} | {:error, Error.t()}
      def get_version(type) do
        case Enum.find(event_versions(), fn {t, _version} -> t == type end) do
          {^type, version} -> {:ok, version}
          nil -> {:error, Error.not_found_error(__MODULE__, "Unknown event type", type)}
        end
      end

      @doc """
      Migrates event data from one version to another.
      """
      @spec migrate(String.t(), map(), pos_integer(), pos_integer()) ::
              {:ok, map()} | {:error, Error.t()}
      def migrate(type, data, from_version, to_version) do
        cond do
          from_version == to_version ->
            {:ok, data}

          from_version > to_version ->
            {:error,
             Error.validation_error(__MODULE__, "Cannot migrate to older version", %{
               type: type,
               from: from_version,
               to: to_version
             })}

          true ->
            do_migrate(type, data, from_version, to_version)
        end
      end

      # Internal function to handle the migration process
      defp do_migrate(type, data, from_version, to_version) do
        case find_migration_path(type, from_version, to_version) do
          {:ok, path} -> apply_migrations(type, data, path)
          {:error, reason} -> {:error, reason}
        end
      end

      @doc """
      Find a migration path between two versions of an event type.

      Used internally by migrate/4 but also exposed for testing.
      """
      def find_migration_path(type, from_version, to_version) do
        # Build the migration graph
        graph = build_migration_graph()

        # Define source and target vertices
        source = {type, from_version}
        target = {type, to_version}

        # Check if both vertices exist
        cond do
          not Graph.vertex(graph, source) ->
            IO.puts("Source vertex not found: #{inspect(source)}")
            IO.puts("Graph has vertices: #{inspect(Graph.vertices(graph))}")

            {:error,
             Error.not_found_error(__MODULE__, "No migration path found", %{
               type: type,
               from: from_version,
               to: to_version,
               reason: :source_not_found
             })}

          not Graph.vertex(graph, target) ->
            IO.puts("Target vertex not found: #{inspect(target)}")
            IO.puts("Graph has vertices: #{inspect(Graph.vertices(graph))}")

            {:error,
             Error.not_found_error(__MODULE__, "No migration path found", %{
               type: type,
               from: from_version,
               to: to_version,
               reason: :target_not_found
             })}

          true ->
            # Find path using safer approach
            case find_path_dfs(graph, source, target, []) do
              {:ok, path} ->
                # Convert path to migration steps
                migration_steps = path_to_migration_steps(path)

                if Enum.empty?(migration_steps) do
                  {:error,
                   Error.not_found_error(__MODULE__, "No migration path found", %{
                     type: type,
                     from: from_version,
                     to: to_version,
                     reason: :no_migrations
                   })}
                else
                  {:ok, migration_steps}
                end

              :error ->
                {:error,
                 Error.not_found_error(__MODULE__, "No migration path found", %{
                   type: type,
                   from: from_version,
                   to: to_version,
                   reason: :no_path
                 })}
            end
        end
      end

      # Depth-first search algorithm to find a path between two vertices
      defp find_path_dfs(graph, source, target, visited) do
        if source == target do
          {:ok, [source]}
        else
          visited = [source | visited]

          edges = Graph.out_edges(graph, source)

          Enum.reduce_while(edges, :error, fn edge, _acc ->
            {_, _, dest_vertex, _} = Graph.edge(graph, edge)

            if Enum.member?(visited, dest_vertex) do
              {:cont, :error}
            else
              case find_path_dfs(graph, dest_vertex, target, visited) do
                {:ok, path} -> {:halt, {:ok, [source | path]}}
                :error -> {:cont, :error}
              end
            end
          end)
        end
      end

      # Convert a path of vertices to migration steps with functions
      defp path_to_migration_steps(path) do
        path
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [{type, v1}, {type, v2}] ->
          case get_migration_fun(type, v1, v2) do
            nil -> nil
            fun -> {v1, v2, fun}
          end
        end)
        |> Enum.reject(&is_nil/1)
      end

      # Find the migration function for a specific edge
      defp get_migration_fun(type, from, to) do
        case Enum.find(event_migrations(), fn
               {^type, ^from, ^to, _fun} -> true
               _ -> false
             end) do
          {_type, _from, _to, fun} -> fun
          nil -> nil
        end
      end

      @doc """
      Apply a series of migration functions to event data.

      Used internally by migrate/4 but also exposed for testing.
      """
      def apply_migrations(_type, data, []), do: {:ok, data}

      def apply_migrations(type, data, [{from, to, fun} | rest]) do
        case fun.(data) do
          {:ok, migrated} -> apply_migrations(type, migrated, rest)
          {:error, reason} ->
            {:error,
             Error.validation_error(__MODULE__, "Migration failed", %{
               type: type,
               from: from,
               to: to,
               reason: reason
             })}
        end
      end

      # Build a directed graph representing all possible migrations
      defp build_migration_graph do
        # Create a new digraph
        graph = Graph.new()

        registry = event_modules()
        versions = event_versions()
        migrations = event_migrations()

        # Log info for debugging
        IO.puts("Building graph with:")
        IO.puts("  Event registry: #{inspect(registry)}")
        IO.puts("  Versions: #{inspect(versions)}")
        IO.puts("  Migrations: #{inspect(migrations)}")

        # Add vertices for all event versions
        Enum.each(versions, fn {type, max_version} ->
          # Add vertex for each version from 1 to max_version
          Enum.each(1..max_version, fn version ->
            IO.puts("  Adding vertex: {#{type}, #{version}}")
            vertex = {type, version}
            Graph.add_vertex(graph, vertex)
          end)
        end)

        # Add edges for all migrations
        Enum.each(migrations, fn {type, from, to, _fun} ->
          # Add edge between versions
          IO.puts("  Adding edge: {#{type}, #{from}} -> {#{type}, #{to}}")
          source = {type, from}
          target = {type, to}
          Graph.add_edge(graph, source, target)
        end)

        # Log resulting graph
        vertices = Graph.vertices(graph)
        edges = Graph.edges(graph)
        IO.puts("Graph has #{length(vertices)} vertices: #{inspect(vertices)}")
        IO.puts("Graph has #{length(edges)} edges: #{inspect(edges)}")

        graph
      end

      # Test helper to expose the graph building function
      def __build_migration_graph_for_test__ do
        build_migration_graph()
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @doc """
      Returns a list of event types and their modules.
      """
      def event_modules do
        @event_registry
        |> Enum.map(fn {type, module, _version} -> {type, module} end)
      end

      @doc """
      Returns a list of event types and their current versions.
      """
      def event_versions do
        @event_registry
        |> Enum.map(fn {type, _module, version} -> {type, version} end)
      end

      @doc """
      Returns all registered migrations.
      """
      def event_migrations do
        @migrations
      end
    end
  end
end
