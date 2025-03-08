defmodule GameBot.Domain.Events.EventBuilderTest do
  use ExUnit.Case, async: true

  alias GameBot.Domain.Events.{Metadata, ErrorEvents, GuessEvents}

  describe "event creation with EventBuilder" do
    test "creates a valid event with proper attributes" do
      metadata = %{
        source_id: "test-123",
        correlation_id: "corr-456"
      }

      attrs = %{
        game_id: "game-123",
        guild_id: "guild-456",
        team_id: "team-789",
        player_id: "player-101",
        word: "apple",
        reason: :invalid_word
      }

      assert {:ok, event} = ErrorEvents.GuessError.create(
        "game-123",
        "guild-456",
        "team-789",
        "player-101",
        "apple",
        :invalid_word,
        metadata
      )

      assert event.game_id == "game-123"
      assert event.guild_id == "guild-456"
      assert event.team_id == "team-789"
      assert event.player_id == "player-101"
      assert event.word == "apple"
      assert event.reason == :invalid_word
      assert event.metadata.source_id == "test-123"
      assert event.metadata.correlation_id == "corr-456"
      assert %DateTime{} = event.timestamp
    end

    test "returns error with invalid attributes" do
      metadata = %{
        source_id: "test-123",
        correlation_id: "corr-456"
      }

      attrs = %{
        # Missing required fields
        team_id: "team-789",
        player_id: "player-101",
        word: "apple",
        reason: :invalid_word
      }

      result = ErrorEvents.GuessError.new(attrs, metadata)
      assert match?({:error, {:validation, _}}, result)
    end

    test "returns error with invalid metadata" do
      metadata = %{
        # Missing required fields
        source_id: nil
      }

      attrs = %{
        game_id: "game-123",
        guild_id: "guild-456",
        team_id: "team-789",
        player_id: "player-101",
        word: "apple",
        reason: :invalid_word
      }

      result = ErrorEvents.GuessError.new(attrs, metadata)
      assert match?({:error, {:validation, _}}, result)
    end

    test "returns error when field has incorrect type" do
      metadata = %{
        source_id: "test-123",
        correlation_id: "corr-456"
      }

      attrs = %{
        game_id: "game-123",
        guild_id: "guild-456",
        team_id: "team-789",
        player_id: "player-101",
        word: 123, # Should be a string
        reason: :invalid_word
      }

      result = ErrorEvents.GuessError.new(attrs, metadata)
      assert match?({:error, {:validation, _}}, result)
    end
  end

  describe "event serialization" do
    test "serializes event to map with to_map" do
      metadata = %{
        source_id: "test-123",
        correlation_id: "corr-456"
      }

      {:ok, event} = ErrorEvents.GuessError.create(
        "game-123",
        "guild-456",
        "team-789",
        "player-101",
        "apple",
        :invalid_word,
        metadata
      )

      map = ErrorEvents.GuessError.to_map(event)
      assert is_map(map)
      assert map["game_id"] == "game-123"
      assert map["guild_id"] == "guild-456"
      assert map["team_id"] == "team-789"
      assert map["player_id"] == "player-101"
      assert map["word"] == "apple"
      assert map["reason"] == "invalid_word"
      assert is_binary(map["timestamp"])
      assert is_map(map["metadata"])
      assert map["metadata"]["source_id"] == "test-123"
      assert map["metadata"]["correlation_id"] == "corr-456"
    end

    test "deserializes map to event with from_map" do
      map = %{
        "game_id" => "game-123",
        "guild_id" => "guild-456",
        "team_id" => "team-789",
        "player_id" => "player-101",
        "word" => "apple",
        "reason" => "invalid_word",
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "metadata" => %{
          "source_id" => "test-123",
          "correlation_id" => "corr-456"
        }
      }

      event = ErrorEvents.GuessError.from_map(map)
      assert event.game_id == "game-123"
      assert event.guild_id == "guild-456"
      assert event.team_id == "team-789"
      assert event.player_id == "player-101"
      assert event.word == "apple"
      assert event.reason == :invalid_word
      assert %DateTime{} = event.timestamp
      assert event.metadata["source_id"] == "test-123"
      assert event.metadata["correlation_id"] == "corr-456"
    end
  end

  describe "GameEvents behavior implementation" do
    test "validates events through the behavior functions" do
      metadata = %{
        source_id: "test-123",
        correlation_id: "corr-456"
      }

      {:ok, event} = ErrorEvents.GuessError.create(
        "game-123",
        "guild-456",
        "team-789",
        "player-101",
        "apple",
        :invalid_word,
        metadata
      )

      assert :ok = ErrorEvents.GuessError.validate(event)
    end

    test "gets event type through behavior functions" do
      assert ErrorEvents.GuessError.event_type() == "guess_error"
    end

    test "gets event version through behavior functions" do
      assert ErrorEvents.GuessError.event_version() == 1
    end
  end
end
