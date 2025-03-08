defmodule GameBot.Domain.Events.Registry do
  @moduledoc """
  Registry for event types and their implementations.
  Provides runtime registration and lookup of event types with version support.
  """

  use GenServer
  require Logger

  @table_name :event_registry

  # Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Registers an event type with its module and version.
  """
  @spec register_event(String.t(), module(), pos_integer()) :: :ok | {:error, term()}
  def register_event(type, module, version \\ 1) do
    GenServer.call(__MODULE__, {:register, type, module, version})
  end

  @doc """
  Gets the module for an event type and version.
  If version is not specified, returns the highest version available.
  """
  @spec get_module(String.t(), pos_integer() | nil) :: {:ok, module()} | {:error, term()}
  def get_module(type, version \\ nil) do
    GenServer.call(__MODULE__, {:get_module, type, version})
  end

  @doc """
  Gets all registered event types with their versions and modules.
  """
  @spec all_registered_events() :: [{String.t(), pos_integer(), module()}]
  def all_registered_events do
    GenServer.call(__MODULE__, :all_registered_events)
  end

  # Server Callbacks

  @impl true
  def init(_) do
    :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{events: %{}, versions: %{}}}
  end

  @impl true
  def handle_call({:register, type, module, version}, _from, state) do
    try do
      # Verify module implements required behaviours
      :ok = verify_module_behaviours(module)

      # Update state
      new_state = state
        |> put_in([:events, type], module)
        |> put_in([:versions, type], version)

      # Update ETS table
      :ets.insert(@table_name, {{type, version}, module})

      {:reply, :ok, new_state}
    catch
      :error, reason ->
        Logger.error("Failed to register event type #{type}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_module, type, nil}, _from, state) do
    case :ets.lookup(@table_name, {type, get_in(state, [:versions, type])}) do
      [{{^type, _version}, module}] -> {:reply, {:ok, module}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:get_module, type, version}, _from, state) do
    case :ets.lookup(@table_name, {type, version}) do
      [{{^type, ^version}, module}] -> {:reply, {:ok, module}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:all_registered_events, _from, state) do
    events = :ets.tab2list(@table_name)
      |> Enum.map(fn {{type, version}, module} -> {type, version, module} end)
    {:reply, events, state}
  end

  # Private Functions

  defp verify_module_behaviours(module) do
    behaviours = [GameBot.Domain.Events.EventSerializer, GameBot.Domain.Events.EventValidator]

    Enum.each(behaviours, fn behaviour ->
      unless behaviour in module.__behaviours__ do
        raise "#{module} must implement #{behaviour}"
      end
    end)
  end
end
