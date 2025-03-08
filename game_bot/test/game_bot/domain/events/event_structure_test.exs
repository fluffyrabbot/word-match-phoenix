defmodule GameBot.Domain.Events.EventStructureTest do
  use ExUnit.Case, async: true

  alias GameBot.Domain.Events.{EventStructure, Metadata}

  # Helper to create a test message
  defp create_test_message do
    %{
      id: "1234",
      channel_id: "channel_id",
      guild_id: "guild_id",
      author: %{id: "1234"}
    }
  end

  # Helper function to create a valid event for testing
  defp create_valid_event do
    %{
      game_id: "game-123",
      guild_id: "guild-456",
      mode: :two_player,
      timestamp: DateTime.utc_now(),
      metadata: %{
        source_id: "source-123",
        correlation_id: "corr-456",
        guild_id: "guild-456"
      }
    }
  end

  describe "base_fields/0" do
    test "returns the expected base fields" do
      assert Enum.sort(EventStructure.base_fields()) ==
             Enum.sort([:game_id, :guild_id, :mode, :timestamp, :metadata])
    end
  end

  describe "validate_base_fields/1" do
    test "validates required fields exist" do
      event = create_valid_event()
      assert :ok = EventStructure.validate_base_fields(event)
    end

    test "returns error for missing fields" do
      event = create_valid_event() |> Map.delete(:game_id)
      assert {:error, "game_id is required"} = EventStructure.validate_base_fields(event)
    end

    test "validates timestamp is not in future" do
      future_time = DateTime.utc_now() |> DateTime.add(3600, :second)
      event = create_valid_event() |> Map.put(:timestamp, future_time)
      assert {:error, "timestamp cannot be in the future"} = EventStructure.validate_base_fields(event)
    end
  end

  describe "validate_metadata/1" do
    test "returns :ok when metadata has required fields" do
      event = create_valid_event()
      assert :ok = EventStructure.validate_metadata(event)
    end

    test "returns error when metadata is missing required fields" do
      event = create_valid_event()
      |> Map.put(:metadata, %{})
      assert {:error, "source_id is required in metadata"} = EventStructure.validate_metadata(event)
    end

    test "returns error when metadata is not a map" do
      event = create_valid_event()
      |> Map.put(:metadata, "not a map")
      assert {:error, "metadata must be a map"} = EventStructure.validate_metadata(event)
    end
  end

  describe "validate_types/2" do
    test "validates types correctly" do
      event = create_valid_event()
      type_checks = %{
        game_id: &is_binary/1,
        guild_id: &is_binary/1,
        mode: &is_atom/1
      }
      assert :ok = EventStructure.validate_types(event, type_checks)
    end

    test "returns error for invalid type" do
      event = create_valid_event() |> Map.put(:game_id, 123)
      type_checks = %{game_id: &is_binary/1}
      assert {:error, "game_id has invalid type"} = EventStructure.validate_types(event, type_checks)
    end

    test "ignores nil values" do
      event = create_valid_event() |> Map.put(:optional_field, nil)
      type_checks = %{optional_field: &is_binary/1}
      assert :ok = EventStructure.validate_types(event, type_checks)
    end
  end

  describe "parse_timestamp/1" do
    test "parses valid ISO8601 timestamp" do
      timestamp = "2023-01-01T12:00:00Z"
      assert %DateTime{} = EventStructure.parse_timestamp(timestamp)
    end

    test "handles nil input" do
      assert EventStructure.parse_timestamp(nil) == nil
    end

    test "raises an error for invalid timestamp format" do
      assert_raise RuntimeError, ~r/Invalid timestamp format/, fn ->
        EventStructure.parse_timestamp("invalid-timestamp")
      end
    end
  end

  describe "create_event_map/5" do
    test "creates a valid event map with all base fields" do
      message = create_test_message()
      metadata = Metadata.from_discord_message(message)

      event_map = EventStructure.create_event_map("game-123", "guild-123", :knockout, metadata)

      assert event_map.game_id == "game-123"
      assert event_map.guild_id == "guild-123"
      assert event_map.mode == :knockout
      assert %DateTime{} = event_map.timestamp
      assert event_map.metadata == metadata
    end

    test "creates a valid event map with custom timestamp" do
      message = create_test_message()
      metadata = Metadata.from_discord_message(message)
      custom_timestamp = DateTime.from_naive!(~N[2023-01-01 00:00:00], "Etc/UTC")

      event_map = EventStructure.create_event_map(
        "game-123",
        "guild-123",
        :knockout,
        metadata,
        timestamp: custom_timestamp
      )

      assert event_map.game_id == "game-123"
      assert event_map.guild_id == "guild-123"
      assert event_map.mode == :knockout
      assert event_map.timestamp == custom_timestamp
      assert event_map.metadata == metadata
    end
  end

  describe "serialization" do
    test "serializes and deserializes DateTime" do
      dt = DateTime.utc_now()
      serialized = EventStructure.serialize(dt)
      deserialized = EventStructure.deserialize(serialized)
      assert DateTime.compare(dt, deserialized) == :eq
    end

    test "serializes and deserializes MapSet" do
      set = MapSet.new(["a", "b", "c"])
      serialized = EventStructure.serialize(set)
      deserialized = EventStructure.deserialize(serialized)
      assert deserialized == set
    end

    test "serializes and deserializes nested structures" do
      data = %{
        "set" => MapSet.new(["a", "b"]),
        "time" => DateTime.utc_now(),
        "list" => [1, 2, 3],
        "map" => %{"key" => "value"}
      }
      serialized = EventStructure.serialize(data)
      deserialized = EventStructure.deserialize(serialized)

      assert deserialized["set"] == data["set"]
      assert DateTime.compare(deserialized["time"], data["time"]) == :eq
      assert deserialized["list"] == data["list"]
      assert deserialized["map"] == data["map"]
    end

    test "handles nil values" do
      data = %{"field" => nil}
      serialized = EventStructure.serialize(data)
      deserialized = EventStructure.deserialize(serialized)
      assert deserialized == data
    end

    test "preserves non-struct maps" do
      data = %{"key" => "value"}
      serialized = EventStructure.serialize(data)
      deserialized = EventStructure.deserialize(serialized)
      assert deserialized == data
    end
  end
end
