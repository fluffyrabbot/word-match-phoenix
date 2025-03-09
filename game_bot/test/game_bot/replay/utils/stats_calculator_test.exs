defmodule GameBot.Replay.Utils.StatsCalculatorTest do
  use ExUnit.Case

  alias GameBot.Replay.Utils.StatsCalculator

  # Test event generators for different game modes
  describe "calculate_base_stats/1" do
    test "calculates base stats correctly" do
      events = [
        create_game_started_event(),
        create_guess_processed_event(true, "team1", 1),
        create_guess_processed_event(false, "team2", 1),
        create_guess_processed_event(true, "team1", 1),
        create_game_completed_event()
      ]

      {:ok, stats} = StatsCalculator.calculate_base_stats(events)

      assert stats.total_guesses == 3
      assert stats.player_count == 4
      assert stats.team_count == 3
      assert stats.rounds == 1
      assert stats.duration_seconds > 0
    end

    test "handles missing game_completed event" do
      events = [
        create_game_started_event(),
        create_guess_processed_event(true, "team1", 1),
        create_guess_processed_event(false, "team2", 1)
      ]

      {:ok, stats} = StatsCalculator.calculate_base_stats(events)

      assert stats.total_guesses == 2
      assert stats.duration_seconds > 0
    end

    test "returns error when game_started event is missing" do
      events = [
        create_guess_processed_event(true, "team1", 1),
        create_game_completed_event()
      ]

      assert {:error, :stats_calculation_error} = StatsCalculator.calculate_base_stats(events)
    end
  end

  describe "calculate_two_player_stats/1" do
    test "calculates two-player stats correctly" do
      events = [
        create_game_started_event(),
        create_guess_processed_event(true, "team1", 1, 5),
        create_guess_processed_event(false, "team2", 1, 3),
        create_guess_processed_event(true, "team1", 1, 7),
        create_game_completed_event()
      ]

      {:ok, stats} = StatsCalculator.calculate_two_player_stats(events)

      assert stats.successful_guesses == 2
      assert stats.failed_guesses == 1
      assert stats.team_scores["team1"] == 2
      assert stats.winning_team == "team1"
      assert stats.average_guess_time == 5.0
    end

    test "handles no successful guesses" do
      events = [
        create_game_started_event(),
        create_guess_processed_event(false, "team1", 1, 3),
        create_guess_processed_event(false, "team2", 1, 4),
        create_game_completed_event()
      ]

      {:ok, stats} = StatsCalculator.calculate_two_player_stats(events)

      assert stats.successful_guesses == 0
      assert stats.failed_guesses == 2
      assert stats.team_scores == %{}
      assert stats.winning_team == nil
      assert stats.average_guess_time == 3.5
    end
  end

  describe "calculate_knockout_stats/1" do
    test "calculates knockout stats correctly" do
      events = [
        create_game_started_event(),
        create_guess_processed_event(true, "team1", 1),
        create_guess_processed_event(false, "team2", 1),
        create_team_eliminated_event("team2", 1),
        create_knockout_round_completed_event(1),
        create_guess_processed_event(true, "team1", 2),
        create_guess_processed_event(true, "team3", 2),
        create_team_eliminated_event("team3", 2),
        create_knockout_round_completed_event(2),
        create_game_completed_event(%{winning_team: "team1"})
      ]

      {:ok, stats} = StatsCalculator.calculate_knockout_stats(events)

      assert stats.rounds == 3  # Initial round + 2 completed rounds
      assert stats.eliminations[1] == ["team2"]
      assert stats.eliminations[2] == ["team3"]
      assert stats.team_stats["team1"].total_guesses == 2
      assert stats.team_stats["team2"].eliminated_in_round == 1
      assert stats.team_stats["team3"].eliminated_in_round == 2
      assert stats.winning_team == "team1"
    end

    test "handles game without completion" do
      events = [
        create_game_started_event(),
        create_guess_processed_event(true, "team1", 1),
        create_guess_processed_event(false, "team2", 1),
        create_team_eliminated_event("team2", 1)
      ]

      {:ok, stats} = StatsCalculator.calculate_knockout_stats(events)

      assert stats.rounds == 1
      assert stats.eliminations[1] == ["team2"]
      assert stats.winning_team == nil
    end
  end

  describe "calculate_race_stats/1" do
    test "calculates race stats correctly" do
      started_event = create_game_started_event(%{config: %{race_target: 5}})

      events = [
        started_event,
        create_guess_processed_event(true, "team1", 1),
        create_guess_processed_event(true, "team1", 1),
        create_guess_processed_event(true, "team2", 1),
        create_guess_processed_event(true, "team1", 1),
        create_guess_processed_event(true, "team1", 1),
        create_guess_processed_event(true, "team1", 1),
        create_game_completed_event(%{winning_team: "team1"})
      ]

      {:ok, stats} = StatsCalculator.calculate_race_stats(events)

      assert stats.team_progress["team1"] == 5
      assert stats.team_progress["team2"] == 1
      assert stats.winning_team == "team1"
      assert stats.match_completion_time > 0
    end

    test "handles race without completion event" do
      started_event = create_game_started_event(%{config: %{race_target: 3}})

      events = [
        started_event,
        create_guess_processed_event(true, "team1", 1),
        create_guess_processed_event(true, "team2", 1),
        create_guess_processed_event(true, "team1", 1),
        create_guess_processed_event(true, "team1", 1)
      ]

      {:ok, stats} = StatsCalculator.calculate_race_stats(events)

      assert stats.team_progress["team1"] == 3
      assert stats.team_progress["team2"] == 1
      assert stats.winning_team == "team1"  # Should determine winner by progress
      assert stats.match_completion_time == nil
    end
  end

  describe "calculate_mode_stats/2" do
    test "routes to appropriate calculator function" do
      events = [create_game_started_event(), create_game_completed_event()]

      # Test routing for each mode
      assert {:ok, _} = StatsCalculator.calculate_mode_stats(events, :two_player)
      assert {:ok, _} = StatsCalculator.calculate_mode_stats(events, :knockout)
      assert {:ok, _} = StatsCalculator.calculate_mode_stats(events, :race)
      assert {:ok, _} = StatsCalculator.calculate_mode_stats(events, :golf_race)  # Uses race stats for now
      assert {:error, :unsupported_mode} = StatsCalculator.calculate_mode_stats(events, :unknown_mode)
    end
  end

  # Helper functions to create test events

  defp create_game_started_event(extra_fields \\ %{}) do
    timestamp = DateTime.utc_now() |> DateTime.add(-60)

    Map.merge(%{
      event_type: "game_started",
      timestamp: timestamp,
      game_id: "test-game-123",
      player_ids: ["p1", "p2", "p3", "p4"],
      team_ids: ["team1", "team2", "team3"],
      config: %{},
      round_number: 1
    }, extra_fields)
  end

  defp create_guess_processed_event(successful, team_id, round, guess_duration \\ 5) do
    %{
      event_type: "guess_processed",
      timestamp: DateTime.utc_now() |> DateTime.add(-30 + :rand.uniform(20)),
      game_id: "test-game-123",
      guess_successful: successful,
      team_id: team_id,
      player_id: "p#{:rand.uniform(4)}",
      round_number: round,
      guess_duration: guess_duration
    }
  end

  defp create_game_completed_event(extra_fields \\ %{}) do
    Map.merge(%{
      event_type: "game_completed",
      timestamp: DateTime.utc_now(),
      game_id: "test-game-123",
      round_number: 1
    }, extra_fields)
  end

  defp create_team_eliminated_event(team_id, round) do
    %{
      event_type: "team_eliminated",
      timestamp: DateTime.utc_now() |> DateTime.add(-20 + round * 5),
      game_id: "test-game-123",
      team_id: team_id,
      round_number: round
    }
  end

  defp create_knockout_round_completed_event(round) do
    %{
      event_type: "knockout_round_completed",
      timestamp: DateTime.utc_now() |> DateTime.add(-15 + round * 5),
      game_id: "test-game-123",
      round_number: round
    }
  end
end
