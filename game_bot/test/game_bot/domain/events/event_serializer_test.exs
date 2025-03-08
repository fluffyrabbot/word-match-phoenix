defmodule GameBot.Domain.Events.EventSerializerTest do
  use ExUnit.Case, async: true

  alias GameBot.Domain.Events.{EventSerializer, EventStructure, Metadata}

  # Test event struct for serialization
  defmodule TestEvent do
    @moduledoc "Test event struct for serialization tests"
    defstruct [
      :game_id,
      :guild_id,
      :mode,
      :timestamp,
      :metadata,
      :count,
      :score,
      :tags,
      :nested_data,
      :optional_field
    ]

    defimpl EventSerializer do
      def to_map(event) do
        %{
          "game_id" => event.game_id,
          "guild_id" => event.guild_id,
          "mode" => Atom.to_string(event.mode),
          "timestamp" => DateTime.to_iso8601(event.timestamp),
          "metadata" => event.metadata,
          "count" => event.count,
          "score" => event.score,
          "tags" => MapSet.to_list(event.tags),
          "nested_data" => serialize_nested(event.nested_data),
          "optional_field" => event.optional_field
        }
      end

      def from_map(data) do
        %TestEvent{
          game_id: data["game_id"],
          guild_id: data["guild_id"],
          mode: String.to_existing_atom(data["mode"]),
          timestamp: EventStructure.parse_timestamp(data["timestamp"]),
          metadata: data["metadata"],
          count: data["count"],
          score: data["score"],
          tags: MapSet.new(data["tags"] || []),
          nested_data: deserialize_nested(data["nested_data"]),
          optional_field: data["optional_field"]
        }
      end

      defp serialize_nested(nil), do: nil
      defp serialize_nested(data) when is_map(data) do
        Enum.map(data, fn {k, v} -> {to_string(k), serialize_nested(v)} end)
        |> Map.new()
      end
      defp serialize_nested(data) when is_list(data) do
        Enum.map(data, &serialize_nested/1)
      end
      defp serialize_nested(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
      defp serialize_nested(other), do: other

      defp deserialize_nested(nil), do: nil
      defp deserialize_nested(data) when is_map(data) do
        Enum.map(data, fn {k, v} -> {k, deserialize_nested(v)} end)
        |> Map.new()
      end
      defp deserialize_nested(data) when is_list(data) do
        Enum.map(data, &deserialize_nested/1)
      end
      defp deserialize_nested(data) when is_binary(data) and String.contains?(data, "T") do
        case DateTime.from_iso8601(data) do
          {:ok, dt, _} -> dt
          _ -> data
        end
      end
      defp deserialize_nested(other), do: other
    end
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

    %TestEvent{
      game_id: Keyword.get(opts, :game_id, "game-123"),
      guild_id: Keyword.get(opts, :guild_id, "guild-123"),
      mode: Keyword.get(opts, :mode, :knockout),
      timestamp: timestamp,
      metadata: metadata,
      count: Keyword.get(opts, :count, 1),
      score: Keyword.get(opts, :score, 100),
      tags: Keyword.get(opts, :tags, MapSet.new(["tag1", "tag2"])),
      nested_data: Keyword.get(opts, :nested_data, %{
        "key" => "value",
        "time" => DateTime.utc_now(),
        "list" => [1, 2, 3],
        "nested" => %{"inner" => "value"}
      }),
      optional_field: Keyword.get(opts, :optional_field)
    }
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

      assert_raise ArgumentError, fn ->
        EventSerializer.from_map(map)
      end
    end
  end
end
