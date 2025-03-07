defmodule GameBot.Domain.Events.EventRegistry do
  @moduledoc """
  Registry of all event types in the system.
  Provides mapping between event type strings and modules.
  Used for deserializing events from storage and validating event types.

  Implements an ETS-based registry for runtime registration and version support.
  """

  alias GameBot.Domain.Events.GameEvents

  # Hardcoded known events for initial registration
  @known_events [
    # Core game events
    {"game_created", GameEvents.GameCreated, 1},
    {"game_started", GameEvents.GameStarted, 1},
    {"game_completed", GameEvents.GameCompleted, 1},

    # Round events
    {"round_started", GameEvents.RoundStarted, 1},
    {"round_completed", GameEvents.RoundCompleted, 1},

    # Guess events
    {"guess_processed", GameEvents.GuessProcessed, 1},

    # Example event for testing
    {"example_event", GameBot.Domain.Events.GameEvents.ExampleEvent, 1}

    # Add more as they are implemented...
  ]

  @table_name :event_registry

  @doc """
  Starts the registry, creating an ETS table and registering initial events.
  Must be called before using the registry.
  """
  def start_link do
    # Create ETS table with read concurrency for better lookup performance
    # Use public table for simplicity - in production consider using protected
    # and accessing through a GenServer API
    :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])

    # Register known events
    Enum.each(@known_events, fn {type, module, version} ->
      register(type, module, version)
    end)

    {:ok, self()}
  end

  @doc """
  Registers an event type with its module.
  Also stores the event version for versioning support.
  """
  @spec register(String.t(), module(), pos_integer()) :: true
  def register(event_type, module, version \\ 1) when is_binary(event_type) and is_atom(module) do
    # Ensure table exists
    ensure_table_exists()

    # Insert the event type with its module and version
    :ets.insert(@table_name, {{event_type, version}, module})
  end

  @doc """
  Returns the module for a given event type string.
  If version is not specified, returns the highest version available.

  Returns {:ok, module} if found, or {:error, reason} if not found.
  """
  @spec module_for_type(String.t(), pos_integer() | nil) ::
    {:ok, module()} | {:ok, module(), pos_integer()} | {:error, String.t()}
  def module_for_type(type, version \\ nil) when is_binary(type) do
    # Ensure table exists
    ensure_table_exists()

    if version do
      # Get specific version
      case :ets.lookup(@table_name, {type, version}) do
        [{{^type, ^version}, module}] -> {:ok, module}
        [] -> {:error, "Unknown event type/version: #{type}/#{version}"}
      end
    else
      # Find all versions of this event type
      # Using select to find all entries where the event type matches
      result = :ets.select(@table_name, [
        {{{:"$1", :"$2"}, :"$3"}, [{:==, :"$1", type}], [{{{:"$1", :"$2"}}, :"$3"}]}
      ])

      case result do
        [] -> {:error, "Unknown event type: #{type}"}
        pairs ->
          # Find highest version
          {{^type, highest_version}, module} =
            Enum.max_by(pairs, fn {{_type, version}, _module} -> version end)
          {:ok, module, highest_version}
      end
    end
  end

  @doc """
  Returns all registered event types.
  """
  @spec all_event_types() :: [String.t()]
  def all_event_types do
    # Ensure table exists
    ensure_table_exists()

    # Using select to extract unique event types
    :ets.select(@table_name, [
      {{{:"$1", :_}, :_}, [], [:"$1"]}
    ])
    |> Enum.uniq()
  end

  @doc """
  Returns all registered event modules.
  """
  @spec all_event_modules() :: [module()]
  def all_event_modules do
    # Ensure table exists
    ensure_table_exists()

    # Using select to extract modules
    :ets.select(@table_name, [
      {{:_, :"$1"}, [], [:"$1"]}
    ])
    |> Enum.uniq()
  end

  @doc """
  Returns all registered event types with their versions and modules.
  Format: [{type, version, module}, ...]
  """
  @spec all_registered_events() :: [{String.t(), pos_integer(), module()}]
  def all_registered_events do
    # Ensure table exists
    ensure_table_exists()

    # Get all entries from the table
    :ets.tab2list(@table_name)
    |> Enum.map(fn {{type, version}, module} -> {type, version, module} end)
  end

  @doc """
  Deserializes event data into the appropriate struct.
  """
  @spec deserialize(map()) :: {:ok, struct()} | {:error, String.t()}
  def deserialize(%{"event_type" => type, "event_version" => version} = data) when is_map(data) do
    # Use the specified version
    version = String.to_integer("#{version}")
    case module_for_type(type, version) do
      {:ok, module} -> try_deserialize(module, data)
      {:error, reason} -> {:error, reason}
    end
  end

  def deserialize(%{"event_type" => type} = data) when is_map(data) do
    # No version specified, use the latest
    case module_for_type(type) do
      {:ok, module, _version} -> try_deserialize(module, data)
      {:error, reason} -> {:error, reason}
    end
  end

  def deserialize(data) when is_map(data) do
    {:error, "Missing event_type in data"}
  end

  def deserialize(_) do
    {:error, "Invalid event data format"}
  end

  # Private helpers

  defp try_deserialize(module, data) do
    try do
      if function_exported?(module, :deserialize, 1) do
        {:ok, module.deserialize(data["data"])}
      else
        {:error, "Module #{module} does not implement deserialize/1"}
      end
    rescue
      e -> {:error, "Failed to deserialize event: #{inspect(e)}"}
    end
  end

  defp ensure_table_exists do
    if :ets.info(@table_name) == :undefined do
      # Table doesn't exist yet, bootstrap with known events
      start_link()
    end
  end
end
