defmodule GameBot.Domain.Events.GameEvents.ExampleEventTest do
  use ExUnit.Case, async: true

  alias GameBot.Domain.Events.GameEvents.ExampleEvent
  alias GameBot.Domain.Events.Metadata

  describe "ExampleEvent" do
    test "creates a valid event" do
      {:ok, metadata} = Metadata.new("source_123", %{
        correlation_id: "corr_123",
        actor_id: "player_123"
      })

      event = ExampleEvent.new("game_123", "guild_123", "player_123", "do_something", %{extra: "data"}, metadata)

      assert :ok = ExampleEvent.validate(event)
      assert event.game_id == "game_123"
      assert event.player_id == "player_123"
      assert event.action == "do_something"
      assert event.data == %{extra: "data"}
      assert %DateTime{} = event.timestamp
      assert event.metadata == metadata
    end

    test "validation fails with missing fields" do
      {:ok, metadata} = Metadata.new("source_123", %{correlation_id: "corr_123"})

      # Missing player_id
      event = %ExampleEvent{
        game_id: "game_123",
        guild_id: "guild_123",
        mode: :two_player,
        round_number: 1,
        action: "do_something",
        data: %{},
        timestamp: DateTime.utc_now(),
        metadata: metadata
      }

      assert {:error, "player_id is required"} = ExampleEvent.validate(event)

      # Missing action
      event = %ExampleEvent{
        game_id: "game_123",
        guild_id: "guild_123",
        mode: :two_player,
        round_number: 1,
        player_id: "player_123",
        data: %{},
        timestamp: DateTime.utc_now(),
        metadata: metadata
      }

      assert {:error, "action is required"} = ExampleEvent.validate(event)

      # Missing data
      event = %ExampleEvent{
        game_id: "game_123",
        guild_id: "guild_123",
        mode: :two_player,
        round_number: 1,
        player_id: "player_123",
        action: "do_something",
        timestamp: DateTime.utc_now(),
        metadata: metadata
      }

      assert {:error, "data is required"} = ExampleEvent.validate(event)
    end

    test "serializes and deserializes" do
      {:ok, metadata} = Metadata.new("source_123", %{
        correlation_id: "corr_123",
        actor_id: "player_123"
      })

      event = ExampleEvent.new("game_123", "guild_123", "player_123", "do_something", %{extra: "data"}, metadata)

      serialized = ExampleEvent.serialize(event)
      assert is_binary(serialized["timestamp"])
      assert serialized["game_id"] == "game_123"
      assert serialized["player_id"] == "player_123"

      deserialized = ExampleEvent.deserialize(serialized)
      assert deserialized.game_id == event.game_id
      assert deserialized.player_id == event.player_id
      assert deserialized.action == event.action
      assert deserialized.data == event.data
      assert %DateTime{} = deserialized.timestamp
      assert deserialized.metadata == event.metadata
    end

    test "creates event from parent" do
      {:ok, parent_metadata} = Metadata.new("source_123", %{
        correlation_id: "corr_123",
        actor_id: "parent_actor"
      })

      parent_event = ExampleEvent.new(
        "game_123",
        "guild_123",
        "parent_actor",
        "parent_action",
        %{parent: true},
        parent_metadata
      )

      child_event = ExampleEvent.from_parent(
        parent_event,
        "child_actor",
        "child_action",
        %{child: true}
      )

      assert child_event.game_id == parent_event.game_id
      assert child_event.guild_id == parent_event.guild_id
      assert child_event.player_id == "child_actor"
      assert child_event.action == "child_action"
      assert child_event.data == %{child: true}

      # Check for causation tracking
      assert child_event.metadata.correlation_id == parent_metadata.correlation_id
      assert child_event.metadata.causation_id != nil
      assert child_event.metadata.actor_id == "child_actor"
    end

    test "applies event to state" do
      {:ok, metadata} = Metadata.new("source_123", %{
        correlation_id: "corr_123",
        actor_id: "player_123"
      })

      event = ExampleEvent.new("game_123", "guild_123", "player_123", "do_something", %{extra: "data"}, metadata)

      initial_state = %{}
      {:ok, updated_state} = ExampleEvent.apply(event, initial_state)

      assert updated_state.actions == ["do_something"]
      assert updated_state.last_player_id == "player_123"
      assert updated_state.last_action_time == event.timestamp
    end
  end
end
