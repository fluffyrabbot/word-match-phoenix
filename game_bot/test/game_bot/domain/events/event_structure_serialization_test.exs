defmodule GameBot.Domain.Events.EventStructureSerializationTest do
  use ExUnit.Case, async: true

  alias GameBot.Domain.Events.EventStructure

  # Define test structs for serialization testing
  defmodule SimpleTestStruct do
    defstruct [:name, :value]
  end

  defmodule ComplexTestStruct do
    defstruct [:name, :nested, :list, :map]
  end

  describe "EventStructure serialization" do
    test "serializes and deserializes DateTime objects" do
      # Create a DateTime object
      timestamp = DateTime.utc_now()
      data = %{"timestamp" => timestamp}

      # Serialize
      serialized = EventStructure.serialize(data)

      # Verify it's serialized to ISO8601 string
      assert is_binary(serialized["timestamp"])
      assert String.contains?(serialized["timestamp"], "T")

      # Deserialize
      deserialized = EventStructure.deserialize(serialized)

      # Verify it's a DateTime object again
      assert %DateTime{} = deserialized["timestamp"]
      assert DateTime.compare(timestamp, deserialized["timestamp"]) == :eq
    end

    test "serializes and deserializes nested maps" do
      # Create a nested map
      timestamp = DateTime.utc_now()
      original = %{
        "level1" => %{
          "level2" => %{
            "level3" => "value",
            "timestamp" => timestamp
          }
        }
      }

      # Serialize
      serialized = EventStructure.serialize(original)

      # Verify it's still nested and the timestamp is a string
      assert is_map(serialized["level1"])
      assert is_map(serialized["level1"]["level2"])
      assert serialized["level1"]["level2"]["level3"] == "value"
      assert is_binary(serialized["level1"]["level2"]["timestamp"])

      # Deserialize
      deserialized = EventStructure.deserialize(serialized)

      # Verify structure is preserved and timestamp is a DateTime again
      assert is_map(deserialized["level1"])
      assert is_map(deserialized["level1"]["level2"])
      assert deserialized["level1"]["level2"]["level3"] == "value"
      assert %DateTime{} = deserialized["level1"]["level2"]["timestamp"]
      assert DateTime.compare(timestamp, deserialized["level1"]["level2"]["timestamp"]) == :eq
    end

    test "serializes and deserializes lists of maps" do
      # Create a list of maps
      timestamps = [DateTime.utc_now(), DateTime.utc_now()]
      original = %{
        "items" => [
          %{"id" => 1, "name" => "Item 1", "created_at" => Enum.at(timestamps, 0)},
          %{"id" => 2, "name" => "Item 2", "created_at" => Enum.at(timestamps, 1)}
        ]
      }

      # Serialize
      serialized = EventStructure.serialize(original)

      # Verify list structure and timestamp conversions
      assert is_list(serialized["items"])
      assert length(serialized["items"]) == 2
      assert Enum.all?(serialized["items"], fn item -> is_binary(item["created_at"]) end)

      # Deserialize
      deserialized = EventStructure.deserialize(serialized)

      # Verify restoration
      assert is_list(deserialized["items"])
      assert length(deserialized["items"]) == 2
      assert Enum.all?(deserialized["items"], fn item -> %DateTime{} = item["created_at"] end)
      assert Enum.zip(timestamps, deserialized["items"])
             |> Enum.all?(fn {ts, item} -> DateTime.compare(ts, item["created_at"]) == :eq end)
    end

    test "serializes and deserializes MapSet objects" do
      # Create a MapSet
      set = MapSet.new(["value1", "value2", "value3"])
      original = %{"unique_values" => set}

      # Serialize
      serialized = EventStructure.serialize(original)

      # Verify it's converted to a map with list
      assert is_map(serialized["unique_values"])
      assert serialized["unique_values"]["__mapset__"]
      assert is_list(serialized["unique_values"]["items"])
      assert length(serialized["unique_values"]["items"]) == 3

      # Deserialize
      deserialized = EventStructure.deserialize(serialized)

      # Verify restoration
      assert %MapSet{} = deserialized["unique_values"]
      assert MapSet.equal?(deserialized["unique_values"], set)
    end

    test "serializes and deserializes complex nested structures" do
      timestamp = DateTime.utc_now()
      original = %{
        "timestamp" => timestamp,
        "nested" => %{
          "set" => MapSet.new(["a", "b"]),
          "list" => [
            %{"time" => timestamp, "value" => 1},
            %{"time" => timestamp, "value" => 2}
          ]
        },
        "items" => [
          %{"id" => 1, "created_at" => timestamp},
          %{"id" => 2, "created_at" => timestamp}
        ]
      }

      # Serialize
      serialized = EventStructure.serialize(original)

      # Verify structure
      assert is_binary(serialized["timestamp"])
      assert is_map(serialized["nested"])
      assert serialized["nested"]["set"]["__mapset__"]
      assert is_list(serialized["nested"]["list"])
      assert is_list(serialized["items"])

      # Deserialize
      deserialized = EventStructure.deserialize(serialized)

      # Verify restoration
      assert %DateTime{} = deserialized["timestamp"]
      assert DateTime.compare(timestamp, deserialized["timestamp"]) == :eq
      assert %MapSet{} = deserialized["nested"]["set"]
      assert is_list(deserialized["nested"]["list"])
      assert is_list(deserialized["items"])

      # Verify nested timestamps
      Enum.each(deserialized["nested"]["list"], fn item ->
        assert %DateTime{} = item["time"]
        assert DateTime.compare(timestamp, item["time"]) == :eq
      end)

      Enum.each(deserialized["items"], fn item ->
        assert %DateTime{} = item["created_at"]
        assert DateTime.compare(timestamp, item["created_at"]) == :eq
      end)
    end

    test "handles nil values" do
      original = %{
        "present" => "value",
        "nil_value" => nil,
        "nested" => %{
          "present" => "nested value",
          "nil_value" => nil
        }
      }

      # Serialize
      serialized = EventStructure.serialize(original)

      # Verify nil values are preserved
      assert serialized["present"] == "value"
      assert is_nil(serialized["nil_value"])
      assert serialized["nested"]["present"] == "nested value"
      assert is_nil(serialized["nested"]["nil_value"])

      # Deserialize
      deserialized = EventStructure.deserialize(serialized)

      # Verify nil values are still preserved
      assert deserialized["present"] == "value"
      assert is_nil(deserialized["nil_value"])
      assert deserialized["nested"]["present"] == "nested value"
      assert is_nil(deserialized["nested"]["nil_value"])
    end

    test "handles real event metadata serialization" do
      metadata = %{
        "server_version" => "0.1.0",
        "guild_id" => "guild_123",
        "correlation_id" => "corr_123",
        "source_id" => "source_123",
        "actor_id" => "user_123",
        "created_at" => DateTime.utc_now()
      }

      # Serialize
      serialized = EventStructure.serialize(metadata)

      # Verify metadata structure
      assert is_binary(serialized["created_at"])
      assert serialized["server_version"] == "0.1.0"
      assert serialized["guild_id"] == "guild_123"

      # Deserialize
      deserialized = EventStructure.deserialize(serialized)

      # Verify restoration
      assert %DateTime{} = deserialized["created_at"]
      assert DateTime.compare(metadata["created_at"], deserialized["created_at"]) == :eq
      assert deserialized["server_version"] == "0.1.0"
      assert deserialized["guild_id"] == "guild_123"
    end
  end
end
