defmodule GameBot.Domain.GameModes.RaceModeValidationTest do
  use ExUnit.Case
  alias GameBot.Domain.GameModes.RaceMode
  alias GameBot.Domain.Events.GameEvents.{GameStarted, GuessProcessed, RaceModeTimeExpired}
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
    "team1" => ["player1", "player2"],
    "team2" => ["player3", "player4"]
  }

  @valid_config %{
    time_limit: 180,
    guild_id: "guild123"
  }

  describe "init/3 validation" do
    test "validates minimum team count" do
      teams = %{"team1" => ["player1", "player2"]}
      assert {:error, {:invalid_team_count, _}} = RaceMode.init("game123", teams, @valid_config)
    end

    test "validates guild_id presence" do
      config = Map.delete(@valid_config, :guild_id)
      assert {:error, :missing_guild_id} = RaceMode.init("game123", @valid_teams, config)
    end

    test "validates time_limit is positive" do
      config = %{@valid_config | time_limit: 0}
      assert {:error, :invalid_time_limit} = RaceMode.init("game123", @valid_teams, config)
    end

    test "accepts valid initialization parameters" do
      assert {:ok, state, _events} = RaceMode.init("game123", @valid_teams, @valid_config)
      assert state.time_limit == @valid_config.time_limit
      assert state.guild_id == @valid_config.guild_id
      assert map_size(state.teams) == 2
    end
  end

  describe "process_guess_pair/3 validation" do
    setup do
      {:ok, state, _} = RaceMode.init("game123", @valid_teams, @valid_config)

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
      assert {:error, :invalid_team} = RaceMode.process_guess_pair(state, "nonexistent_team", guess_pair)
    end

    test "validates player membership", %{state: state} do
      guess_pair = %{
        player1_id: "invalid_player",
        player2_id: "player2",
        player1_word: "hello",
        player2_word: "world"
      }
      assert {:error, :invalid_player} = RaceMode.process_guess_pair(state, "team1", guess_pair)
    end

    test "validates player uniqueness", %{state: state} do
      guess_pair = %{
        player1_id: "player1",
        player2_id: "player1",
        player1_word: "hello",
        player2_word: "world"
      }
      assert {:error, :same_player} = RaceMode.process_guess_pair(state, "team1", guess_pair)
    end

    test "accepts valid guess pair", %{state: state} do
      guess_pair = %{
        player1_id: "player1",
        player2_id: "player2",
        player1_word: "hello",
        player2_word: "hello"
      }
      assert {:ok, _state, _event} = RaceMode.process_guess_pair(state, "team1", guess_pair)
    end
  end

  describe "validate_event/1" do
    test "validates GameStarted event" do
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
      assert :ok = RaceMode.validate_event(event)
    end

    test "validates GuessProcessed event" do
      event = %GuessProcessed{
        game_id: "game123",
        guild_id: "guild123",
        mode: :race,
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
      assert :ok = RaceMode.validate_event(event)
    end

    test "validates RaceModeTimeExpired event" do
      event = %RaceModeTimeExpired{
        game_id: "game123",
        mode: :race,
        final_matches: %{
          "team1" => %{matches: 5, total_guesses: 15},
          "team2" => %{matches: 3, total_guesses: 12}
        },
        game_duration: 180,
        timestamp: DateTime.utc_now(),
        metadata: %{}
      }
      assert :ok = RaceMode.validate_event(event)
    end

    test "rejects events with wrong mode" do
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
      assert {:error, _} = RaceMode.validate_event(event)
    end
  end
end
