defmodule GameBot.Domain.Events.GuessEventsTest do
  use ExUnit.Case
  alias GameBot.Domain.Events.{GuessMatched, GuessNotMatched}

  describe "GuessMatched" do
    test "creates a valid event" do
      event = %GuessMatched{
        game_id: "game123",
        team_id: "team123",
        player1_id: "player1",
        player2_id: "player2",
        player1_word: "word1",
        player2_word: "word2",
        score: 10,
        timestamp: DateTime.utc_now(),
        guild_id: "guild123",
        metadata: %{"round" => 1}
      }

      assert :ok = GuessMatched.validate(event)
      assert "guess_matched" = GuessMatched.event_type()
      assert 1 = GuessMatched.event_version()
    end

    test "fails validation with missing required fields" do
      event = %GuessMatched{
        game_id: "game123",
        team_id: "team123",
        timestamp: DateTime.utc_now(),
        guild_id: "guild123"
      }

      assert {:error, "player1_id is required"} = GuessMatched.validate(event)
    end

    test "converts to and from map" do
      original = %GuessMatched{
        game_id: "game123",
        team_id: "team123",
        player1_id: "player1",
        player2_id: "player2",
        player1_word: "word1",
        player2_word: "word2",
        score: 10,
        timestamp: DateTime.utc_now(),
        guild_id: "guild123",
        metadata: %{"round" => 1}
      }

      map = GuessMatched.to_map(original)
      reconstructed = GuessMatched.from_map(map)

      assert reconstructed.game_id == original.game_id
      assert reconstructed.team_id == original.team_id
      assert reconstructed.player1_id == original.player1_id
      assert reconstructed.player2_id == original.player2_id
      assert reconstructed.player1_word == original.player1_word
      assert reconstructed.player2_word == original.player2_word
      assert reconstructed.score == original.score
      assert reconstructed.guild_id == original.guild_id
      assert reconstructed.metadata == original.metadata
    end
  end

  describe "GuessNotMatched" do
    test "creates a valid event" do
      event = %GuessNotMatched{
        game_id: "game123",
        team_id: "team123",
        player1_id: "player1",
        player2_id: "player2",
        player1_word: "word1",
        player2_word: "word2",
        timestamp: DateTime.utc_now(),
        guild_id: "guild123",
        metadata: %{"round" => 1}
      }

      assert :ok = GuessNotMatched.validate(event)
      assert "guess_not_matched" = GuessNotMatched.event_type()
      assert 1 = GuessNotMatched.event_version()
    end

    test "fails validation with missing required fields" do
      event = %GuessNotMatched{
        game_id: "game123",
        team_id: "team123",
        timestamp: DateTime.utc_now(),
        guild_id: "guild123"
      }

      assert {:error, "player1_id is required"} = GuessNotMatched.validate(event)
    end

    test "converts to and from map" do
      original = %GuessNotMatched{
        game_id: "game123",
        team_id: "team123",
        player1_id: "player1",
        player2_id: "player2",
        player1_word: "word1",
        player2_word: "word2",
        timestamp: DateTime.utc_now(),
        guild_id: "guild123",
        metadata: %{"round" => 1}
      }

      map = GuessNotMatched.to_map(original)
      reconstructed = GuessNotMatched.from_map(map)

      assert reconstructed.game_id == original.game_id
      assert reconstructed.team_id == original.team_id
      assert reconstructed.player1_id == original.player1_id
      assert reconstructed.player2_id == original.player2_id
      assert reconstructed.player1_word == original.player1_word
      assert reconstructed.player2_word == original.player2_word
      assert reconstructed.guild_id == original.guild_id
      assert reconstructed.metadata == original.metadata
    end
  end
end
