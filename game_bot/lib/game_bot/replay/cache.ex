defmodule GameBot.Replay.Cache do
  @moduledoc """
  ETS-based caching for replay metadata to improve performance.

  This module provides:
  - Fast access to frequently requested replays
  - Automatic cache invalidation with TTL
  - Performance monitoring
  """

  use GenServer
  require Logger

  alias GameBot.Replay.Types

  @table_name :replay_cache
  @ttl :timer.hours(1)  # 1 hour TTL
  @cleanup_interval :timer.minutes(5)  # Cleanup every 5 minutes
  @max_cache_size 1000  # Maximum number of entries

  # Client API

  @doc """
  Starts the cache server.

  ## Parameters
    - opts: Options for the GenServer

  ## Returns
    - {:ok, pid} - Successfully started
    - {:error, reason} - Failed to start
  """
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Stores a replay in the cache.

  ## Parameters
    - key: The key to store the replay under (replay_id or display_name)
    - replay: The replay to store

  ## Returns
    - :ok - Successfully stored
  """
  @spec put(String.t(), Types.replay_reference()) :: :ok
  def put(key, replay) do
    GenServer.call(__MODULE__, {:put, key, replay})
  end

  @doc """
  Retrieves a replay from the cache.

  ## Parameters
    - key: The key to look up (replay_id or display_name)

  ## Returns
    - {:ok, replay} - Successfully retrieved
    - {:error, :not_found} - Not in cache
    - {:error, :expired} - In cache but expired
  """
  @spec get(String.t()) :: {:ok, Types.replay_reference()} | {:error, :not_found | :expired}
  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  @doc """
  Gets a replay from the cache with fallback function.
  If not in the cache, calls the fallback function and stores the result.

  ## Parameters
    - key: The key to look up (replay_id or display_name)
    - fallback: Function that returns {:ok, replay} | {:error, reason}

  ## Returns
    - {:ok, replay, :cache_hit} - Found in cache
    - {:ok, replay, :cache_miss} - Not in cache, fallback succeeded
    - {:error, reason} - Fallback failed
  """
  @spec get_with_fallback(String.t(), (-> {:ok, Types.replay_reference()} | {:error, term()})) ::
    {:ok, Types.replay_reference(), :cache_hit | :cache_miss} | {:error, term()}
  def get_with_fallback(key, fallback) do
    GenServer.call(__MODULE__, {:get_with_fallback, key, fallback})
  end

  @doc """
  Removes a replay from the cache.

  ## Parameters
    - key: The key to remove

  ## Returns
    - :ok - Successfully removed (or wasn't present)
  """
  @spec remove(String.t()) :: :ok
  def remove(key) do
    GenServer.call(__MODULE__, {:remove, key})
  end

  @doc """
  Gets cache statistics.

  ## Returns
    - stats: Statistics about the cache usage
  """
  @spec stats() :: %{
    size: non_neg_integer(),
    hits: non_neg_integer(),
    misses: non_neg_integer(),
    inserts: non_neg_integer(),
    evictions: non_neg_integer()
  }
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Clears the entire cache. Only use this for testing!

  ## Returns
    - :ok
  """
  @spec clear_cache() :: :ok
  def clear_cache do
    GenServer.call(__MODULE__, :clear_cache)
  end

  @doc """
  Resets the cache statistics. Only use this for testing!

  ## Returns
    - :ok
  """
  @spec reset_stats() :: :ok
  def reset_stats do
    GenServer.call(__MODULE__, :reset_stats)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # Create ETS table if it doesn't exist
    if :ets.whereis(@table_name) == :undefined do
      :ets.new(@table_name, [:named_table, :set, :protected])
    end

    # Initialize stats in process dictionary
    stats = %{
      hits: 0,
      misses: 0,
      inserts: 0,
      evictions: 0
    }
    Process.put(:stats, stats)
    Process.put(:max_cache_size, @max_cache_size)

    # Schedule cleanup
    schedule_cleanup()

    {:ok, nil}
  end

  @impl true
  def handle_call({:put, key, replay}, _from, state) do
    normalized_key = normalize_key(key)
    expires_at = System.system_time(:millisecond) + @ttl

    # Store under both the provided key and the replay_id if different
    :ets.insert(@table_name, {normalized_key, {replay, expires_at}})

    replay_id = normalize_key(replay.replay_id)
    if normalized_key != replay_id do
      :ets.insert(@table_name, {replay_id, {replay, expires_at}})
    end

    # Update stats
    update_stat(:inserts)

    # Check if we need to evict entries
    maybe_evict_entries()

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    normalized_key = normalize_key(key)
    result = case :ets.lookup(@table_name, normalized_key) do
      [] ->
        update_stat(:misses)
        {:error, :not_found}

      [{^normalized_key, {replay, expires_at}}] ->
        if System.system_time(:millisecond) > expires_at do
          # Expired - remove it
          :ets.delete(@table_name, normalized_key)
          update_stat(:misses)
          {:error, :not_found} # Changed from :expired to :not_found for compatibility
        else
          # Valid entry
          update_stat(:hits)
          {:ok, replay}
        end
    end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_with_fallback, key, fallback}, _from, state) do
    normalized_key = normalize_key(key)
    result = case :ets.lookup(@table_name, normalized_key) do
      [] ->
        update_stat(:misses)
        case fallback.() do
          {:ok, replay} = _success ->
            # Store in cache directly without calling ourselves
            expires_at = System.system_time(:millisecond) + @ttl
            :ets.insert(@table_name, {normalized_key, {replay, expires_at}})

            # Also index by replay_id if different
            replay_id = normalize_key(replay.replay_id)
            if normalized_key != replay_id do
              :ets.insert(@table_name, {replay_id, {replay, expires_at}})
            end

            # Update stats
            update_stat(:inserts)

            # Maybe evict entries if over limit
            maybe_evict_entries()

            # Return success with cache miss
            {:ok, replay, :cache_miss}

          error ->
            # Pass through error
            error
        end

      [{^normalized_key, {replay, expires_at}}] ->
        if System.system_time(:millisecond) > expires_at do
          # Expired - try fallback
          :ets.delete(@table_name, normalized_key)
          update_stat(:misses)

          case fallback.() do
            {:ok, replay} = _success ->
              # Store in cache directly without calling ourselves
              new_expires_at = System.system_time(:millisecond) + @ttl
              :ets.insert(@table_name, {normalized_key, {replay, new_expires_at}})

              # Also index by replay_id if different
              replay_id = normalize_key(replay.replay_id)
              if normalized_key != replay_id do
                :ets.insert(@table_name, {replay_id, {replay, new_expires_at}})
              end

              # Update stats
              update_stat(:inserts)

              # Maybe evict entries if over limit
              maybe_evict_entries()

              # Return success with cache miss
              {:ok, replay, :cache_miss}

            error ->
              # Pass through error
              error
          end
        else
          # Valid entry
          update_stat(:hits)
          {:ok, replay, :cache_hit}
        end
    end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:remove, key}, _from, state) do
    normalized_key = normalize_key(key)
    :ets.delete(@table_name, normalized_key)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    size = :ets.info(@table_name, :size)
    stats = Process.get(:stats)
    {:reply, Map.put(stats, :size, size), state}
  end

  @impl true
  def handle_call(:reset_stats, _from, state) do
    # Reset stats for testing
    stats = %{
      hits: 0,
      misses: 0,
      inserts: 0,
      evictions: 0
    }
    Process.put(:stats, stats)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:clear_cache, _from, state) do
    # Clear the cache table
    :ets.delete_all_objects(@table_name)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  @impl true
  def handle_info({:manually_expire, key}, state) do
    # Add handler for test - manually expire a key
    normalized_key = normalize_key(key)
    case :ets.lookup(@table_name, normalized_key) do
      [{^normalized_key, {replay, _expires_at}}] ->
        # Set expiration to the past
        expired_time = System.system_time(:millisecond) - 1000
        :ets.insert(@table_name, {normalized_key, {replay, expired_time}})
      [] ->
        :ok
    end
    {:noreply, state}
  end

  @impl true
  def handle_info({:set_max_size, size}, state) do
    # Add handler for test - change max cache size
    Process.put(:max_cache_size, size)
    {:noreply, state}
  end

  # Private functions

  # Normalize keys (case insensitive comparison)
  defp normalize_key(key) when is_binary(key) do
    String.downcase(key)
  end

  defp normalize_key(key), do: key

  # Schedule the next cleanup
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  # Remove expired entries
  defp cleanup_expired_entries do
    now = System.system_time(:millisecond)

    # Find and delete expired entries
    :ets.select_delete(@table_name, [
      {:"$1", {:"$2", :"$3"}, [{:<, :"$3", now}]}
    ])
  end

  # Evict oldest entries if over size limit
  defp maybe_evict_entries do
    max_size = Process.get(:max_cache_size)
    current_size = :ets.info(@table_name, :size)

    if current_size > max_size do
      num_to_evict = current_size - max_size

      # Get all entries sorted by expiration time (oldest first)
      entries = :ets.tab2list(@table_name)
        |> Enum.sort_by(fn {_key, {_replay, expires_at}} -> expires_at end)

      # Delete the oldest entries
      to_delete = Enum.take(entries, num_to_evict)

      Enum.each(to_delete, fn {key, _} ->
        :ets.delete(@table_name, key)
        update_stat(:evictions)
      end)
    end
  end

  # Update a stat counter
  defp update_stat(stat_name) do
    stats = Process.get(:stats)
    updated_stats = Map.update(stats, stat_name, 1, &(&1 + 1))
    Process.put(:stats, updated_stats)
  end
end
