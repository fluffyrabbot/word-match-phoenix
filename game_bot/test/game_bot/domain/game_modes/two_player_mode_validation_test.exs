defmodule GameBot.Domain.GameModes.TwoPlayerModeValidationTest do
  use ExUnit.Case
  alias GameBot.Domain.GameModes.TwoPlayerMode
  alias GameBot.Domain.Events.GameEvents.{GameStarted, GuessProcessed}
  alias GameBot.TestHelpers

  # Apply test environment settings before all tests
  setup_all do
    TestHelpers.apply_test_environment()

    on_exit(fn ->
      TestHelpers.cleanup_test_environment()
    end)

    :ok
  end

  @valid_teams %{
    "team1" => ["player1", "player2"]
  }

  @valid_config %{
    rounds_required: 5,
    success_threshold: 4,
    guild_id: "guild123"
  }

  describe "init/3 validation" do
    test "validates exact team count" do
      teams = %{
        "team1" => ["player1", "player2"],
        "team2" => ["player3", "player4"]
      }
      assert {:error, {:invalid_team_count, _}} = TwoPlayerMode.init("game123", teams, @valid_config)
    end

    test "validates team size" do
      teams = %{"team1" => ["player1"]}
      assert {:error, {:invalid_team_size, _}} = TwoPlayerMode.init("game123", teams, @valid_config)
    end

    test "validates rounds_required is positive" do
      config = %{@valid_config | rounds_required: 0}
      assert {:error, :invalid_rounds} = TwoPlayerMode.init("game123", @valid_teams, config)
    end

    test "validates success_threshold is positive" do
      config = %{@valid_config | success_threshold: 0}
      assert {:error, :invalid_threshold} = TwoPlayerMode.init("game123", @valid_teams, config)
    end

    test "accepts valid initialization parameters" do
      assert {:ok, state, _events} = TwoPlayerMode.init("game123", @valid_teams, @valid_config)
      assert state.rounds_required == @valid_config.rounds_required
      assert state.success_threshold == @valid_config.success_threshold
      assert map_size(state.teams) == 1
    end
  end

  describe "process_guess_pair/3 validation" do
    setup do
      {:ok, state, _} = TwoPlayerMode.init("game123", @valid_teams, @valid_config)

      # Ensure state has empty forbidden_words
      state = TestHelpers.bypass_word_validations(state)

      {:ok, state: state}
    end

    test "validates team existence", %{state: state} do
      guess_pair = %{
        player1_id: "player1",
        player2_id: "player2",
        player1_word: "hello",
        player2_word: "world"
      }
      assert {:error, :invalid_team} = TwoPlayerMode.process_guess_pair(state, "nonexistent_team", guess_pair)
    end

    test "validates player membership", %{state: state} do
      guess_pair = %{
        player1_id: "invalid_player",
        player2_id: "player2",
        player1_word: "hello",
        player2_word: "world"
      }
      assert {:error, :invalid_player} = TwoPlayerMode.process_guess_pair(state, "team1", guess_pair)
    end

    test "validates player uniqueness", %{state: state} do
      guess_pair = %{
        player1_id: "player1",
        player2_id: "player1",
        player1_word: "hello",
        player2_word: "world"
      }
      assert {:error, :same_player} = TwoPlayerMode.process_guess_pair(state, "team1", guess_pair)
    end

    test "accepts valid guess pair", %{state: state} do
      guess_pair = %{
        player1_id: "player1",
        player2_id: "player2",
        player1_word: "hello",
        player2_word: "hello"
      }
      assert {:ok, _state, _event} = TwoPlayerMode.process_guess_pair(state, "team1", guess_pair)
    end
  end

  describe "check_round_end/1 validation" do
    setup do
      {:ok, state, _} = TwoPlayerMode.init("game123", @valid_teams, @valid_config)

      # Ensure state has empty forbidden_words
      state = TestHelpers.bypass_word_validations(state)

      {:ok, state: state}
    end

    test "validates round completion", %{state: state} do
      # Simulate completing all rounds
      state = %{state | current_round: state.rounds_required + 1}
      assert {:game_end, _winners} = TwoPlayerMode.check_game_end(state)
    end

    test "continues game when rounds remain", %{state: state} do
      assert :continue = TwoPlayerMode.check_game_end(state)
    end
  end

  describe "validate_event/1" do
    test "validates GameStarted event" do
      event = %GameStarted{
        game_id: "game123",
        mode: :two_player,
        teams: @valid_teams,
        team_ids: Map.keys(@valid_teams),
        player_ids: List.flatten(Map.values(@valid_teams)),
        config: @valid_config,
        timestamp: DateTime.utc_now(),
        metadata: %{}
      }
      assert :ok = TwoPlayerMode.validate_event(event)
    end

    test "validates GuessProcessed event" do
      event = %GuessProcessed{
        game_id: "game123",
        guild_id: "guild123",
        mode: :two_player,
        team_id: "team1",
        player1_info: %{id: "player1", word: "hello"},
        player2_info: %{id: "player2", word: "hello"},
        guess_successful: true,
        guess_count: 1,
        round_number: 1,
        round_guess_count: 1,
        total_guesses: 1,
        guess_duration: 100,
        match_score: 1,
        timestamp: DateTime.utc_now(),
        metadata: %{}
      }
      assert :ok = TwoPlayerMode.validate_event(event)
    end

    test "rejects events with wrong mode" do
      event = %GameStarted{
        game_id: "game123",
        mode: :race,
        teams: @valid_teams,
        team_ids: Map.keys(@valid_teams),
        player_ids: List.flatten(Map.values(@valid_teams)),
        config: @valid_config,
        timestamp: DateTime.utc_now(),
        metadata: %{}
      }
      assert {:error, _} = TwoPlayerMode.validate_event(event)
    end
  end
end
