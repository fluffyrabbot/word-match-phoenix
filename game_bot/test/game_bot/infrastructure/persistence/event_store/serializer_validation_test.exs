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

      # Create a map with atom keys (simulating a struct that's been converted to a map)
      event_map = %{
        event_type: "game_started",
        event_version: 1,
        data: %{
          game_id: valid_event.game_id,
          guild_id: valid_event.guild_id,
          mode: valid_event.mode,
          timestamp: valid_event.timestamp,
          round_number: valid_event.round_number,
          teams: valid_event.teams,
          team_ids: valid_event.team_ids,
          player_ids: valid_event.player_ids,
          config: valid_event.config,
          started_at: valid_event.started_at
        },
        metadata: valid_event.metadata
      }

      assert {:ok, serialized} = Serializer.serialize(event_map)
      assert is_map(serialized)
      assert serialized["type"] == "game_started"
      assert is_map(serialized["data"])
    end

    test "rejects invalid events" do
      invalid_event = create_valid_game_started()
      |> Map.put(:round_number, 2)  # Invalid round number for game start

      # Convert to map with explicit event_type and event_version
      event_map = %{
        event_type: "game_started",
        event_version: 1,
        data: Map.from_struct(invalid_event),
        metadata: invalid_event.metadata
      }

      assert {:error, _} = Serializer.serialize(event_map)
    end

    test "allows bypassing validation" do
      valid_event = create_valid_game_started()
      |> Map.put(:round_number, 2)  # Invalid round number for game start

      # Create a serialized event with string keys but invalid round_number
      serialized = %{
        "type" => "game_started",
        "version" => 1,
        "data" => %{
          "game_id" => valid_event.game_id,
          "guild_id" => valid_event.guild_id,
          "mode" => valid_event.mode,
          "timestamp" => valid_event.timestamp,
          "round_number" => 2, # Invalid - must be 1 for game start
          "teams" => valid_event.teams,
          "team_ids" => valid_event.team_ids,
          "player_ids" => valid_event.player_ids,
          "config" => valid_event.config,
          "started_at" => valid_event.started_at
        },
        "metadata" => valid_event.metadata
      }

      # With validation
      assert {:error, _} = Serializer.deserialize(serialized)

      # Without validation
      assert {:ok, deserialized} = Serializer.deserialize(serialized, nil, validate: false)
      assert deserialized.round_number == 2
    end
  end

  describe "deserialize/3 with validation" do
    test "deserializes and validates valid events" do
      valid_event = create_valid_game_started()

      # Create a serialized event with string keys (simulating JSON format)
      serialized = %{
        "type" => "game_started",
        "version" => 1,
        "data" => %{
          "game_id" => valid_event.game_id,
          "guild_id" => valid_event.guild_id,
          "mode" => valid_event.mode,
          "timestamp" => valid_event.timestamp,
          "round_number" => valid_event.round_number,
          "teams" => valid_event.teams,
          "team_ids" => valid_event.team_ids,
          "player_ids" => valid_event.player_ids,
          "config" => valid_event.config,
          "started_at" => valid_event.started_at
        },
        "metadata" => valid_event.metadata
      }

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
      valid_event = create_valid_game_started()

      # Create a serialized event with string keys but invalid round_number
      serialized = %{
        "type" => "game_started",
        "version" => 1,
        "data" => %{
          "game_id" => valid_event.game_id,
          "guild_id" => valid_event.guild_id,
          "mode" => valid_event.mode,
          "timestamp" => valid_event.timestamp,
          "round_number" => 2, # Invalid - must be 1 for game start
          "teams" => valid_event.teams,
          "team_ids" => valid_event.team_ids,
          "player_ids" => valid_event.player_ids,
          "config" => valid_event.config,
          "started_at" => valid_event.started_at
        },
        "metadata" => valid_event.metadata
      }

      assert {:error, _} = Serializer.deserialize(serialized)
    end

    test "allows bypassing validation on deserialization" do
      valid_event = create_valid_game_started()

      # Create a serialized event with string keys but invalid round_number
      serialized = %{
        "type" => "game_started",
        "version" => 1,
        "data" => %{
          "game_id" => valid_event.game_id,
          "guild_id" => valid_event.guild_id,
          "mode" => valid_event.mode,
          "timestamp" => valid_event.timestamp,
          "round_number" => 2, # Invalid - must be 1 for game start
          "teams" => valid_event.teams,
          "team_ids" => valid_event.team_ids,
          "player_ids" => valid_event.player_ids,
          "config" => valid_event.config,
          "started_at" => valid_event.started_at
        },
        "metadata" => valid_event.metadata
      }

      # With validation
      assert {:error, _} = Serializer.deserialize(serialized)

      # Without validation
      assert {:ok, deserialized} = Serializer.deserialize(serialized, nil, validate: false)
      assert deserialized.round_number == 2
    end
  end

  describe "end-to-end serialization with validation" do
    test "rejects invalid events in both directions" do
      # Test serialization failure
      invalid_event = create_valid_game_started()
      |> Map.put(:round_number, 0)  # Invalid - must be positive

      # Convert to map with explicit event_type and event_version
      event_map = %{
        event_type: "game_started",
        event_version: 1,
        data: Map.from_struct(invalid_event),
        metadata: invalid_event.metadata
      }

      assert {:error, _} = Serializer.serialize(event_map)

      # Test deserialization failure
      valid_event = create_valid_game_started()

      # Create a serialized event with string keys but invalid round_number
      serialized = %{
        "type" => "game_started",
        "version" => 1,
        "data" => %{
          "game_id" => valid_event.game_id,
          "guild_id" => valid_event.guild_id,
          "mode" => valid_event.mode,
          "timestamp" => valid_event.timestamp,
          "round_number" => 0, # Invalid - must be positive
          "teams" => valid_event.teams,
          "team_ids" => valid_event.team_ids,
          "player_ids" => valid_event.player_ids,
          "config" => valid_event.config,
          "started_at" => valid_event.started_at
        },
        "metadata" => valid_event.metadata
      }

      assert {:error, _} = Serializer.deserialize(serialized)
    end

    test "round-trip serialization preserves data integrity" do
      original_event = create_valid_game_started()

      # Create a serialized event with string keys
      serialized = %{
        "type" => "game_started",
        "version" => 1,
        "data" => %{
          "game_id" => original_event.game_id,
          "guild_id" => original_event.guild_id,
          "mode" => original_event.mode,
          "timestamp" => original_event.timestamp,
          "round_number" => original_event.round_number,
          "teams" => original_event.teams,
          "team_ids" => original_event.team_ids,
          "player_ids" => original_event.player_ids,
          "config" => original_event.config,
          "started_at" => original_event.started_at
        },
        "metadata" => original_event.metadata
      }

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
      player1_id: "playerbob",
      player2_id: "playeralice",
      player1_word: "apple",
      player2_word: "banana",
      guess_successful: true,
      match_score: 10,
      guess_count: 1,
      round_guess_count: 1,
      total_guesses: 5,
      guess_duration: 30,
      player1_duration: 25,
      player2_duration: 30
    }
  end
end
