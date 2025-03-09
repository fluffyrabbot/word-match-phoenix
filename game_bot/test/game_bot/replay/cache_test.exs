defmodule GameBot.Replay.CacheTest do
  use ExUnit.Case, async: false

  alias GameBot.Replay.Cache

  # Setup for each test
  setup do
    # Stop any existing Cache
    if Process.whereis(Cache) do
      GenServer.stop(Cache)
      # Small delay to ensure termination
      Process.sleep(50)
    end

    # Clean up any existing ETS table
    if :ets.whereis(:replay_cache) != :undefined do
      :ets.delete(:replay_cache)
    end

    # Start a fresh Cache for this test
    {:ok, pid} = Cache.start_link()

    # Create a test replay
    test_replay = create_test_replay()

    # Return the test data and schedule cleanup
    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(Cache)
      end
    end)

    {:ok, %{
      replay: test_replay,
      replay_id: test_replay.replay_id,
      display_name: test_replay.display_name
    }}
  end

  describe "put/2 and get/1" do
    test "stores and retrieves a replay by ID", %{replay: replay, replay_id: replay_id} do
      # Store the replay
      :ok = Cache.put(replay_id, replay)

      # Retrieve it
      assert {:ok, retrieved} = Cache.get(replay_id)
      assert retrieved.replay_id == replay_id
      assert retrieved.display_name == replay.display_name
    end

    test "stores and retrieves a replay by display name", %{replay: replay, display_name: display_name} do
      # Store the replay using display name
      :ok = Cache.put(display_name, replay)

      # Retrieve it
      assert {:ok, retrieved} = Cache.get(display_name)
      assert retrieved.replay_id == replay.replay_id
      assert retrieved.display_name == display_name
    end

    test "handles different casing in keys", %{replay: replay} do
      # Store with lowercase
      :ok = Cache.put("test-key", replay)

      # Retrieve with different casing
      assert {:ok, _} = Cache.get("TEST-KEY")
    end

    test "returns not_found for missing keys" do
      assert {:error, :not_found} = Cache.get("nonexistent-key")
    end
  end

  describe "get_with_fallback/2" do
    test "returns cached value on hit", %{replay: replay, replay_id: replay_id} do
      # Store the replay
      :ok = Cache.put(replay_id, replay)

      # Create a fallback that would fail if called
      fallback = fn -> raise "Fallback should not be called on cache hit" end

      # Get with fallback should hit the cache
      assert {:ok, retrieved, :cache_hit} = Cache.get_with_fallback(replay_id, fallback)
      assert retrieved.replay_id == replay_id
    end

    test "calls fallback on miss", %{replay: replay, replay_id: replay_id} do
      # Create fallback that returns the test replay
      fallback = fn -> {:ok, replay} end

      # Get with fallback should miss and call the fallback
      assert {:ok, retrieved, :cache_miss} = Cache.get_with_fallback(replay_id, fallback)
      assert retrieved.replay_id == replay_id

      # Next call should hit
      assert {:ok, _, :cache_hit} = Cache.get_with_fallback(replay_id, fallback)
    end

    test "caches by both ID and display name when using display name", %{replay: replay, replay_id: replay_id, display_name: display_name} do
      # Create fallback that returns the test replay
      fallback = fn -> {:ok, replay} end

      # Get with fallback using display name
      assert {:ok, _, :cache_miss} = Cache.get_with_fallback(display_name, fallback)

      # Should now be able to get by replay_id too
      assert {:ok, _, :cache_hit} = Cache.get_with_fallback(replay_id, fn -> raise "Should not call" end)
    end

    test "propagates errors from fallback" do
      # Create a fallback that returns an error
      fallback = fn -> {:error, :test_error} end

      # Error should be propagated
      assert {:error, :test_error} = Cache.get_with_fallback("test-key", fallback)
    end
  end

  describe "remove/1" do
    test "removes an item from the cache", %{replay: replay, replay_id: replay_id} do
      # Store the replay
      :ok = Cache.put(replay_id, replay)

      # Verify it's there
      assert {:ok, _} = Cache.get(replay_id)

      # Remove it
      :ok = Cache.remove(replay_id)

      # Verify it's gone
      assert {:error, :not_found} = Cache.get(replay_id)
    end
  end

  describe "stats/0" do
    test "tracks hits, misses, and inserts correctly", %{replay: replay, replay_id: replay_id} do
      # Initial stats should show zeros for hits/misses/inserts
      initial_stats = Cache.stats()
      assert initial_stats.hits == 0
      assert initial_stats.misses == 0
      assert initial_stats.inserts == 0

      # Miss: get a non-existent item
      Cache.get("nonexistent")

      # Insert: put an item
      Cache.put(replay_id, replay)

      # Hit: get the item we just put
      Cache.get(replay_id)

      # Check stats
      updated_stats = Cache.stats()
      assert updated_stats.hits == 1
      assert updated_stats.misses == 1
      assert updated_stats.inserts == 1
    end

    test "reports current cache size" do
      # Reset the cache first
      if Process.whereis(Cache) do
        GenServer.stop(Cache)
        Process.sleep(50)
      end
      {:ok, _pid} = Cache.start_link()

      # Put 3 items with unique IDs and display names to ensure clean state
      for i <- 1..3 do
        # Create replays that use same ID and display name to avoid dual storage confusion
        replay = create_test_replay_with_id("id-#{i}", "id-#{i}")
        Cache.put("id-#{i}", replay)
      end

      # Get the stats and check the size - depends on implementation
      # With current implementation, each entry is stored just once
      stats = Cache.stats()
      assert stats.size == 3  # Adjust based on actual implementation
    end
  end

  describe "expiration" do
    test "expired items are reported as such", %{replay: replay, replay_id: replay_id} do
      # Put an item in the cache
      :ok = Cache.put(replay_id, replay)

      # Verify it's there
      assert {:ok, _} = Cache.get(replay_id)

      # Manually expire the item
      send(Cache, {:manually_expire, replay_id})

      # Wait a brief moment for the message to be processed
      Process.sleep(50)

      # Now the get should return not_found (expired items are automatically removed)
      assert {:error, :not_found} = Cache.get(replay_id)
    end
  end

  describe "eviction" do
    test "oldest entries are evicted when cache is full" do
      # Reset the cache first
      if Process.whereis(Cache) do
        GenServer.stop(Cache)
        Process.sleep(50)
      end
      {:ok, _pid} = Cache.start_link()

      # Set a small cache size
      max_size = 4
      send(Cache, {:set_max_size, max_size})

      # Wait for the message to be processed
      Process.sleep(50)

      # Add entries until we exceed max_size
      for i <- 1..6 do
        key = "key-#{i}"
        # Create a replay where id matches the key to simplify testing
        replay = create_test_replay_with_id(key, key)
        Cache.put(key, replay)
        # Small delay to ensure different timestamps for eviction ordering
        Process.sleep(10)
      end

      # Wait a moment for any eviction to occur
      Process.sleep(50)

      # Check the cache size - should be at most max_size
      stats = Cache.stats()
      assert stats.size <= max_size

      # The oldest entries should be evicted first
      assert {:error, :not_found} = Cache.get("key-1")
      assert {:error, :not_found} = Cache.get("key-2")

      # The newest entries should still be there
      assert {:ok, _} = Cache.get("key-5")
      assert {:ok, _} = Cache.get("key-6")
    end
  end

  # Helper function to create test replays
  defp create_test_replay do
    replay_id = Ecto.UUID.generate()
    display_name = "test-#{:rand.uniform(999)}"

    %{
      replay_id: replay_id,
      game_id: "test-game-#{System.unique_integer([:positive])}",
      display_name: display_name,
      mode: :two_player,
      start_time: DateTime.utc_now() |> DateTime.add(-3600),
      end_time: DateTime.utc_now(),
      event_count: 42,
      base_stats: %{duration_seconds: 3600},
      mode_stats: %{successful_guesses: 30},
      version_map: %{"game_started" => 1},
      created_at: DateTime.utc_now()
    }
  end

  # Helper to create a test replay with specific ID and name
  defp create_test_replay_with_id(id, name) do
    %{
      replay_id: id,
      game_id: "test-game-#{System.unique_integer([:positive])}",
      display_name: name,
      mode: :two_player,
      start_time: DateTime.utc_now() |> DateTime.add(-3600),
      end_time: DateTime.utc_now(),
      event_count: 42,
      base_stats: %{duration_seconds: 3600},
      mode_stats: %{successful_guesses: 30},
      version_map: %{"game_started" => 1},
      created_at: DateTime.utc_now()
    }
  end
end
