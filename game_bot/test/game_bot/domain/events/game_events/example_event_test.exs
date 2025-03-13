defmodule GameBot.Domain.Events.GameEvents.ExampleEventTest do
  use ExUnit.Case, async: true

  alias GameBot.Domain.Events.GameEvents.ExampleEvent
  alias GameBot.Domain.Events.Metadata

  describe "new/1" do
    test "creates a valid event with all required fields" do
      # Arrange
      metadata = %{source_id: "test-123", correlation_id: "corr-123"}
      attrs = %{
        game_id: "game-123",
        guild_id: "guild-123",
        mode: :two_player,
        round_number: 1,
        player_id: "player-123",
        action: "create",
        data: %{key: "value"},
        metadata: metadata
      }

      # Act
      event = ExampleEvent.new(attrs)

      # Assert
      assert event.game_id == "game-123"
      assert event.guild_id == "guild-123"
      assert event.mode == :two_player
      assert event.round_number == 1
      assert event.player_id == "player-123"
      assert event.action == "create"
      assert event.data == %{key: "value"}
      assert event.metadata == metadata
      assert event.type == "example_event"
      assert event.version == 1
      assert %DateTime{} = event.timestamp
    end
  end

  describe "new/6" do
    test "creates a valid event with individual parameters" do
      # Arrange
      metadata = %{source_id: "test-123", correlation_id: "corr-123"}

      # Act
      event = ExampleEvent.new(
        "game-123",
        "guild-123",
        "player-123",
        "update",
        %{key: "value"},
        metadata
      )

      # Assert
      assert event.game_id == "game-123"
      assert event.guild_id == "guild-123"
      assert event.mode == :two_player
      assert event.round_number == 1
      assert event.player_id == "player-123"
      assert event.action == "update"
      assert event.data == %{key: "value"}
      assert event.metadata == metadata
    end

    test "accepts metadata result tuple" do
      # Arrange
      metadata = %{source_id: "test-123", correlation_id: "corr-123"}
      metadata_result = {:ok, metadata}

      # Act
      event = ExampleEvent.new(
        "game-123",
        "guild-123",
        "player-123",
        "update",
        %{key: "value"},
        metadata_result
      )

      # Assert
      assert event.metadata == metadata
    end
  end

  describe "from_parent/4" do
    test "creates a valid event from a parent event" do
      # Arrange
      parent_metadata = %{
        source_id: "parent-123",
        correlation_id: "corr-123"
      }

      parent_event = %{
        game_id: "game-123",
        guild_id: "guild-123",
        mode: :knockout,
        round_number: 2,
        metadata: parent_metadata
      }

      # Act
      event = ExampleEvent.from_parent(
        parent_event,
        "player-123",
        "delete",
        %{key: "value"}
      )

      # Assert
      assert event.game_id == "game-123"
      assert event.guild_id == "guild-123"
      assert event.mode == :knockout
      assert event.round_number == 2
      assert event.player_id == "player-123"
      assert event.action == "delete"
      assert event.data == %{key: "value"}
      assert event.metadata.correlation_id == "corr-123"
      assert event.metadata.causation_id == "corr-123"
      assert event.metadata.actor_id == "player-123"
    end
  end

  describe "validate/1" do
    test "returns :ok for valid event" do
      # Arrange
      metadata = %{source_id: "test-123", correlation_id: "corr-123"}
      event = ExampleEvent.new(
        "game-123",
        "guild-123",
        "player-123",
        "create",
        %{key: "value"},
        metadata
      )

      # Act
      result = ExampleEvent.validate(event)

      # Assert
      assert result == :ok
    end

    test "returns error for missing player_id" do
      # Arrange
      metadata = %{source_id: "test-123", correlation_id: "corr-123"}
      attrs = %{
        game_id: "game-123",
        guild_id: "guild-123",
        mode: :two_player,
        round_number: 1,
        action: "create",
        data: %{key: "value"},
        metadata: metadata
      }
      event = struct(ExampleEvent, attrs)

      # Act
      result = ExampleEvent.validate(event)

      # Assert
      assert {:error, _} = result
    end

    test "returns error for invalid action" do
      # Arrange
      metadata = %{source_id: "test-123", correlation_id: "corr-123"}
      event = ExampleEvent.new(
        "game-123",
        "guild-123",
        "player-123",
        "invalid_action",
        %{key: "value"},
        metadata
      )

      # Act
      result = ExampleEvent.validate(event)

      # Assert
      assert {:error, message} = result
      assert message =~ "action must be one of"
    end

    test "returns error for invalid data type" do
      # Arrange
      metadata = %{source_id: "test-123", correlation_id: "corr-123"}
      attrs = %{
        game_id: "game-123",
        guild_id: "guild-123",
        mode: :two_player,
        round_number: 1,
        player_id: "player-123",
        action: "create",
        data: "not a map",
        metadata: metadata
      }
      event = struct(ExampleEvent, attrs)

      # Act
      result = ExampleEvent.validate(event)

      # Assert
      assert {:error, message} = result
      assert message == "data must be a map"
    end
  end

  describe "to_map/1 and from_map/1" do
    test "serialization roundtrip preserves data" do
      # Arrange
      metadata = %{source_id: "test-123", correlation_id: "corr-123"}
      original = ExampleEvent.new(
        "game-123",
        "guild-123",
        "player-123",
        "create",
        %{key: "value"},
        metadata
      )

      # Act
      serialized = ExampleEvent.to_map(original)
      deserialized = ExampleEvent.from_map(serialized)

      # Assert
      assert deserialized.game_id == original.game_id
      assert deserialized.guild_id == original.guild_id
      assert deserialized.mode == original.mode
      assert deserialized.round_number == original.round_number
      assert deserialized.player_id == original.player_id
      assert deserialized.action == original.action
      assert deserialized.data == original.data
      assert deserialized.metadata == original.metadata
    end
  end

  describe "apply/2" do
    test "applies event to state" do
      # Arrange
      metadata = %{source_id: "test-123", correlation_id: "corr-123"}
      event = ExampleEvent.new(
        "game-123",
        "guild-123",
        "player-123",
        "create",
        %{key: "value"},
        metadata
      )
      state = %{actions: ["previous_action"]}

      # Act
      {:ok, updated_state} = ExampleEvent.apply(event, state)

      # Assert
      assert updated_state.actions == ["create", "previous_action"]
      assert updated_state.last_player_id == "player-123"
      assert updated_state.last_action_time == event.timestamp
    end

    test "returns error for invalid event" do
      # Arrange
      metadata = %{source_id: "test-123", correlation_id: "corr-123"}
      attrs = %{
        game_id: "game-123",
        guild_id: "guild-123",
        mode: :two_player,
        round_number: 1,
        player_id: "player-123",
        action: "invalid_action",
        data: %{key: "value"},
        metadata: metadata
      }
      event = struct(ExampleEvent, attrs)
      state = %{actions: ["previous_action"]}

      # Act
      result = ExampleEvent.apply(event, state)

      # Assert
      assert {:error, _} = result
    end
  end
end
