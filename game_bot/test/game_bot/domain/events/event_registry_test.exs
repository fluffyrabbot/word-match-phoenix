defmodule GameBot.Domain.Events.EventRegistryTest do
  # Set async: false to prevent conflicts with ETS tables
  use ExUnit.Case, async: false

  alias GameBot.Domain.Events.EventRegistry
  alias GameBot.Domain.Events.GameEvents.ExampleEvent

  setup do
    # Cleanup any existing registry - do this first
    EventRegistry.stop()

    # Start a fresh registry for this test
    {:ok, _pid} = EventRegistry.start_link()

    # Get the current table name to use in tests
    table = EventRegistry.table_name()

    # Double check the table exists before continuing
    unless :ets.info(table) != :undefined do
      # If table doesn't exist, try once more
      EventRegistry.stop()
      EventRegistry.start_link()
      table = EventRegistry.table_name()

      # If still undefined, raise error
      unless :ets.info(table) != :undefined do
        raise "Failed to create ETS table for event registry"
      end
    end

    # Clean up after the test
    on_exit(fn ->
      # Ensure the table is cleaned up and process dictionary is cleared
      EventRegistry.stop()
    end)

    # Return the current table for test use
    {:ok, %{table: table}}
  end

  describe "EventRegistry" do
    test "starts and registers initial events" do
      # Verify initial events are registered
      assert is_list(EventRegistry.all_event_types())
      assert length(EventRegistry.all_event_types()) > 0
      assert "game_created" in EventRegistry.all_event_types()
    end

    test "registers and retrieves events" do
      # Define a test module
      defmodule TestEvent do
        defstruct [:test_field]
        def deserialize(data), do: %__MODULE__{test_field: data["test_field"]}
      end

      # Register the test event
      EventRegistry.register("test_event", TestEvent, 1)

      # Verify it can be retrieved
      assert {:ok, TestEvent, 1} = EventRegistry.module_for_type("test_event")
      assert {:ok, TestEvent} = EventRegistry.module_for_type("test_event", 1)
    end

    test "handles versioned events" do
      # Define test modules for different versions
      defmodule TestEventV1 do
        defstruct [:test_field]
        def deserialize(data), do: %__MODULE__{test_field: data["test_field"]}
      end

      defmodule TestEventV2 do
        defstruct [:test_field, :new_field]
        def deserialize(data) do
          %__MODULE__{
            test_field: data["test_field"],
            new_field: data["new_field"]
          }
        end
      end

      # Register both versions
      EventRegistry.register("versioned_event", TestEventV1, 1)
      EventRegistry.register("versioned_event", TestEventV2, 2)

      # Get specific version
      assert {:ok, TestEventV1} = EventRegistry.module_for_type("versioned_event", 1)
      assert {:ok, TestEventV2} = EventRegistry.module_for_type("versioned_event", 2)

      # Get latest version when no version specified
      assert {:ok, TestEventV2, 2} = EventRegistry.module_for_type("versioned_event")
    end

    test "deserializes events" do
      # Create event data with type
      event_data = %{
        "event_type" => "example_event",
        "event_version" => 1,
        "data" => %{
          "game_id" => "game_123",
          "guild_id" => "guild_123",
          "player_id" => "player_123",
          "action" => "test_action",
          "data" => %{"extra" => "info"},
          "timestamp" => "2023-01-01T12:00:00Z",
          "metadata" => %{"source_id" => "source_123", "correlation_id" => "corr_123"}
        }
      }

      # Deserialize
      assert {:ok, event} = EventRegistry.deserialize(event_data)

      # Verify the event
      assert %ExampleEvent{} = event
      assert event.game_id == "game_123"
      assert event.player_id == "player_123"
      assert event.action == "test_action"
    end

    test "handles errors in deserialization" do
      # Missing event type
      assert {:error, "Missing event_type in data"} = EventRegistry.deserialize(%{})

      # Unknown event type
      assert {:error, "Unknown event type: unknown_event"} =
        EventRegistry.deserialize(%{"event_type" => "unknown_event"})

      # Invalid event version
      assert {:error, "Unknown event type/version: example_event/99"} =
        EventRegistry.deserialize(%{"event_type" => "example_event", "event_version" => 99})

      # Invalid data structure
      assert {:error, _} = EventRegistry.deserialize("not a map")
    end

    test "list all registered events" do
      # Get all registered events
      all_events = EventRegistry.all_registered_events()

      # Should be a list of tuples {type, version, module}
      assert is_list(all_events)
      assert length(all_events) > 0

      # Each entry should be a tuple with type, version, module
      Enum.each(all_events, fn event ->
        assert is_tuple(event)
        assert tuple_size(event) == 3
        {type, version, module} = event
        assert is_binary(type)
        assert is_integer(version)
        assert is_atom(module)
      end)

      # Should include our example event
      assert Enum.any?(all_events, fn {type, _, _} -> type == "example_event" end)
    end

    test "cleanup works correctly", %{table: table} do
      # Verify table exists before stopping
      assert :ets.info(table) != :undefined

      # Stop the registry
      EventRegistry.stop()

      # Verify table is gone
      assert :ets.info(table) == :undefined

      # Restart registry
      EventRegistry.start_link()

      # Get new table name - it should be a new one
      new_table = EventRegistry.table_name()

      # Verify the new table exists
      assert :ets.info(new_table) != :undefined
    end

    test "handles binary data properly" do
      # Create JSON string representing an event
      json_data = """
      {
        "event_type": "example_event",
        "event_version": 1,
        "data": {
          "game_id": "game_123",
          "guild_id": "guild_123",
          "player_id": "player_123",
          "action": "test_action",
          "timestamp": "2023-01-01T12:00:00Z",
          "metadata": {"source_id": "source_123"}
        }
      }
      """

      # Deserialize from binary
      assert {:ok, event} = EventRegistry.deserialize(json_data)

      # Verify the event
      assert %ExampleEvent{} = event
      assert event.game_id == "game_123"
      assert event.player_id == "player_123"
    end
  end
end
