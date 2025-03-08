defmodule GameBot.Domain.Events.GameEventsTest do
  use ExUnit.Case, async: true
  alias GameBot.Domain.Events.GameEvents.{GameStarted, GameEnded}

  describe "GameStarted event" do
    test "creates a valid two_player event" do
      event = %GameStarted{
        game_id: "game-123",
        guild_id: "guild-456",
        mode: :two_player,
        round_number: 1,
        team_id: "team-789",
        player_ids: ["player1", "player2"],
        settings: %{
          round_limit: 10,
          time_limit: 300,
          score_limit: 100
        },
        timestamp: DateTime.utc_now(),
        metadata: %{
          source_id: "msg-123",
          correlation_id: "corr-123"
        }
      }

      assert :ok = GameBot.Domain.Events.EventValidator.validate(event)
    end

    test "creates a valid knockout event" do
      event = %GameStarted{
        game_id: "game-123",
        guild_id: "guild-456",
        mode: :knockout,
        round_number: 1,
        team_id: "team-789",
        player_ids: ["player1", "player2", "player3", "player4"],
        settings: %{
          round_limit: 10,
          time_limit: 300,
          score_limit: 100
        },
        timestamp: DateTime.utc_now(),
        metadata: %{
          source_id: "msg-123",
          correlation_id: "corr-123"
        }
      }

      assert :ok = GameBot.Domain.Events.EventValidator.validate(event)
    end

    test "fails validation with invalid player count" do
      event = %GameStarted{
        game_id: "game-123",
        guild_id: "guild-456",
        mode: :two_player,
        round_number: 1,
        team_id: "team-789",
        player_ids: ["player1"], # Only one player for two_player mode
        settings: %{
          round_limit: 10,
          time_limit: 300,
          score_limit: 100
        },
        timestamp: DateTime.utc_now(),
        metadata: %{
          source_id: "msg-123",
          correlation_id: "corr-123"
        }
      }

      assert {:error, "invalid player count for game mode"} = GameBot.Domain.Events.EventValidator.validate(event)
    end

    test "fails validation with missing settings" do
      event = %GameStarted{
        game_id: "game-123",
        guild_id: "guild-456",
        mode: :two_player,
        round_number: 1,
        team_id: "team-789",
        player_ids: ["player1", "player2"],
        settings: %{
          round_limit: 10,
          # Missing time_limit
          score_limit: 100
        },
        timestamp: DateTime.utc_now(),
        metadata: %{
          source_id: "msg-123",
          correlation_id: "corr-123"
        }
      }

      assert {:error, "missing required setting: time_limit"} = GameBot.Domain.Events.EventValidator.validate(event)
    end
  end

  describe "GameEnded event" do
    test "creates a valid event" do
      event = %GameEnded{
        game_id: "game-123",
        guild_id: "guild-456",
        mode: :two_player,
        round_number: 10,
        team_id: "team-789",
        winner_id: "player1",
        final_score: 100,
        round_count: 10,
        duration: 300,
        timestamp: DateTime.utc_now(),
        metadata: %{
          source_id: "msg-123",
          correlation_id: "corr-123"
        }
      }

      assert :ok = GameBot.Domain.Events.EventValidator.validate(event)
    end

    test "fails validation with negative score" do
      event = %GameEnded{
        game_id: "game-123",
        guild_id: "guild-456",
        mode: :two_player,
        round_number: 10,
        team_id: "team-789",
        winner_id: "player1",
        final_score: -1,
        round_count: 10,
        duration: 300,
        timestamp: DateTime.utc_now(),
        metadata: %{
          source_id: "msg-123",
          correlation_id: "corr-123"
        }
      }

      assert {:error, "final_score must be non-negative"} = GameBot.Domain.Events.EventValidator.validate(event)
    end

    test "fails validation with invalid round count" do
      event = %GameEnded{
        game_id: "game-123",
        guild_id: "guild-456",
        mode: :two_player,
        round_number: 10,
        team_id: "team-789",
        winner_id: "player1",
        final_score: 100,
        round_count: 0,
        duration: 300,
        timestamp: DateTime.utc_now(),
        metadata: %{
          source_id: "msg-123",
          correlation_id: "corr-123"
        }
      }

      assert {:error, "round_count must be positive"} = GameBot.Domain.Events.EventValidator.validate(event)
    end

    test "fails validation with negative duration" do
      event = %GameEnded{
        game_id: "game-123",
        guild_id: "guild-456",
        mode: :two_player,
        round_number: 10,
        team_id: "team-789",
        winner_id: "player1",
        final_score: 100,
        round_count: 10,
        duration: -1,
        timestamp: DateTime.utc_now(),
        metadata: %{
          source_id: "msg-123",
          correlation_id: "corr-123"
        }
      }

      assert {:error, "duration must be non-negative"} = GameBot.Domain.Events.EventValidator.validate(event)
    end

    test "serializes and deserializes correctly" do
      original = %GameEnded{
        game_id: "game-123",
        guild_id: "guild-456",
        mode: :two_player,
        round_number: 10,
        team_id: "team-789",
        winner_id: "player1",
        final_score: 100,
        round_count: 10,
        duration: 300,
        timestamp: DateTime.utc_now(),
        metadata: %{
          source_id: "msg-123",
          correlation_id: "corr-123"
        }
      }

      serialized = GameBot.Domain.Events.EventSerializer.to_map(original)
      deserialized = GameBot.Domain.Events.EventSerializer.from_map(serialized)

      assert deserialized.game_id == original.game_id
      assert deserialized.guild_id == original.guild_id
      assert deserialized.mode == original.mode
      assert deserialized.round_number == original.round_number
      assert deserialized.team_id == original.team_id
      assert deserialized.winner_id == original.winner_id
      assert deserialized.final_score == original.final_score
      assert deserialized.round_count == original.round_count
      assert deserialized.duration == original.duration
      assert deserialized.metadata == original.metadata
      assert DateTime.diff(deserialized.timestamp, original.timestamp) < 1
    end
  end
end
