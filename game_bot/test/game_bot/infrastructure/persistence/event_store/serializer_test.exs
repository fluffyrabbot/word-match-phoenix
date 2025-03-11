defmodule GameBot.Infrastructure.Persistence.EventStore.SerializerTest do
  use GameBot.RepositoryCase, async: false
  use ExUnitProperties

  alias GameBot.Infrastructure.Persistence.EventStore.Serializer
  alias GameBot.Infrastructure.Persistence.Error
  alias GameBot.Infrastructure.Persistence.EventStore.Serialization.JsonSerializer

  describe "serialize/1" do
    test "successfully serializes valid event" do
      event = build_test_event()
      assert {:ok, serialized} = Serializer.serialize(event)
      assert is_map(serialized)
      assert serialized.event_type == event.event_type
      assert serialized.event_version == event.event_version
    end

    test "returns error for invalid event structure" do
      assert {:error, %Error{type: :validation}} = Serializer.serialize(%{invalid: "structure"})
    end

    property "serialization is reversible" do
      check all event <- event_generator() do
        assert {:ok, serialized} = Serializer.serialize(event)
        assert {:ok, deserialized} = Serializer.deserialize(serialized)
        assert event == deserialized
      end
    end
  end

  describe "deserialize/1" do
    test "successfully deserializes valid event data" do
      event = build_test_event()
      {:ok, serialized} = Serializer.serialize(event)
      assert {:ok, deserialized} = Serializer.deserialize(serialized)
      assert deserialized.event_type == event.event_type
    end

    test "returns error for missing required fields" do
      assert {:error, %Error{type: :validation}} =
        Serializer.deserialize(%{"incomplete" => "data"})
    end
  end

  describe "event_version/1" do
    test "returns correct version for known event types" do
      assert {:ok, version} = Serializer.event_version("game_started")
      assert is_integer(version)
    end

    test "returns error for unknown event type" do
      assert {:error, %Error{type: :validation}} =
        Serializer.event_version("unknown_event_type")
    end
  end

  # Generators for property testing
  defp event_generator do
    gen all(
      type <- StreamData.string(:alphanumeric, min_length: 1),
      version <- StreamData.positive_integer(),
      data <- map_generator(),
      do: %{
        event_type: type,
        event_version: version,
        data: data,
        stored_at: DateTime.utc_now()
      }
    )
  end

  defp map_generator do
    gen all(
      keys <- StreamData.list_of(StreamData.string(:alphanumeric), min_length: 1),
      values <- StreamData.list_of(StreamData.string(:alphanumeric), min_length: 1),
      pairs = Enum.zip(keys, values)
    ) do
      Map.new(pairs)
    end
  end

  # Define TestEvent for serialization testing
  defmodule TestEvent do
    defstruct [:stream_id, :event_type, :data, :metadata, :type, :version]

    # Add these functions to make the event compatible with JsonSerializer
    def event_type, do: "test_event"
    def event_version, do: 1

    # Add to_map function for serialization
    def to_map(event) do
      event.data
    end
  end

  describe "JsonSerializer" do
    test "serializes and deserializes TestEvent correctly" do
      # Create a test event with all required fields
      event = %TestEvent{
        stream_id: "test-stream-1",
        event_type: "test_event",
        data: %{value: "test-value"},
        metadata: %{guild_id: "test-guild"},
        type: "test_event",
        version: 1
      }

      # Serialize the event
      {:ok, serialized} = JsonSerializer.serialize(event)

      # Verify serialized data structure
      assert is_map(serialized)
      assert serialized["type"] == "test_event"
      assert serialized["version"] == 1
      assert serialized["data"] == %{"value" => "test-value"}
      assert serialized["metadata"] == %{"guild_id" => "test-guild"}

      # Deserialize back to an event
      {:ok, deserialized} = JsonSerializer.deserialize(serialized, TestEvent)

      # Verify the deserialized event
      assert deserialized.__struct__ == TestEvent
      assert deserialized.data == %{"value" => "test-value"}
      assert deserialized.metadata == %{"guild_id" => "test-guild"}
      assert deserialized.type == "test_event"
      assert deserialized.version == 1
    end

    test "handles missing type or version fields" do
      # Create an event missing required fields
      event = %TestEvent{
        stream_id: "test-stream-1",
        event_type: "test_event",
        data: %{value: "test-value"},
        metadata: %{guild_id: "test-guild"}
        # Missing type and version
      }

      # Serialization should fail
      assert {:error, _} = JsonSerializer.serialize(event)
    end
  end
end
