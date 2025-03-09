defmodule GameBot.Replay.VersionCompatibilityTest do
  use ExUnit.Case, async: true

  alias GameBot.Replay.VersionCompatibility

  describe "check_version/2" do
    test "returns :ok for supported version" do
      result = VersionCompatibility.check_version("game_started", 1)
      assert result == :ok
    end

    test "returns error for unsupported version" do
      result = VersionCompatibility.check_version("game_started", 2)
      assert {:error, {:unsupported_version, "game_started", 2, [1]}} = result
    end

    test "returns error for unsupported event type" do
      result = VersionCompatibility.check_version("unknown_event", 1)
      assert {:error, {:unsupported_event_type, "unknown_event"}} = result
    end
  end

  describe "latest_version/1" do
    test "returns latest version for supported event type" do
      result = VersionCompatibility.latest_version("game_started")
      assert result == {:ok, 1}
    end

    test "returns error for unsupported event type" do
      result = VersionCompatibility.latest_version("unknown_event")
      assert {:error, {:unsupported_event_type, "unknown_event"}} = result
    end
  end

  describe "build_version_map/1" do
    test "builds a map of event types to versions" do
      events = [
        create_test_event("game_started", 1),
        create_test_event("round_started", 1),
        create_test_event("guess_processed", 1),
        create_test_event("game_completed", 1)
      ]

      version_map = VersionCompatibility.build_version_map(events)

      assert version_map == %{
        "game_started" => 1,
        "round_started" => 1,
        "guess_processed" => 1,
        "game_completed" => 1
      }
    end

    test "handles empty event list" do
      version_map = VersionCompatibility.build_version_map([])
      assert version_map == %{}
    end

    test "uses most common version for each event type" do
      # Mix of v1 and v2 events
      events = [
        create_test_event("game_started", 1),
        create_test_event("game_started", 1),
        create_test_event("game_started", 2), # Less common version
        create_test_event("round_started", 2),
        create_test_event("round_started", 2), # More common version
        create_test_event("round_started", 1)
      ]

      version_map = VersionCompatibility.build_version_map(events)

      assert version_map == %{
        "game_started" => 1, # v1 is more common
        "round_started" => 2  # v2 is more common
      }
    end
  end

  describe "validate_event/1" do
    test "validates event with atom keys" do
      event = %{
        event_type: "game_started",
        event_version: 1
      }

      result = VersionCompatibility.validate_event(event)
      assert result == :ok
    end

    test "validates event with string keys" do
      event = %{
        "event_type" => "game_started",
        "event_version" => 1
      }

      result = VersionCompatibility.validate_event(event)
      assert result == :ok
    end

    test "returns error for invalid event format" do
      event = %{foo: "bar"}

      result = VersionCompatibility.validate_event(event)
      assert {:error, :invalid_event_format} = result
    end

    test "returns error for unsupported version" do
      event = %{
        event_type: "game_started",
        event_version: 999
      }

      result = VersionCompatibility.validate_event(event)
      assert {:error, {:unsupported_version, "game_started", 999, [1]}} = result
    end
  end

  describe "process_versioned_event/3" do
    test "processes event with correct handler" do
      event = %{
        event_type: "test_event",
        event_version: 1,
        data: "test data"
      }

      handlers = %{
        1 => fn e -> String.upcase(e.data) end
      }

      result = VersionCompatibility.process_versioned_event(event, handlers)
      assert result == {:ok, "TEST DATA"}
    end

    test "uses default handler when version not found" do
      event = %{
        event_type: "test_event",
        event_version: 2,
        data: "test data"
      }

      handlers = %{
        1 => fn _ -> "v1 handler" end
      }

      default_handler = fn e -> "default: #{e.data}" end

      result = VersionCompatibility.process_versioned_event(event, handlers, default_handler)
      assert result == {:ok, "default: test data"}
    end

    test "returns error when no handler available" do
      event = %{
        event_type: "test_event",
        event_version: 2,
        data: "test data"
      }

      handlers = %{
        1 => fn _ -> "v1 handler" end
      }

      result = VersionCompatibility.process_versioned_event(event, handlers)
      assert {:error, {:unsupported_version, "test_event", 2}} = result
    end

    test "handles exceptions in handler" do
      event = %{
        event_type: "test_event",
        event_version: 1
      }

      handlers = %{
        1 => fn _ -> raise "Test exception" end
      }

      result = VersionCompatibility.process_versioned_event(event, handlers)
      assert {:error, :processing_error} = result
    end

    test "uses version 1 as default when event_version is nil" do
      event = %{
        event_type: "test_event",
        event_version: nil,
        data: "test data"
      }

      handlers = %{
        1 => fn e -> "v1: #{e.data}" end
      }

      result = VersionCompatibility.process_versioned_event(event, handlers)
      assert result == {:ok, "v1: test data"}
    end
  end

  describe "validate_replay_compatibility/1" do
    test "validates compatible event set" do
      events = [
        create_test_event("game_started", 1),
        create_test_event("round_started", 1),
        create_test_event("game_completed", 1)
      ]

      result = VersionCompatibility.validate_replay_compatibility(events)

      assert {:ok, version_map} = result
      assert version_map == %{
        "game_started" => 1,
        "round_started" => 1,
        "game_completed" => 1
      }
    end

    test "returns errors for incompatible events" do
      events = [
        create_test_event("game_started", 1),
        create_test_event("round_started", 999), # Invalid version
        create_test_event("unknown_event", 1)    # Unknown event type
      ]

      result = VersionCompatibility.validate_replay_compatibility(events)

      assert {:error, issues} = result
      assert length(issues) == 2

      # Check that we got the expected error reasons
      assert Enum.any?(issues, fn {event, reason} ->
        match?({:unsupported_version, "round_started", 999, _}, reason)
      end)

      assert Enum.any?(issues, fn {event, reason} ->
        match?({:unsupported_event_type, "unknown_event"}, reason)
      end)
    end

    test "handles empty event list" do
      result = VersionCompatibility.validate_replay_compatibility([])
      assert {:ok, %{}} = result
    end
  end

  # Helper functions

  defp create_test_event(event_type, version) do
    %{
      event_type: event_type,
      event_version: version,
      timestamp: DateTime.utc_now(),
      game_id: "test-game-123",
      data: %{test: "data"}
    }
  end
end
