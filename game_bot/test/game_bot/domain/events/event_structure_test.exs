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

  # Helper to create a valid base event
  defp create_valid_event(opts \\ []) do
    message = create_test_message()
    metadata = Metadata.from_discord_message(message)
    timestamp = Keyword.get(opts, :timestamp, DateTime.utc_now())

    %{
      game_id: Keyword.get(opts, :game_id, "game-123"),
      guild_id: Keyword.get(opts, :guild_id, "guild-123"),
      mode: Keyword.get(opts, :mode, :knockout),
      timestamp: timestamp,
      metadata: metadata
    }
  end

  describe "base_fields/0" do
    test "returns the expected base fields" do
      assert Enum.sort(EventStructure.base_fields()) ==
             Enum.sort([:game_id, :guild_id, :mode, :timestamp, :metadata])
    end
  end

  describe "validate_base_fields/1" do
    test "returns :ok for a valid event" do
      event = create_valid_event()
      assert :ok = EventStructure.validate_base_fields(event)
    end

    test "returns error for missing game_id" do
      event = create_valid_event() |> Map.delete(:game_id)
      assert {:error, "game_id is required"} = EventStructure.validate_base_fields(event)
    end

    test "returns error for missing guild_id" do
      event = create_valid_event() |> Map.delete(:guild_id)
      assert {:error, "guild_id is required"} = EventStructure.validate_base_fields(event)
    end

    test "returns error for missing mode" do
      event = create_valid_event() |> Map.delete(:mode)
      assert {:error, "mode is required"} = EventStructure.validate_base_fields(event)
    end

    test "returns error for missing timestamp" do
      event = create_valid_event() |> Map.delete(:timestamp)
      assert {:error, "timestamp is required"} = EventStructure.validate_base_fields(event)
    end

    test "returns error for missing metadata" do
      event = create_valid_event() |> Map.delete(:metadata)
      assert {:error, "metadata is required"} = EventStructure.validate_base_fields(event)
    end

    test "returns error for empty game_id" do
      event = create_valid_event(game_id: "")
      assert {:error, "game_id and guild_id must be non-empty strings"} = EventStructure.validate_base_fields(event)
    end

    test "returns error for empty guild_id" do
      event = create_valid_event(guild_id: "")
      assert {:error, "game_id and guild_id must be non-empty strings"} = EventStructure.validate_base_fields(event)
    end

    test "returns error for non-atom mode" do
      event = create_valid_event() |> Map.put(:mode, "not_an_atom")
      assert {:error, "mode must be an atom"} = EventStructure.validate_base_fields(event)
    end

    test "returns error for future timestamp" do
      future_time = DateTime.add(DateTime.utc_now(), 3600, :second)
      event = create_valid_event(timestamp: future_time)
      assert {:error, "timestamp cannot be in the future"} = EventStructure.validate_base_fields(event)
    end
  end

  describe "validate_metadata/1" do
    test "returns :ok when metadata has guild_id" do
      event = create_valid_event()
      assert :ok = EventStructure.validate_metadata(event)
    end

    test "returns :ok when metadata has source_id" do
      event = create_valid_event()
      |> Map.put(:metadata, %{"source_id" => "source-123"})
      assert :ok = EventStructure.validate_metadata(event)
    end

    test "returns error when metadata is missing required fields" do
      event = create_valid_event()
      |> Map.put(:metadata, %{})
      assert {:error, "metadata must include guild_id or source_id"} = EventStructure.validate_metadata(event)
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
    test "parses a valid ISO8601 timestamp" do
      timestamp_str = "2023-01-01T12:00:00Z"
      {:ok, expected, _} = DateTime.from_iso8601(timestamp_str)
      assert ^expected = EventStructure.parse_timestamp(timestamp_str)
    end

    test "parses a timestamp with microseconds" do
      timestamp_str = "2023-01-01T12:00:00.123456Z"
      {:ok, expected, _} = DateTime.from_iso8601(timestamp_str)
      assert ^expected = EventStructure.parse_timestamp(timestamp_str)
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
        set: MapSet.new(["a", "b"]),
        time: DateTime.utc_now(),
        list: [1, 2, 3],
        map: %{key: "value"}
      }
      serialized = EventStructure.serialize(data)
      deserialized = EventStructure.deserialize(serialized)

      assert deserialized.set == data.set
      assert DateTime.compare(deserialized.time, data.time) == :eq
      assert deserialized.list == data.list
      assert deserialized.map == %{"key" => "value"}
    end

    test "handles nil values" do
      data = %{field: nil}
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
