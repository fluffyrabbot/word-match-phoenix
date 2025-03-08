defmodule GameBot.Infrastructure.Persistence.EventStore.Serialization.EventTranslator do
  @moduledoc """
  Handles event translation and version mapping between different event versions.

  This module is responsible for:
  - Registering event types and their versions
  - Mapping between different versions of events
  - Validating event data during translation
  - Managing version compatibility
  """

  alias GameBot.Infrastructure.Error
  alias GameBot.Infrastructure.ErrorHelpers
  alias Graph

  @type event_type :: String.t()
  @type version :: pos_integer()
  @type event_module :: module()
  @type translation_fn :: (map() -> {:ok, map()} | {:error, Error.t()})

  @doc """
  Registers an event type with its module and version information.
  """
  defmacro register_event(type, module, version) do
    quote do
      @event_registry {unquote(type), unquote(module), unquote(version)}
    end
  end

  @doc """
  Defines a version migration for an event type.
  """
  defmacro register_migration(type, from_version, to_version, fun) do
    quote do
      @migrations {unquote(type), unquote(from_version), unquote(to_version), unquote(fun)}
    end
  end

  defmacro __using__(_opts) do
    quote do
      @before_compile GameBot.Infrastructure.Persistence.EventStore.Serialization.EventTranslator

      Module.register_attribute(__MODULE__, :event_registry, accumulate: true)
      Module.register_attribute(__MODULE__, :migrations, accumulate: true)

      import GameBot.Infrastructure.Persistence.EventStore.Serialization.EventTranslator,
        only: [register_event: 3, register_migration: 4]

      @doc """
      Looks up the module for a given event type.
      """
      @spec lookup_module(String.t()) :: {:ok, module()} | {:error, Error.t()}
      def lookup_module(type) do
        case Map.fetch(event_modules(), type) do
          {:ok, module} -> {:ok, module}
          :error -> {:error, Error.not_found_error(__MODULE__, "Unknown event type", type)}
        end
      end

      @doc """
      Gets the current version for an event type.
      """
      @spec get_version(String.t()) :: {:ok, pos_integer()} | {:error, Error.t()}
      def get_version(type) do
        case Map.fetch(event_versions(), type) do
          {:ok, version} -> {:ok, version}
          :error -> {:error, Error.not_found_error(__MODULE__, "Unknown event type", type)}
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
            {:error, Error.validation_error(__MODULE__, "Cannot migrate to older version", %{
              type: type,
              from: from_version,
              to: to_version
            })}
          true ->
            do_migrate(type, data, from_version, to_version)
        end
      end

      defp do_migrate(type, data, from_version, target_version) do
        case find_migration_path(type, from_version, target_version) do
          {:ok, path} -> apply_migrations(type, data, path)
          error -> error
        end
      end

      defp find_migration_path(type, from_version, target_version) do
        case build_migration_graph() |> find_path(type, from_version, target_version) do
          nil ->
            {:error, Error.not_found_error(__MODULE__, "No migration path found", %{
              type: type,
              from: from_version,
              to: target_version
            })}
          path ->
            {:ok, path}
        end
      end

      defp apply_migrations(_type, data, []), do: {:ok, data}
      defp apply_migrations(type, data, [{from, to, fun} | rest]) do
        case fun.(data) do
          {:ok, migrated} -> apply_migrations(type, migrated, rest)
          {:error, reason} ->
            {:error, Error.validation_error(__MODULE__, "Migration failed", %{
              type: type,
              from: from,
              to: to,
              reason: reason
            })}
        end
      end

      defp build_migration_graph do
        Enum.reduce(@migrations, Graph.new(), fn {type, from, to, _fun}, graph ->
          Graph.add_edge(graph, {type, from}, {type, to})
        end)
      end

      defp find_path(graph, type, from, to) do
        case Graph.get_paths(graph, {type, from}, {type, to}) do
          [] -> nil
          [path | _rest] ->
            path
            |> Enum.chunk_every(2, 1, :discard)
            |> Enum.map(fn [{^type, v1}, {^type, v2}] ->
              {v1, v2, get_migration_fun(type, v1, v2)}
            end)
        end
      end

      defp get_migration_fun(type, from, to) do
        Enum.find_value(@migrations, fn
          {^type, ^from, ^to, fun} -> fun
          _ -> nil
        end)
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def event_modules do
        @event_registry
        |> Enum.map(fn {type, module, _version} -> {type, module} end)
        |> Map.new()
      end

      def event_versions do
        @event_registry
        |> Enum.map(fn {type, _module, version} -> {type, version} end)
        |> Map.new()
      end

      def migrations do
        @migrations
        |> Enum.map(fn {type, from, to, fun} -> {{type, from, to}, fun} end)
        |> Map.new()
      end
    end
  end
end
