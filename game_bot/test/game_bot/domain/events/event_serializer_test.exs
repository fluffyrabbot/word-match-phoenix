defmodule GameBot.Domain.Events.EventSerializerTest do
  use ExUnit.Case, async: true

  alias GameBot.Domain.Events.{EventSerializer, EventStructure, Metadata, TestEvents}
  alias TestEvents.TestEvent

  # Add test counter to verify execution
  setup do
    IO.puts("\n======= EXECUTING EVENT_SERIALIZER_TEST =======")
    :ok
  end

  # Helper to create a test message
  defp create_test_message do
    %{
      id: "1234",
      channel_id: "channel_id",
      guild_id: "guild_id",
      author: %{id: "1234"}
    }
  end

  # Helper to create a valid test event
  defp create_valid_event(opts \\ []) do
    message = create_test_message()
    metadata = Metadata.from_discord_message(message)
    timestamp = Keyword.get(opts, :timestamp, DateTime.utc_now())

    TestEvents.create_test_event(
      [timestamp: timestamp, metadata: metadata] ++ opts
    )
  end

  describe "to_map/1" do
    test "serializes base fields correctly" do
      event = create_valid_event()
      map = EventSerializer.to_map(event)

      assert map["game_id"] == event.game_id
      assert map["guild_id"] == event.guild_id
      assert map["mode"] == Atom.to_string(event.mode)
      assert map["timestamp"] == DateTime.to_iso8601(event.timestamp)
      assert map["metadata"] == event.metadata
    end

    test "serializes numeric fields correctly" do
      event = create_valid_event(count: 42, score: -10)
      map = EventSerializer.to_map(event)

      assert map["count"] == 42
      assert map["score"] == -10
    end

    test "serializes MapSet correctly" do
      event = create_valid_event(tags: MapSet.new(["a", "b", "c"]))
      map = EventSerializer.to_map(event)

      assert Enum.sort(map["tags"]) == ["a", "b", "c"]
    end

    test "serializes nested structures correctly" do
      nested_time = DateTime.utc_now()
      event = create_valid_event(
        nested_data: %{
          "string" => "value",
          "number" => 42,
          "time" => nested_time,
          "list" => [1, "two", nested_time],
          "map" => %{"key" => "value"}
        }
      )
      map = EventSerializer.to_map(event)

      assert map["nested_data"]["string"] == "value"
      assert map["nested_data"]["number"] == 42
      assert map["nested_data"]["time"] == DateTime.to_iso8601(nested_time)
      assert Enum.at(map["nested_data"]["list"], 0) == 1
      assert Enum.at(map["nested_data"]["list"], 1) == "two"
      assert Enum.at(map["nested_data"]["list"], 2) == DateTime.to_iso8601(nested_time)
      assert map["nested_data"]["map"]["key"] == "value"
    end

    test "handles nil values correctly" do
      event = create_valid_event(
        tags: nil,
        nested_data: nil,
        optional_field: nil
      )
      map = EventSerializer.to_map(event)

      assert map["tags"] == []
      assert map["nested_data"] == nil
      assert map["optional_field"] == nil
    end
  end

  describe "from_map/1" do
    test "deserializes base fields correctly" do
      original = create_valid_event()
      map = EventSerializer.to_map(original)
      reconstructed = EventSerializer.from_map(map)

      assert reconstructed.game_id == original.game_id
      assert reconstructed.guild_id == original.guild_id
      assert reconstructed.mode == original.mode
      assert DateTime.compare(reconstructed.timestamp, original.timestamp) == :eq
      assert reconstructed.metadata == original.metadata
    end

    test "deserializes numeric fields correctly" do
      original = create_valid_event(count: 42, score: -10)
      map = EventSerializer.to_map(original)
      reconstructed = EventSerializer.from_map(map)

      assert reconstructed.count == 42
      assert reconstructed.score == -10
    end

    test "deserializes MapSet correctly" do
      original = create_valid_event(tags: MapSet.new(["a", "b", "c"]))
      map = EventSerializer.to_map(original)
      reconstructed = EventSerializer.from_map(map)

      assert reconstructed.tags == MapSet.new(["a", "b", "c"])
    end

    test "deserializes nested structures correctly" do
      nested_time = DateTime.utc_now()
      original = create_valid_event(
        nested_data: %{
          "string" => "value",
          "number" => 42,
          "time" => nested_time,
          "list" => [1, "two", nested_time],
          "map" => %{"key" => "value"}
        }
      )
      map = EventSerializer.to_map(original)
      reconstructed = EventSerializer.from_map(map)

      assert reconstructed.nested_data["string"] == "value"
      assert reconstructed.nested_data["number"] == 42
      assert DateTime.compare(reconstructed.nested_data["time"], nested_time) == :eq
      assert Enum.at(reconstructed.nested_data["list"], 0) == 1
      assert Enum.at(reconstructed.nested_data["list"], 1) == "two"
      assert DateTime.compare(Enum.at(reconstructed.nested_data["list"], 2), nested_time) == :eq
      assert reconstructed.nested_data["map"]["key"] == "value"
    end

    test "handles nil values correctly" do
      original = create_valid_event(
        tags: nil,
        nested_data: nil,
        optional_field: nil
      )
      map = EventSerializer.to_map(original)
      reconstructed = EventSerializer.from_map(map)

      assert reconstructed.tags == MapSet.new([])
      assert reconstructed.nested_data == nil
      assert reconstructed.optional_field == nil
    end

    test "preserves data types through serialization cycle" do
      original = create_valid_event(
        count: 42,
        score: -10,
        tags: MapSet.new(["a", "b"]),
        nested_data: %{
          "string" => "value",
          "number" => 42,
          "time" => DateTime.utc_now(),
          "list" => [1, "two", DateTime.utc_now()],
          "map" => %{"key" => "value"}
        }
      )
      map = EventSerializer.to_map(original)
      reconstructed = EventSerializer.from_map(map)

      assert is_integer(reconstructed.count)
      assert is_integer(reconstructed.score)
      assert reconstructed.tags.__struct__ == MapSet
      assert is_map(reconstructed.nested_data)
      assert is_binary(reconstructed.nested_data["string"])
      assert is_integer(reconstructed.nested_data["number"])
      assert reconstructed.nested_data["time"].__struct__ == DateTime
      assert is_list(reconstructed.nested_data["list"])
      assert is_map(reconstructed.nested_data["map"])
    end

    test "handles invalid mode atoms" do
      map = %{
        "game_id" => "game-123",
        "guild_id" => "guild-123",
        "mode" => "invalid_mode",
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "metadata" => %{},
        "count" => 1,
        "score" => 100,
        "tags" => [],
        "nested_data" => nil
      }

      # Add :invalid_mode as an existing atom for the test
      # This ensures the test runs correctly
      :invalid_mode

      # Now verify that unknown atoms still raise an error
      map = %{map | "mode" => "really_unknown_mode_xyz"}
      assert_raise ArgumentError, fn ->
        EventSerializer.from_map(map)
      end
    end
  end

  describe "error handling" do
    test "handles invalid DateTime strings" do
      map = %{
        "game_id" => "game-123",
        "guild_id" => "guild-123",
        "mode" => "knockout",
        "timestamp" => "invalid-time",
        "metadata" => %{},
        "count" => 1,
        "score" => 100,
        "tags" => [],
        "nested_data" => nil
      }

      assert_raise RuntimeError, ~r/Invalid timestamp format/, fn ->
        EventSerializer.from_map(map)
      end
    end
  end
end
