defmodule GameBot.Domain.Events.GuessEventsTest do
  use ExUnit.Case, async: true
  alias GameBot.Domain.Events.{GuessMatched, GuessNotMatched}
  alias GameBot.Domain.Events.GuessEvents.GuessProcessed

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

  describe "GuessProcessed event" do
    test "creates a valid event" do
      event = GuessProcessed.new(
        "game-123",
        "guild-456",
        :two_player,
        1,
        "team-789",
        %{player_id: "player1", name: "Player 1"},
        %{player_id: "player2", name: "Player 2"},
        "word1",
        "word2",
        true,
        10,
        1,
        1,
        1,
        100,
        %{source_id: "msg-123", correlation_id: "corr-123"}
      )

      assert event.game_id == "game-123"
      assert event.guild_id == "guild-456"
      assert event.mode == :two_player
      assert event.round_number == 1
      assert event.team_id == "team-789"
      assert event.player1_info == %{player_id: "player1", name: "Player 1"}
      assert event.player2_info == %{player_id: "player2", name: "Player 2"}
      assert event.player1_word == "word1"
      assert event.player2_word == "word2"
      assert event.guess_successful == true
      assert event.match_score == 10
      assert event.guess_count == 1
      assert event.round_guess_count == 1
      assert event.total_guesses == 1
      assert event.guess_duration == 100
      assert event.metadata == %{source_id: "msg-123", correlation_id: "corr-123"}
      assert DateTime.diff(event.timestamp, DateTime.utc_now()) < 1
    end

    test "validates required fields" do
      assert {:error, _} = GuessProcessed.new(
        nil,
        "guild-456",
        :two_player,
        1,
        "team-789",
        %{player_id: "player1"},
        %{player_id: "player2"},
        "word1",
        "word2",
        true,
        10,
        1,
        1,
        1,
        100,
        %{source_id: "msg-123"}
      )

      assert {:error, _} = GuessProcessed.new(
        "game-123",
        nil,
        :two_player,
        1,
        "team-789",
        %{player_id: "player1"},
        %{player_id: "player2"},
        "word1",
        "word2",
        true,
        10,
        1,
        1,
        1,
        100,
        %{source_id: "msg-123"}
      )

      assert {:error, _} = GuessProcessed.new(
        "game-123",
        "guild-456",
        :two_player,
        1,
        "team-789",
        %{player_id: "player1"},
        %{player_id: "player2"},
        "word1",
        "word2",
        true,
        10,
        1,
        1,
        1,
        100,
        %{}
      )
    end

    test "validates non-negative counts" do
      assert {:error, _} = GuessProcessed.new(
        "game-123",
        "guild-456",
        :two_player,
        1,
        "team-789",
        %{player_id: "player1"},
        %{player_id: "player2"},
        "word1",
        "word2",
        true,
        10,
        -1,
        1,
        1,
        100,
        %{source_id: "msg-123"}
      )

      assert {:error, _} = GuessProcessed.new(
        "game-123",
        "guild-456",
        :two_player,
        1,
        "team-789",
        %{player_id: "player1"},
        %{player_id: "player2"},
        "word1",
        "word2",
        true,
        10,
        1,
        -1,
        1,
        100,
        %{source_id: "msg-123"}
      )

      assert {:error, _} = GuessProcessed.new(
        "game-123",
        "guild-456",
        :two_player,
        1,
        "team-789",
        %{player_id: "player1"},
        %{player_id: "player2"},
        "word1",
        "word2",
        true,
        10,
        1,
        1,
        -1,
        100,
        %{source_id: "msg-123"}
      )
    end

    test "validates non-negative duration" do
      assert {:error, _} = GuessProcessed.new(
        "game-123",
        "guild-456",
        :two_player,
        1,
        "team-789",
        %{player_id: "player1"},
        %{player_id: "player2"},
        "word1",
        "word2",
        true,
        10,
        1,
        1,
        1,
        -100,
        %{source_id: "msg-123"}
      )
    end

    test "serializes and deserializes correctly" do
      original = GuessProcessed.new(
        "game-123",
        "guild-456",
        :two_player,
        1,
        "team-789",
        %{player_id: "player1"},
        %{player_id: "player2"},
        "word1",
        "word2",
        true,
        10,
        1,
        1,
        1,
        100,
        %{source_id: "msg-123"}
      )

      serialized = GameBot.Domain.Events.EventSerializer.to_map(original)
      deserialized = GameBot.Domain.Events.EventSerializer.from_map(serialized)

      assert deserialized.game_id == original.game_id
      assert deserialized.guild_id == original.guild_id
      assert deserialized.mode == original.mode
      assert deserialized.round_number == original.round_number
      assert deserialized.team_id == original.team_id
      assert deserialized.player1_info == original.player1_info
      assert deserialized.player2_info == original.player2_info
      assert deserialized.player1_word == original.player1_word
      assert deserialized.player2_word == original.player2_word
      assert deserialized.guess_successful == original.guess_successful
      assert deserialized.match_score == original.match_score
      assert deserialized.guess_count == original.guess_count
      assert deserialized.round_guess_count == original.round_guess_count
      assert deserialized.total_guesses == original.total_guesses
      assert deserialized.guess_duration == original.guess_duration
      assert deserialized.metadata == original.metadata
      assert DateTime.diff(deserialized.timestamp, original.timestamp) < 1
    end
  end
end
