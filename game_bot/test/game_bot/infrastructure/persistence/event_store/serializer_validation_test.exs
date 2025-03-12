defmodule GameBot.Infrastructure.Persistence.EventStore.SerializerValidationTest do
  @moduledoc """
  Tests for the validation integration in the EventStore serializer.
  """

  use ExUnit.Case, async: true
  alias GameBot.Infrastructure.Persistence.EventStore.Serializer
  alias GameBot.Domain.Events.GameEvents.{GameStarted, GuessProcessed}

  describe "serialize/2 with validation" do
    test "serializes valid events" do
      valid_event = create_valid_game_started()

      assert {:ok, serialized} = Serializer.serialize(valid_event)
      assert is_map(serialized)
      assert serialized["type"] == "game_started"
      assert is_map(serialized["data"])
    end

    test "rejects invalid events" do
      invalid_event = create_valid_game_started()
      |> Map.put(:round_number, 2)  # Invalid round number for game start

      assert {:error, _} = Serializer.serialize(invalid_event)
    end

    test "allows bypassing validation" do
      invalid_event = create_valid_game_started()
      |> Map.put(:round_number, 2)  # Invalid for validation

      # With validation
      assert {:error, _} = Serializer.serialize(invalid_event)

      # Without validation
      assert {:ok, serialized} = Serializer.serialize(invalid_event, validate: false)
      assert serialized["data"]["round_number"] == 2
    end
  end

  describe "deserialize/3 with validation" do
    test "deserializes and validates valid events" do
      valid_event = create_valid_game_started()
      {:ok, serialized} = Serializer.serialize(valid_event, validate: false)

      assert {:ok, deserialized} = Serializer.deserialize(serialized)
      assert deserialized.__struct__ == GameStarted
      assert deserialized.round_number == 1
    end

    test "rejects serialized data with invalid structure" do
      # Missing required fields
      invalid_data = %{
        "type" => "game_started",
        "version" => 1,
        # Missing "data" field
        "metadata" => %{}
      }

      assert {:error, _} = Serializer.deserialize(invalid_data)
    end

    test "rejects deserializing to invalid events" do
      # Create valid data for serialization
      valid_event = create_valid_game_started()
      {:ok, serialized} = Serializer.serialize(valid_event, validate: false)

      # Modify the data to make it invalid for deserialization
      invalid_serialized = put_in(serialized, ["data", "round_number"], 2)

      assert {:error, _} = Serializer.deserialize(invalid_serialized)
    end

    test "allows bypassing validation on deserialization" do
      valid_event = create_valid_game_started()
      {:ok, serialized} = Serializer.serialize(valid_event, validate: false)

      # Make the data invalid
      invalid_serialized = put_in(serialized, ["data", "round_number"], 2)

      # With validation
      assert {:error, _} = Serializer.deserialize(invalid_serialized)

      # Without validation
      assert {:ok, deserialized} = Serializer.deserialize(invalid_serialized, nil, validate: false)
      assert deserialized.round_number == 2
    end
  end

  describe "end-to-end serialization with validation" do
    test "rejects invalid events in both directions" do
      # Test serialization failure
      invalid_event = create_valid_game_started()
      |> Map.put(:round_number, 0)  # Invalid - must be positive

      assert {:error, _} = Serializer.serialize(invalid_event)

      # Test deserialization failure
      valid_event = create_valid_game_started()
      {:ok, serialized} = Serializer.serialize(valid_event, validate: false)
      invalid_serialized = put_in(serialized, ["data", "round_number"], 0)

      assert {:error, _} = Serializer.deserialize(invalid_serialized)
    end

    test "round-trip serialization preserves data integrity" do
      original_event = create_valid_game_started()

      {:ok, serialized} = Serializer.serialize(original_event)
      {:ok, deserialized} = Serializer.deserialize(serialized)

      # Verify key fields are preserved
      assert deserialized.__struct__ == original_event.__struct__
      assert deserialized.game_id == original_event.game_id
      assert deserialized.guild_id == original_event.guild_id
      assert deserialized.round_number == original_event.round_number
      assert deserialized.teams == original_event.teams
      assert deserialized.team_ids == original_event.team_ids
      assert deserialized.player_ids == original_event.player_ids
    end
  end

  # Helper functions for creating valid test events

  defp create_valid_game_started do
    %GameStarted{
      game_id: "game123",
      guild_id: "guild456",
      mode: :standard,
      timestamp: DateTime.utc_now(),
      metadata: %{source_id: "src123", correlation_id: "corr123"},
      round_number: 1,
      teams: %{"team1" => ["player1", "player2"], "team2" => ["player3", "player4"]},
      team_ids: ["team1", "team2"],
      player_ids: ["player1", "player2", "player3", "player4"],
      config: %{},
      started_at: DateTime.utc_now()
    }
  end

  defp create_valid_guess_processed do
    %GuessProcessed{
      game_id: "game123",
      guild_id: "guild456",
      mode: :standard,
      timestamp: DateTime.utc_now(),
      metadata: %{source_id: "src123", correlation_id: "corr123"},
      round_number: 1,
      team_id: "team1",
      player1_info: %{id: "player1", name: "Player 1"},
      player2_info: %{id: "player2", name: "Player 2"},
      player1_word: "apple",
      player2_word: "banana",
      guess_successful: true,
      match_score: 10,
      guess_count: 1,
      round_guess_count: 1,
      total_guesses: 5,
      guess_duration: 30
    }
  end
end
