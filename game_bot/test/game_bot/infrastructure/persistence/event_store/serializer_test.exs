defmodule GameBot.Infrastructure.Persistence.EventStore.SerializerTest do
  use GameBot.Test.RepositoryCase, async: true
  use ExUnitProperties

  alias GameBot.Infrastructure.Persistence.EventStore.Serializer
  alias GameBot.Infrastructure.Persistence.Error

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

end
