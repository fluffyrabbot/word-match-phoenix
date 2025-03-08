defmodule GameBot.Infrastructure.Persistence.EventStore.Serialization.StandaloneSerializerTest do
  use ExUnit.Case, async: true

  # Tag to skip database connections for this test
  @moduletag :skip_db

  # A simple test module that doesn't require database access
  alias GameBot.Infrastructure.Error
  alias GameBot.Infrastructure.Persistence.EventStore.Serialization.JsonSerializer

  # Simple test event for serialization
  defmodule TestEvent do
    defstruct [:id, :data, :metadata]

    def event_type, do: "test_event"
    def event_version, do: 1

    # Add direct serialization methods to the event struct
    def to_map(%__MODULE__{} = event) do
      # Return the event data directly, without re-wrapping in "data"
      %{
        "id" => event.id,
        "data" => event.data.value  # Access the value directly
      }
    end

    def from_map(data) do
      %__MODULE__{
        id: data["id"],
        data: %{value: data["data"]}, # Re-wrap value in a map
        metadata: %{}
      }
    end
  end

  # Mock registry for tests
  defmodule TestRegistryMock do
    alias GameBot.Infrastructure.Persistence.EventStore.Serialization.StandaloneSerializerTest.TestEvent

    def event_type_for(_), do: "test_event"
    def event_version_for(_), do: 1
    def module_for_type("test_event"), do: {:ok, TestEvent}
    def module_for_type(_), do: {:error, "Unknown event type"}

    # Use the event's own to_map function
    def encode_event(event = %TestEvent{}), do: TestEvent.to_map(event)
    def encode_event(_), do: nil

    def decode_event(TestEvent, data), do: TestEvent.from_map(data)
    def decode_event(_, _), do: nil

    def migrate_event(_, _, _, _), do: {:error, "Migration not supported"}
  end

  setup do
    # Temporarily override the EventRegistry with our test mock
    original_registry = Application.get_env(:game_bot, :event_registry)
    Application.put_env(:game_bot, :event_registry, TestRegistryMock)

    on_exit(fn ->
      # Restore the original registry after test
      Application.put_env(:game_bot, :event_registry, original_registry)
    end)

    {:ok, metadata: %{some: "metadata"}}
  end

  describe "serialize/2" do
    test "successfully serializes a simple event", %{metadata: metadata} do
      event = %TestEvent{
        id: "test-123",
        data: %{value: "test-value"},
        metadata: metadata
      }

      assert {:ok, serialized} = JsonSerializer.serialize(event)
      # Debug output to see the actual structure
      IO.inspect(serialized, label: "Serialized Data")
      assert serialized["type"] == "test_event"
      assert serialized["version"] == 1
      assert serialized["data"]["data"] == "test-value"
      assert serialized["metadata"][:some] == metadata.some
    end

    test "returns error for invalid event" do
      assert {:error, %Error{type: :validation}} = JsonSerializer.serialize(%{not_a_struct: true})
    end
  end

  describe "deserialize/2" do
    test "returns error for invalid format" do
      assert {:error, %Error{type: :validation}} = JsonSerializer.deserialize("not a map")
    end

    test "returns error for missing fields" do
      assert {:error, %Error{type: :validation}} = JsonSerializer.deserialize(%{})
      assert {:error, %Error{type: :validation}} = JsonSerializer.deserialize(%{"type" => "test"})
    end
  end

  describe "validate/2" do
    test "validates valid data" do
      data = %{
        "type" => "test_event",
        "version" => 1,
        "data" => %{},
        "metadata" => %{}
      }

      assert :ok = JsonSerializer.validate(data)
    end

    test "returns error for invalid data" do
      assert {:error, %Error{}} = JsonSerializer.validate(nil)
      assert {:error, %Error{}} = JsonSerializer.validate(%{})
    end
  end

  describe "version/0" do
    test "returns a positive integer" do
      assert JsonSerializer.version() > 0
    end
  end
end
