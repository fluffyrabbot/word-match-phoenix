defmodule GameBot.Replay.GameCompletionHandlerTest do
  use GameBot.RepositoryCase, async: false

  alias GameBot.Replay.{
    GameCompletionHandler,
    EventStoreAccess,
    EventVerifier,
    VersionCompatibility,
    Storage,
    Utils.NameGenerator,
    Utils.StatsCalculator
  }

  import Mox

  setup :verify_on_exit!

  describe "handle_event/1" do
    test "successfully processes game completion event" do
      # Setup test data
      game_id = "test-game-id-#{:rand.uniform(1000)}"
      completion_event = create_game_completed_event(game_id)
      events = [
        create_game_started_event(game_id),
        completion_event
      ]

      # Set up mocks for dependencies
      setup_successful_mocks(game_id, events)

      # Execute the handler
      result = GameCompletionHandler.handle_event(completion_event)

      # Verify the result
      assert result == :ok
    end

    test "returns error when event processing fails" do
      # Setup test data
      game_id = "test-game-id-#{:rand.uniform(1000)}"
      completion_event = create_game_completed_event(game_id)

      # Setup mock to simulate event retrieval failure
      expect(MockEventStoreAccess, :fetch_game_events, fn ^game_id, _opts ->
        {:error, :stream_not_found}
      end)

      # Execute the handler
      result = GameCompletionHandler.handle_event(completion_event)

      # Verify the result
      assert {:error, :stream_not_found} = result
    end
  end

  describe "process_game_completed/1" do
    test "successfully processes a completed game and creates a replay" do
      # Setup test data
      game_id = "test-game-id-#{:rand.uniform(1000)}"
      replay_id = "test-replay-id-#{:rand.uniform(1000)}"
      display_name = "test-replay-#{:rand.uniform(1000)}"
      completion_event = create_game_completed_event(game_id)
      events = [
        create_game_started_event(game_id),
        completion_event
      ]

      # Set up mocks for the happy path
      setup_successful_mocks(game_id, events, replay_id, display_name)

      # Execute the function
      result = GameCompletionHandler.process_game_completed(completion_event)

      # Verify the result
      assert {:ok, ^replay_id} = result
    end

    test "handles event retrieval failure" do
      # Setup test data
      game_id = "test-game-id-#{:rand.uniform(1000)}"
      completion_event = create_game_completed_event(game_id)

      # Setup mock to simulate failure
      expect(MockEventStoreAccess, :fetch_game_events, fn ^game_id, _opts ->
        {:error, :stream_not_found}
      end)

      # Execute function
      result = GameCompletionHandler.process_game_completed(completion_event)

      # Verify result
      assert {:error, :stream_not_found} = result
    end

    test "handles event verification failure" do
      # Setup test data
      game_id = "test-game-id-#{:rand.uniform(1000)}"
      completion_event = create_game_completed_event(game_id)
      events = [completion_event] # Missing required game_started event

      # Setup mocks
      expect(MockEventStoreAccess, :fetch_game_events, fn ^game_id, _opts ->
        {:ok, events}
      end)

      expect(MockEventVerifier, :verify_game_stream, fn ^events, _opts ->
        {:error, :missing_required_events}
      end)

      # Execute function
      result = GameCompletionHandler.process_game_completed(completion_event)

      # Verify result
      assert {:error, :missing_required_events} = result
    end

    test "handles version compatibility failure" do
      # Setup test data
      game_id = "test-game-id-#{:rand.uniform(1000)}"
      completion_event = create_game_completed_event(game_id)
      events = [
        create_game_started_event(game_id),
        completion_event
      ]

      # Setup mocks
      expect(MockEventStoreAccess, :fetch_game_events, fn ^game_id, _opts ->
        {:ok, events}
      end)

      expect(MockEventVerifier, :verify_game_stream, fn ^events, _opts ->
        :ok
      end)

      expect(MockVersionCompatibility, :validate_replay_compatibility, fn ^events ->
        {:error, :incompatible_event_versions}
      end)

      # Execute function
      result = GameCompletionHandler.process_game_completed(completion_event)

      # Verify result
      assert {:error, :incompatible_event_versions} = result
    end

    test "handles statistics calculation failure" do
      # Setup test data
      game_id = "test-game-id-#{:rand.uniform(1000)}"
      completion_event = create_game_completed_event(game_id)
      events = [
        create_game_started_event(game_id),
        completion_event
      ]
      version_map = %{"game_started" => 1, "game_completed" => 1}

      # Setup mocks
      expect(MockEventStoreAccess, :fetch_game_events, fn ^game_id, _opts ->
        {:ok, events}
      end)

      expect(MockEventVerifier, :verify_game_stream, fn ^events, _opts ->
        :ok
      end)

      expect(MockVersionCompatibility, :validate_replay_compatibility, fn ^events ->
        {:ok, version_map}
      end)

      expect(MockStatsCalculator, :calculate_base_stats, fn ^events ->
        {:error, :stats_calculation_error}
      end)

      # Execute function
      result = GameCompletionHandler.process_game_completed(completion_event)

      # Verify result
      assert {:error, :stats_calculation_error} = result
    end

    test "handles storage failure" do
      # Setup test data
      game_id = "test-game-id-#{:rand.uniform(1000)}"
      display_name = "test-replay-#{:rand.uniform(1000)}"
      completion_event = create_game_completed_event(game_id)
      events = [
        create_game_started_event(game_id),
        completion_event
      ]
      version_map = %{"game_started" => 1, "game_completed" => 1}
      base_stats = %{duration_seconds: 60, total_guesses: 5, player_count: 2, team_count: 2, rounds: 1}
      mode_stats = %{successful_guesses: 3, failed_guesses: 2, team_scores: %{"team1" => 2, "team2" => 1}, winning_team: "team1"}

      # Setup mocks
      expect(MockEventStoreAccess, :fetch_game_events, fn ^game_id, _opts ->
        {:ok, events}
      end)

      expect(MockEventVerifier, :verify_game_stream, fn ^events, _opts ->
        :ok
      end)

      expect(MockVersionCompatibility, :validate_replay_compatibility, fn ^events ->
        {:ok, version_map}
      end)

      expect(MockStatsCalculator, :calculate_base_stats, fn ^events ->
        {:ok, base_stats}
      end)

      expect(MockStatsCalculator, :calculate_mode_stats, fn ^events, :two_player ->
        {:ok, mode_stats}
      end)

      expect(MockStorage, :list_replays, fn ->
        {:ok, []}
      end)

      expect(MockNameGenerator, :generate_name, fn _existing_names ->
        {:ok, display_name}
      end)

      expect(MockStorage, :store_replay, fn _replay ->
        {:error, :database_error}
      end)

      # Execute function
      result = GameCompletionHandler.process_game_completed(completion_event)

      # Verify result
      assert {:error, :database_error} = result
    end
  end

  describe "subscribe/0" do
    test "subscribes to game_completed events" do
      expect(MockSubscriptionManager, :subscribe_to_event_type, fn "game_completed" ->
        :ok
      end)

      assert :ok = GameCompletionHandler.subscribe()
    end
  end

  # Helper functions

  defp create_game_started_event(game_id) do
    %{
      event_type: "game_started",
      game_id: game_id,
      event_id: "event-#{:rand.uniform(1000)}",
      timestamp: DateTime.utc_now() |> DateTime.add(-60),
      mode: :two_player,
      player_ids: ["player1", "player2"],
      team_ids: ["team1", "team2"],
      round_number: 1
    }
  end

  defp create_game_completed_event(game_id) do
    %{
      event_type: "game_completed",
      game_id: game_id,
      event_id: "event-#{:rand.uniform(1000)}",
      timestamp: DateTime.utc_now(),
      mode: :two_player,
      winning_team: "team1",
      round_number: 1
    }
  end

  defp setup_successful_mocks(game_id, events, replay_id \\ "test-replay-id", display_name \\ "test-display-name") do
    version_map = %{"game_started" => 1, "game_completed" => 1}
    base_stats = %{duration_seconds: 60, total_guesses: 5, player_count: 2, team_count: 2, rounds: 1}
    mode_stats = %{successful_guesses: 3, failed_guesses: 2, team_scores: %{"team1" => 2, "team2" => 1}, winning_team: "team1"}

    expect(MockEventStoreAccess, :fetch_game_events, fn ^game_id, _opts ->
      {:ok, events}
    end)

    expect(MockEventVerifier, :verify_game_stream, fn ^events, _opts ->
      :ok
    end)

    expect(MockVersionCompatibility, :validate_replay_compatibility, fn ^events ->
      {:ok, version_map}
    end)

    expect(MockStatsCalculator, :calculate_base_stats, fn ^events ->
      {:ok, base_stats}
    end)

    expect(MockStatsCalculator, :calculate_mode_stats, fn ^events, :two_player ->
      {:ok, mode_stats}
    end)

    expect(MockStorage, :list_replays, fn ->
      {:ok, []}
    end)

    expect(MockNameGenerator, :generate_name, fn _existing_names ->
      {:ok, display_name}
    end)

    expect(MockStorage, :store_replay, fn replay ->
      stored_replay = Map.put(replay, :replay_id, replay_id)
      {:ok, stored_replay}
    end)
  end
end
