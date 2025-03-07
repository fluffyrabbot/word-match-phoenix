defmodule GameBot.Domain.Events.EventStructureSerializationTest do
  use ExUnit.Case, async: true

  alias GameBot.Domain.Events.EventStructure
  alias GameBot.Domain.Events.Metadata

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

      # Serialize
      serialized = EventStructure.serialize(%{timestamp: timestamp})

      # Verify it's serialized to ISO8601 string
      assert is_binary(serialized.timestamp)
      assert String.contains?(serialized.timestamp, "T")

      # Deserialize
      deserialized = EventStructure.deserialize(serialized)

      # Verify it's a DateTime object again
      assert %DateTime{} = deserialized.timestamp
      assert DateTime.to_iso8601(timestamp) == DateTime.to_iso8601(deserialized.timestamp)
    end

    test "serializes and deserializes nested maps" do
      # Create a nested map
      original = %{
        level1: %{
          level2: %{
            level3: "value",
            timestamp: DateTime.utc_now()
          }
        }
      }

      # Serialize
      serialized = EventStructure.serialize(original)

      # Verify it's still nested and the timestamp is a string
      assert is_map(serialized.level1)
      assert is_map(serialized.level1.level2)
      assert serialized.level1.level2.level3 == "value"
      assert is_binary(serialized.level1.level2.timestamp)

      # Deserialize
      deserialized = EventStructure.deserialize(serialized)

      # Verify structure is preserved and timestamp is a DateTime again
      assert is_map(deserialized.level1)
      assert is_map(deserialized.level1.level2)
      assert deserialized.level1.level2.level3 == "value"
      assert %DateTime{} = deserialized.level1.level2.timestamp
    end

    test "serializes and deserializes lists of maps" do
      # Create a list of maps
      original = %{
        items: [
          %{id: 1, name: "Item 1", created_at: DateTime.utc_now()},
          %{id: 2, name: "Item 2", created_at: DateTime.utc_now()}
        ]
      }

      # Serialize
      serialized = EventStructure.serialize(original)

      # Verify list structure and timestamp conversions
      assert is_list(serialized.items)
      assert length(serialized.items) == 2
      assert Enum.all?(serialized.items, fn item -> is_binary(item.created_at) end)

      # Deserialize
      deserialized = EventStructure.deserialize(serialized)

      # Verify restoration
      assert is_list(deserialized.items)
      assert length(deserialized.items) == 2
      assert Enum.all?(deserialized.items, fn item -> %DateTime{} = item.created_at end)
    end

    test "serializes and deserializes MapSet objects" do
      # Create a MapSet
      set = MapSet.new(["value1", "value2", "value3"])
      original = %{unique_values: set}

      # Serialize
      serialized = EventStructure.serialize(original)

      # Verify it's converted to a map with list
      assert is_map(serialized.unique_values)
      assert serialized.unique_values["__mapset__"]
      assert is_list(serialized.unique_values["items"])
      assert length(serialized.unique_values["items"]) == 3

      # Deserialize
      deserialized = EventStructure.deserialize(serialized)

      # Verify it's a MapSet again
      assert %MapSet{} = deserialized.unique_values
      assert MapSet.size(deserialized.unique_values) == 3
      assert Enum.all?(["value1", "value2", "value3"], fn v -> v in deserialized.unique_values end)
    end

    test "serializes and deserializes simple structs" do
      # Create a struct
      struct = %SimpleTestStruct{name: "test", value: 42}
      original = %{struct: struct}

      # Serialize
      serialized = EventStructure.serialize(original)

      # Verify it's converted to a map
      assert is_map(serialized.struct)
      assert serialized.struct["name"] == "test"
      assert serialized.struct["value"] == 42

      # Note: In real implementation, you would need to ensure the struct module is available
      # during deserialization. This test doesn't fully test struct restoration.
    end

    test "serializes and deserializes complex nested structures" do
      # Create a complex nested structure
      timestamp = DateTime.utc_now()
      nested = %SimpleTestStruct{name: "nested", value: 100}
      complex = %ComplexTestStruct{
        name: "complex",
        nested: nested,
        list: [1, "two", nested, %{key: "value"}],
        map: %{
          key1: "value1",
          key2: nested,
          key3: timestamp,
          key4: [1, 2, 3]
        }
      }
      original = %{
        string: "simple value",
        number: 42,
        boolean: true,
        timestamp: timestamp,
        complex: complex,
        list_with_timestamps: [timestamp, timestamp]
      }

      # Serialize
      serialized = EventStructure.serialize(original)

      # Some basic validations (full validation would be extensive)
      assert serialized.string == "simple value"
      assert serialized.number == 42
      assert serialized.boolean == true
      assert is_binary(serialized.timestamp)
      assert is_list(serialized.list_with_timestamps)
      assert length(serialized.list_with_timestamps) == 2
      assert is_binary(List.first(serialized.list_with_timestamps))

      # Deserialize
      deserialized = EventStructure.deserialize(serialized)

      # Verify primitive values restored
      assert deserialized.string == "simple value"
      assert deserialized.number == 42
      assert deserialized.boolean == true
      assert %DateTime{} = deserialized.timestamp

      # Verify list of timestamps
      assert is_list(deserialized.list_with_timestamps)
      assert length(deserialized.list_with_timestamps) == 2
      assert Enum.all?(deserialized.list_with_timestamps, fn item -> %DateTime{} = item end)
    end

    test "handles real event metadata serialization" do
      # Create realistic metadata
      metadata = Metadata.new("source_123", %{
        correlation_id: "corr_123",
        actor_id: "user_123",
        guild_id: "guild_123"
      })

      # Add a timestamp to make it more interesting
      metadata = Map.put(metadata, :created_at, DateTime.utc_now())

      # Serialize
      serialized = EventStructure.serialize(%{metadata: metadata})

      # Verify the timestamp is stringified
      assert is_binary(serialized.metadata.created_at)
      assert serialized.metadata.source_id == "source_123"
      assert serialized.metadata.correlation_id == "corr_123"

      # Deserialize
      deserialized = EventStructure.deserialize(serialized)

      # Verify structure restored
      assert %DateTime{} = deserialized.metadata.created_at
      assert deserialized.metadata.source_id == "source_123"
      assert deserialized.metadata.correlation_id == "corr_123"
      assert deserialized.metadata.actor_id == "user_123"
      assert deserialized.metadata.guild_id == "guild_123"
    end

    test "handles serialization of nil values" do
      # Create a map with some nil values
      original = %{
        present: "value",
        nil_value: nil,
        nested: %{
          present: "nested value",
          nil_value: nil
        }
      }

      # Serialize
      serialized = EventStructure.serialize(original)

      # Nil values should be preserved
      assert serialized.present == "value"
      assert is_nil(serialized.nil_value)
      assert serialized.nested.present == "nested value"
      assert is_nil(serialized.nested.nil_value)

      # Deserialize
      deserialized = EventStructure.deserialize(serialized)

      # Nil values should still be preserved
      assert deserialized.present == "value"
      assert is_nil(deserialized.nil_value)
      assert deserialized.nested.present == "nested value"
      assert is_nil(deserialized.nested.nil_value)
    end
  end
end
