defmodule GameBot.Replay.EventVerifierTest do
  use ExUnit.Case, async: true

  alias GameBot.Replay.EventVerifier

  describe "verify_event_sequence/1" do
    test "returns error for empty sequence" do
      result = EventVerifier.verify_event_sequence([])
      assert result == {:error, :empty_sequence}
    end

    test "returns ok for single event" do
      events = [create_test_event("game-1", 1)]
      result = EventVerifier.verify_event_sequence(events)
      assert result == :ok
    end

    test "returns ok for sequential events" do
      events = [
        create_test_event("game-1", 1),
        create_test_event("game-1", 2),
        create_test_event("game-1", 3)
      ]

      result = EventVerifier.verify_event_sequence(events)
      assert result == :ok
    end

    test "returns ok for unordered but sequential events" do
      events = [
        create_test_event("game-1", 3),
        create_test_event("game-1", 1),
        create_test_event("game-1", 2)
      ]

      result = EventVerifier.verify_event_sequence(events)
      assert result == :ok
    end

    test "detects version gaps" do
      events = [
        create_test_event("game-1", 1),
        create_test_event("game-1", 2),
        create_test_event("game-1", 5) # Gap: 3, 4 missing
      ]

      result = EventVerifier.verify_event_sequence(events)
      assert match?({:error, {:version_gap, 2, 5}}, result)
    end

    test "detects duplicate versions" do
      events = [
        create_test_event("game-1", 1),
        create_test_event("game-1", 2),
        create_test_event("game-1", 2) # Duplicate
      ]

      result = EventVerifier.verify_event_sequence(events)
      assert match?({:error, {:version_order_issue, _, _}}, result)
    end
  end

  describe "validate_game_completion/1" do
    test "returns ok for completed game" do
      events = [
        create_test_event("game-1", 1, "game_started"),
        create_test_event("game-1", 2, "round_started"),
        create_test_event("game-1", 3, "game_completed")
      ]

      result = EventVerifier.validate_game_completion(events)
      assert match?({:ok, %{event_type: "game_completed"}}, result)
    end

    test "returns error for incomplete game" do
      events = [
        create_test_event("game-1", 1, "game_started"),
        create_test_event("game-1", 2, "round_started")
      ]

      result = EventVerifier.validate_game_completion(events)
      assert result == {:error, :game_not_completed}
    end
  end

  describe "check_required_events/2" do
    test "returns ok when all required events present" do
      events = [
        create_test_event("game-1", 1, "game_started"),
        create_test_event("game-1", 2, "round_started"),
        create_test_event("game-1", 3, "game_completed")
      ]

      required = ["game_started", "game_completed"]
      result = EventVerifier.check_required_events(events, required)
      assert result == :ok
    end

    test "returns error when some required events missing" do
      events = [
        create_test_event("game-1", 1, "game_started"),
        create_test_event("game-1", 2, "round_started")
      ]

      required = ["game_started", "game_completed"]
      result = EventVerifier.check_required_events(events, required)
      assert match?({:error, {:missing_events, missing}}, result)
      assert "game_completed" in (result |> elem(1) |> elem(1))
    end

    test "returns ok for empty required list" do
      events = [
        create_test_event("game-1", 1, "game_started")
      ]

      result = EventVerifier.check_required_events(events, [])
      assert result == :ok
    end
  end

  describe "verify_game_stream/2" do
    test "returns ok for valid game stream" do
      events = [
        create_test_event("game-1", 1, "game_started"),
        create_test_event("game-1", 2, "round_started"),
        create_test_event("game-1", 3, "game_completed")
      ]

      result = EventVerifier.verify_game_stream(events)
      assert result == :ok
    end

    test "returns error when sequence verification fails" do
      events = [
        create_test_event("game-1", 1, "game_started"),
        create_test_event("game-1", 3, "game_completed") # Gap at version 2
      ]

      result = EventVerifier.verify_game_stream(events)
      assert match?({:error, {:version_gap, 1, 3}}, result)
    end

    test "returns error when required events missing" do
      events = [
        create_test_event("game-1", 1, "round_started"),
        create_test_event("game-1", 2, "game_completed")
      ]

      # By default, game_started is required
      result = EventVerifier.verify_game_stream(events)
      assert match?({:error, {:missing_events, _}}, result)
    end

    test "returns error when completion check fails" do
      events = [
        create_test_event("game-1", 1, "game_started"),
        create_test_event("game-1", 2, "round_started")
      ]

      result = EventVerifier.verify_game_stream(events)
      assert result == {:error, :game_not_completed}
    end

    test "skips completion check when disabled" do
      events = [
        create_test_event("game-1", 1, "game_started"),
        create_test_event("game-1", 2, "round_started")
        # No game_completed event
      ]

      result = EventVerifier.verify_game_stream(events, check_completion: false)
      assert result == :ok
    end

    test "uses custom required events" do
      events = [
        create_test_event("game-1", 1, "game_started"),
        create_test_event("game-1", 2, "game_completed")
        # No round_started event
      ]

      result = EventVerifier.verify_game_stream(events, required_events: ["game_started", "round_started"])
      assert match?({:error, {:missing_events, missing}}, result)
      assert "round_started" in (result |> elem(1) |> elem(1))
    end
  end

  # Helper function to create test events
  defp create_test_event(game_id, version, event_type \\ "test_event") do
    %{
      game_id: game_id,
      event_type: event_type,
      event_version: 1,
      timestamp: DateTime.utc_now(),
      version: version,
      data: %{test: "data"}
    }
  end
end
