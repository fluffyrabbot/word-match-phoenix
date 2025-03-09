defmodule GameBot.Replay.StorageTest do
  use GameBot.RepositoryCase, async: false

  alias GameBot.Replay.{Storage, GameReplay, ReplayAccessLog, Types, EventStoreAccess}
  alias GameBot.Infrastructure.Persistence.Repo.MockRepo
  alias Meck

  # Set up test data and environment
  setup do
    # Test data setup
    game_id = "test-game-#{System.unique_integer([:positive])}"
    replay_id = Ecto.UUID.generate()
    display_name = "test-replay-123"

    test_replay = %{
      replay_id: replay_id,
      game_id: game_id,
      display_name: display_name,
      mode: :two_player,
      start_time: DateTime.utc_now() |> DateTime.add(-3600),
      end_time: DateTime.utc_now(),
      event_count: 42,
      base_stats: %{
        duration_seconds: 3600,
        total_guesses: 75,
        player_count: 2,
        team_count: 2,
        rounds: 10
      },
      mode_stats: %{
        successful_guesses: 50,
        failed_guesses: 25,
        team_scores: %{"team1" => 30, "team2" => 20},
        winning_team: "team1",
        average_guess_time: 15.5
      },
      version_map: %{
        "game_started" => 1,
        "game_completed" => 1
      },
      created_at: DateTime.utc_now()
    }

    test_events = [
      %{event_type: "game_started", event_version: 1, version: 1, game_id: game_id},
      %{event_type: "round_started", event_version: 1, version: 2, game_id: game_id},
      %{event_type: "game_completed", event_version: 1, version: 3, game_id: game_id}
    ]

    # Start :meck for this test run
    :meck.new(MockRepo, [:passthrough])
    on_exit(fn -> :meck.unload(MockRepo) end)

    {:ok, %{
      replay: test_replay,
      replay_id: replay_id,
      game_id: game_id,
      display_name: display_name,
      events: test_events
    }}
  end

  describe "store_replay/1" do
    @tag :mock
    test "stores a replay successfully", %{replay: replay} do
      # Set up MockRepo to return a specific result for this test
      stored_replay = struct(GameReplay, Map.to_list(replay))

      :meck.expect(MockRepo, :insert, fn _changeset, _opts ->
        {:ok, stored_replay}
      end)

      # Call the function under test
      result = Storage.store_replay(replay)

      # Verify results
      assert {:ok, stored_replay} = result
      assert stored_replay.replay_id == replay.replay_id
      assert stored_replay.game_id == replay.game_id
      assert stored_replay.display_name == replay.display_name
    end

    @tag :mock
    test "handles insert errors", %{replay: replay} do
      # Set up MockRepo to return an error for this test
      changeset_error = %Ecto.Changeset{
        valid?: false,
        errors: [display_name: {"has already been taken", []}]
      }

      :meck.expect(MockRepo, :insert, fn _changeset, _opts ->
        {:error, changeset_error}
      end)

      # Call the function under test
      result = Storage.store_replay(replay)

      # Verify results
      assert {:error, %Ecto.Changeset{} = error_changeset} = result
      assert error_changeset.errors == [display_name: {"has already been taken", []}]
    end
  end

  describe "get_replay/2" do
    @tag :mock
    test "retrieves a replay by ID", %{replay: replay, replay_id: replay_id} do
      # Set up MockRepo to return a specific result for one
      stored_replay = struct(GameReplay, Map.to_list(replay))

      :meck.expect(MockRepo, :one, fn _query, _opts ->
        stored_replay
      end)

      # Call the function under test
      result = Storage.get_replay(replay_id)

      # Verify results
      assert {:ok, retrieved_replay} = result
      assert retrieved_replay.replay_id == replay_id
    end

    @tag :mock
    test "retrieves a replay by display name", %{replay: replay, display_name: display_name} do
      # Set up MockRepo to return a specific result for one
      stored_replay = struct(GameReplay, Map.to_list(replay))

      :meck.expect(MockRepo, :one, fn _query, _opts ->
        stored_replay
      end)

      # Call the function under test
      result = Storage.get_replay(display_name)

      # Verify results
      assert {:ok, retrieved_replay} = result
      assert retrieved_replay.display_name == display_name
    end

    @tag :mock
    test "retrieves a replay with events", %{replay: replay, replay_id: replay_id, events: events} do
      # Set up MockRepo to return a specific result for one
      stored_replay = struct(GameReplay, Map.to_list(replay))

      :meck.expect(MockRepo, :one, fn _query, _opts ->
        stored_replay
      end)

      # Mock EventStoreAccess for this test
      :meck.new(EventStoreAccess, [:passthrough])
      :meck.expect(EventStoreAccess, :fetch_game_events, fn _game_id ->
        {:ok, events}
      end)
      on_exit(fn -> :meck.unload(EventStoreAccess) end)

      # Call the function under test
      result = Storage.get_replay(replay_id, load_events: true)

      # Verify results
      assert {:ok, {retrieved_replay, retrieved_events}} = result
      assert retrieved_replay.replay_id == replay_id
      assert length(retrieved_events) == length(events)
    end

    @tag :mock
    test "handles not found error", %{replay_id: replay_id} do
      # Set up MockRepo to return nil for one
      :meck.expect(MockRepo, :one, fn _query, _opts ->
        nil
      end)

      # Call the function under test
      result = Storage.get_replay(replay_id)

      # Verify results
      assert result == {:error, :replay_not_found}
    end

    @tag :mock
    test "handles event loading errors", %{replay: replay, replay_id: replay_id} do
      # Set up MockRepo to return a specific result for one
      stored_replay = struct(GameReplay, Map.to_list(replay))

      :meck.expect(MockRepo, :one, fn _query, _opts ->
        stored_replay
      end)

      # Mock EventStoreAccess for this test
      :meck.new(EventStoreAccess, [:passthrough])
      :meck.expect(EventStoreAccess, :fetch_game_events, fn _game_id ->
        {:error, :stream_not_found}
      end)
      on_exit(fn -> :meck.unload(EventStoreAccess) end)

      # Call the function under test
      result = Storage.get_replay(replay_id, load_events: true)

      # Verify results
      assert result == {:error, :stream_not_found}
    end
  end

  describe "get_replay_metadata/1" do
    @tag :mock
    test "retrieves only replay metadata", %{replay: replay, replay_id: replay_id} do
      # Set up mock to return the replay
      expect(MockRepo, :one, fn _query ->
        struct(GameReplay, Map.to_list(replay))
      end)

      # Call function under test
      result = Storage.get_replay_metadata(replay_id)

      # Verify results
      assert {:ok, retrieved_replay} = result
      assert retrieved_replay.replay_id == replay_id
    end
  end

  describe "list_replays/1" do
    @tag :mock
    test "lists replays with default params" do
      # Create list of test replays
      replays = [
        struct(GameReplay, %{replay_id: Ecto.UUID.generate(), game_id: "game1", mode: :two_player, display_name: "test1"}),
        struct(GameReplay, %{replay_id: Ecto.UUID.generate(), game_id: "game2", mode: :knockout, display_name: "test2"})
      ]

      # Mock the transaction function
      expect(MockRepo, :transaction, fn fun, _opts ->
        {:ok, fun.()}
      end)

      # Mock the all function to return replays
      expect(MockRepo, :all, fn _query -> replays end)

      # Call function under test
      result = Storage.list_replays()

      # Verify results
      assert {:ok, list} = result
      assert length(list) == 2
    end

    @tag :mock
    test "lists replays with filters", %{replay: replay} do
      # Create a struct from the map for test data
      replay_struct = struct(GameReplay, Map.to_list(replay))

      # Mock the transaction function
      expect(MockRepo, :transaction, fn fun, _opts ->
        {:ok, fun.()}
      end)

      # Mock the all function to return filtered replay
      expect(MockRepo, :all, fn _query -> [replay_struct] end)

      # Call function under test with filter
      result = Storage.list_replays(%{
        game_id: replay.game_id,
        mode: replay.mode,
        limit: 10
      })

      # Verify results
      assert {:ok, list} = result
      assert length(list) == 1
      assert hd(list).game_id == replay.game_id
    end

    @tag :mock
    test "returns empty list when no replays match filters" do
      # Mock the transaction function
      expect(MockRepo, :transaction, fn fun, _opts ->
        {:ok, fun.()}
      end)

      # Mock the all function to return empty list
      expect(MockRepo, :all, fn _query -> [] end)

      # Call function under test with filter
      result = Storage.list_replays(%{game_id: "nonexistent-game"})

      # Verify results
      assert {:ok, list} = result
      assert list == []
    end
  end

  describe "log_access/6" do
    @tag :mock
    test "logs access successfully", %{replay_id: replay_id} do
      # Mock insert to return success
      expect(MockRepo, :insert, fn changeset ->
        assert changeset.changes.replay_id == replay_id
        assert changeset.changes.user_id == "user123"
        assert changeset.changes.guild_id == "guild123"
        assert changeset.changes.access_type == :view

        # Create a struct that represents the successful insert
        access_log = struct(ReplayAccessLog, changeset.changes)
        {:ok, access_log}
      end)

      # Call the function under test
      result = Storage.log_access(replay_id, "user123", "guild123", :view)

      # Verify results
      assert result == :ok
    end

    @tag :mock
    test "returns error on failed insert", %{replay_id: replay_id} do
      # Mock insert to return an error
      expect(MockRepo, :insert, fn _changeset ->
        changeset_error = %Ecto.Changeset{
          valid?: false,
          errors: [user_id: {"is invalid", []}]
        }
        {:error, changeset_error}
      end)

      # Call the function under test
      result = Storage.log_access(replay_id, "invalid-user", "guild123", :view)

      # Verify results
      assert {:error, changeset} = result
      assert changeset.errors == [user_id: {"is invalid", []}]
    end
  end

  describe "cleanup_old_replays/1" do
    @tag :mock
    test "deletes old replays" do
      # Mock the transaction function
      expect(MockRepo, :transaction, fn fun, _opts ->
        {:ok, fun.()}
      end)

      # Mock delete_all to return success with count
      expect(MockRepo, :delete_all, fn _query ->
        {5, nil}  # 5 records deleted
      end)

      # Call function under test
      result = Storage.cleanup_old_replays(30)  # Keep replays for 30 days

      # Verify results
      assert {:ok, count} = result
      assert count == 5
    end

    @tag :mock
    test "handles delete errors" do
      # Mock the transaction function
      expect(MockRepo, :transaction, fn fun, _opts ->
        {:ok, fun.()}
      end)

      # Mock delete_all to return an error
      expect(MockRepo, :delete_all, fn _query ->
        {:error, "database error"}
      end)

      # Call function under test
      result = Storage.cleanup_old_replays()

      # Verify results
      assert {:error, "database error"} = result
    end
  end
end
