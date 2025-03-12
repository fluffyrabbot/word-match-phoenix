defmodule GameBot.Infrastructure.Persistence.EventStore.SerializerTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  alias GameBot.Infrastructure.Persistence.Error
  alias GameBot.Infrastructure.Persistence.EventStore.JsonSerializer
  alias GameBot.Infrastructure.Persistence.EventStore.Serializer

  # Define TestEvent struct for testing
  defmodule TestEvent do
    defstruct [:event_type, :event_version, :data, :metadata, :stream_id, :type, :version]

    def event_type, do: "test_event"
    def event_version, do: 1

    def to_map(event) do
      %{
        "type" => event.type || event.event_type,
        "version" => event.version || event.event_version,
        "data" => event.data,
        "metadata" => event.metadata,
        "stream_id" => event.stream_id
      }
    end
  end

  setup do
    # Configure the event store adapter
    Application.put_env(:game_bot, :event_store_adapter, GameBot.Test.EventStoreCore)

    # Start the test event store if not already started
    case GameBot.Test.EventStoreCore.start_link() do
      {:ok, pid} ->
        on_exit(fn ->
          try do
            GameBot.Test.EventStoreCore.reset()
            Process.exit(pid, :normal)
          catch
            _, _ -> :ok
          end
        end)
        {:ok, %{event_store_pid: pid}}
      {:error, {:already_started, pid}} ->
        # Reset the store and continue
        GameBot.Test.EventStoreCore.reset()
        {:ok, %{event_store_pid: pid}}
    end
  end

  describe "serialize/1" do
    test "successfully serializes valid event" do
      event = %TestEvent{
        event_type: "test_event",
        event_version: 1,
        data: %{value: "test"},
        metadata: %{},
        stream_id: "test-stream",
        type: "test_event",
        version: 1
      }

      assert {:ok, serialized} = JsonSerializer.serialize(event)
      assert is_map(serialized)
      assert serialized["type"] == "test_event"
      assert serialized["version"] == 1
      assert serialized["data"] == %{"value" => "test"}
    end

    test "returns error for invalid event structure" do
      assert {:error, %Error{type: :validation}} = JsonSerializer.serialize(%{invalid: "structure"})
    end
  end

  describe "deserialize/1" do
    test "successfully deserializes valid event data" do
      event = %TestEvent{
        event_type: "test_event",
        event_version: 1,
        data: %{value: "test"},
        metadata: %{},
        stream_id: "test-stream",
        type: "test_event",
        version: 1
      }

      {:ok, serialized} = JsonSerializer.serialize(event)
      assert {:ok, deserialized} = JsonSerializer.deserialize(serialized, TestEvent)
      assert deserialized.type == "test_event"
      assert deserialized.data == %{"value" => "test"}
    end

    test "returns error for missing required fields" do
      assert {:error, %Error{type: :validation}} =
        JsonSerializer.deserialize(%{"incomplete" => "data"}, TestEvent)
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
      do: %TestEvent{
        event_type: type,
        event_version: version,
        data: data,
        metadata: %{},
        stream_id: "test-stream",
        type: type,
        version: version
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
