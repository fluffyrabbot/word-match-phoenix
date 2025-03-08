defmodule GameBot.Domain.Events.GuessEventsTest do
  use ExUnit.Case, async: true
  alias GameBot.Domain.Events.GameEvents.GuessProcessed

  describe "GuessProcessed" do
    test "creates a valid event with successful guess" do
      event = %GuessProcessed{
        game_id: "game123",
        guild_id: "guild123",
        mode: :two_player,
        round_number: 1,
        team_id: "team123",
        player1_info: %{player_id: "player1", team_id: "team123"},
        player2_info: %{player_id: "player2", team_id: "team123"},
        player1_word: "word1",
        player2_word: "word1",
        guess_successful: true,
        match_score: 10,
        guess_count: 1,
        round_guess_count: 1,
        total_guesses: 1,
        guess_duration: 1000,
        timestamp: DateTime.utc_now(),
        metadata: %{"guild_id" => "guild123"}
      }

      assert :ok = GuessProcessed.validate(event)
      assert "guess_processed" = GuessProcessed.event_type()
      assert 1 = GuessProcessed.event_version()
    end

    test "creates a valid event with unsuccessful guess" do
      event = %GuessProcessed{
        game_id: "game123",
        guild_id: "guild123",
        mode: :two_player,
        round_number: 1,
        team_id: "team123",
        player1_info: %{player_id: "player1", team_id: "team123"},
        player2_info: %{player_id: "player2", team_id: "team123"},
        player1_word: "word1",
        player2_word: "word2",
        guess_successful: false,
        match_score: nil,
        guess_count: 1,
        round_guess_count: 1,
        total_guesses: 1,
        guess_duration: 1000,
        timestamp: DateTime.utc_now(),
        metadata: %{"guild_id" => "guild123"}
      }

      assert :ok = GuessProcessed.validate(event)
    end

    test "fails validation with missing required fields" do
      event = %GuessProcessed{
        game_id: "game123",
        guild_id: "guild123",
        mode: :two_player,
        round_number: 1,
        team_id: "team123",
        timestamp: DateTime.utc_now(),
        metadata: %{"guild_id" => "guild123"}
      }

      assert {:error, "player1_info is required"} = GuessProcessed.validate(event)
    end

    test "converts to and from map" do
      original = %GuessProcessed{
        game_id: "game123",
        guild_id: "guild123",
        mode: :two_player,
        round_number: 1,
        team_id: "team123",
        player1_info: %{player_id: "player1", team_id: "team123"},
        player2_info: %{player_id: "player2", team_id: "team123"},
        player1_word: "word1",
        player2_word: "word1",
        guess_successful: true,
        match_score: 10,
        guess_count: 1,
        round_guess_count: 1,
        total_guesses: 1,
        guess_duration: 1000,
        timestamp: DateTime.utc_now(),
        metadata: %{"guild_id" => "guild123"}
      }

      map = GuessProcessed.to_map(original)
      reconstructed = GuessProcessed.from_map(map)

      assert reconstructed.game_id == original.game_id
      assert reconstructed.team_id == original.team_id
      assert reconstructed.player1_info == original.player1_info
      assert reconstructed.player2_info == original.player2_info
      assert reconstructed.player1_word == original.player1_word
      assert reconstructed.player2_word == original.player2_word
      assert reconstructed.guess_successful == original.guess_successful
      assert reconstructed.match_score == original.match_score
      assert reconstructed.guess_count == original.guess_count
      assert reconstructed.round_guess_count == original.round_guess_count
      assert reconstructed.total_guesses == original.total_guesses
      assert reconstructed.guess_duration == original.guess_duration
      assert reconstructed.metadata == original.metadata
      assert DateTime.diff(reconstructed.timestamp, original.timestamp) == 0
    end
  end
end
