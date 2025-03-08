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
    expires_at = System.system_time(:millisecond) + @ttl
    :ets.insert(@table_name, {event.id, {event, expires_at}})
    {:noreply, state}
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
end
