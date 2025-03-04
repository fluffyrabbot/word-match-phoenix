defmodule GameBot.Infrastructure.Cache do
  @moduledoc """
  Caching layer using ETS tables for improved performance.
  
  This module provides a transparent caching mechanism that falls back
  to database queries when cache misses occur.
  """
  
  use GenServer
  
  # Table names
  @tables [:game_states, :player_stats]
  
  # Cache expiration time (in milliseconds)
  @default_ttl 60 * 60 * 1000 # 1 hour
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  @doc """
  Gets a value from the cache by table and key.
  
  Returns nil if the value isn't in the cache.
  """
  def get(table, key) do
    case :ets.lookup(table, key) do
      [{^key, value, expiry}] ->
        if expiry > System.monotonic_time(:millisecond) do
          value
        else
          # Entry expired
          nil
        end
        
      [] ->
        # Key not found
        nil
    end
  end
  
  @doc """
  Puts a value into the cache with a specified TTL.
  
  TTL defaults to 1 hour if not specified.
  """
  def put(table, key, value, ttl \\ @default_ttl) do
    expiry = System.monotonic_time(:millisecond) + ttl
    :ets.insert(table, {key, value, expiry})
    value
  end
  
  @doc """
  Deletes a value from the cache.
  """
  def delete(table, key) do
    :ets.delete(table, key)
    :ok
  end
  
  @doc """
  Clears all entries from a specific table.
  """
  def clear(table) do
    :ets.delete_all_objects(table)
    :ok
  end
  
  @doc """
  Clears all cache tables.
  """
  def clear_all do
    Enum.each(@tables, &clear/1)
    :ok
  end
  
  # Initialization
  
  @impl true
  def init(_) do
    # Create ETS tables for each cache
    for table <- @tables do
      :ets.new(table, [:set, :named_table, :public, read_concurrency: true, write_concurrency: true])
    end
    
    # Start periodic cleanup
    schedule_cleanup()
    
    {:ok, %{}}
  end
  
  # Periodic cleanup handler
  
  @impl true
  def handle_info(:cleanup, state) do
    # Remove expired entries from all tables
    cleanup_expired()
    
    # Schedule next cleanup
    schedule_cleanup()
    
    {:noreply, state}
  end
  
  # Private helper functions
  
  defp schedule_cleanup do
    # Run cleanup every 15 minutes
    Process.send_after(self(), :cleanup, 15 * 60 * 1000)
  end
  
  defp cleanup_expired do
    now = System.monotonic_time(:millisecond)
    
    for table <- @tables do
      :ets.select_delete(table, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    end
  end
end 