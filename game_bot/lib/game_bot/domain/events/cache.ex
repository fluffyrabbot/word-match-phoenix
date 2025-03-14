defmodule GameBot.Domain.Events.Cache do
  @moduledoc """
  Cache for events using ETS.
  Provides fast lookup of recently processed events with automatic expiration.
  """

  use GenServer
  require Logger

  @table_name :event_cache
  @ttl :timer.hours(1)
  @cleanup_interval :timer.minutes(5)

  # Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Caches an event with the current timestamp.
  """
  @spec cache_event(struct()) :: :ok
  def cache_event(event) do
    GenServer.cast(__MODULE__, {:cache, event})
  end

  @doc """
  Retrieves an event from the cache by ID.
  Returns {:ok, event} if found and not expired, {:error, reason} otherwise.
  """
  @spec get_event(String.t()) :: {:ok, struct()} | {:error, :not_found | :expired}
  def get_event(id) do
    GenServer.call(__MODULE__, {:get, id})
  end

  @doc """
  Removes an event from the cache.
  """
  @spec remove_event(String.t()) :: :ok
  def remove_event(id) do
    GenServer.cast(__MODULE__, {:remove, id})
  end

  # Server Callbacks

  @impl true
  def init(_) do
    :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:cache, event}, state) do
    case get_event_id(event) do
      {:ok, id} ->
        expires_at = System.system_time(:millisecond) + @ttl
        :ets.insert(@table_name, {id, {event, expires_at}})
        {:noreply, state}
      {:error, reason} ->
        Logger.warning("Failed to cache event: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:remove, id}, state) do
    :ets.delete(@table_name, id)
    {:noreply, state}
  end

  @impl true
  def handle_call({:get, id}, _from, state) do
    case :ets.lookup(@table_name, id) do
      [{^id, {event, expires_at}}] ->
        if System.system_time(:millisecond) < expires_at do
          {:reply, {:ok, event}, state}
        else
          :ets.delete(@table_name, id)
          {:reply, {:error, :expired}, state}
        end
      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired()
    schedule_cleanup() # Schedule next cleanup
    {:noreply, state}
  end

  # Private Functions

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp cleanup_expired do
    now = System.system_time(:millisecond)
    :ets.select_delete(@table_name, [{{:_, {:_, :"$1"}}, [{:<, :"$1", now}], [true]}])
  end

  @doc """
  Extracts an ID from different event structures safely.
  """
  defp get_event_id(event) do
    cond do
      is_map(event) && Map.has_key?(event, :id) ->
        {:ok, event.id}
      is_map(event) && Map.has_key?(event, "id") ->
        {:ok, event["id"]}
      is_map(event) && Map.has_key?(event, :event_id) ->
        {:ok, event.event_id}
      is_map(event) && Map.has_key?(event, :metadata) &&
        is_map(event.metadata) && Map.has_key?(event.metadata, "correlation_id") ->
        {:ok, event.metadata["correlation_id"]}
      is_struct(event) && Map.has_key?(event, :__struct__) ->
        # Last resort - use the struct name and a random value
        module_name = event.__struct__ |> to_string()
        unique_id = "#{module_name}_#{:erlang.unique_integer([:positive])}"
        {:ok, unique_id}
      true ->
        {:error, {:missing_id, event}}
    end
  end
end
