defmodule GameBot.Domain.Events.EventStructureTest do
  use ExUnit.Case, async: true

  alias GameBot.Domain.Events.{EventStructure, Metadata, GameEvents}
  alias Nostrum.Struct.Message

  # Helper to create a test message
  defp create_test_message do
    %Message{
      id: "1234",
      channel_id: "channel_id",
      guild_id: "guild_id",
      author: %{id: "1234"}
    }
  end

  describe "base_fields/0" do
    test "returns the expected base fields" do
      assert Enum.sort(EventStructure.base_fields()) ==
             Enum.sort([:game_id, :guild_id, :mode, :round_number, :timestamp, :metadata])
    end
  end

  describe "validate/1" do
    test "returns :ok for a valid event" do
      message = create_test_message()
      metadata = Metadata.from_discord_message(message)
      timestamp = DateTime.utc_now()

      valid_event = %{
        game_id: "game-123",
        guild_id: "guild-123",
        mode: :knockout,
        round_number: 1,
        timestamp: timestamp,
        metadata: metadata
      }

      assert :ok = EventStructure.validate(valid_event)
    end

    test "returns error for missing game_id" do
      message = create_test_message()
      metadata = Metadata.from_discord_message(message)
      timestamp = DateTime.utc_now()

      invalid_event = %{
        guild_id: "guild-123",
        mode: :knockout,
        round_number: 1,
        timestamp: timestamp,
        metadata: metadata
      }

      assert {:error, "game_id is required"} = EventStructure.validate(invalid_event)
    end

    test "returns error for missing guild_id" do
      message = create_test_message()
      metadata = Metadata.from_discord_message(message)
      timestamp = DateTime.utc_now()

      invalid_event = %{
        game_id: "game-123",
        mode: :knockout,
        round_number: 1,
        timestamp: timestamp,
        metadata: metadata
      }

      assert {:error, "guild_id is required"} = EventStructure.validate(invalid_event)
    end

    test "returns error for missing mode" do
      message = create_test_message()
      metadata = Metadata.from_discord_message(message)
      timestamp = DateTime.utc_now()

      invalid_event = %{
        game_id: "game-123",
        guild_id: "guild-123",
        round_number: 1,
        timestamp: timestamp,
        metadata: metadata
      }

      assert {:error, "mode is required"} = EventStructure.validate(invalid_event)
    end

    test "returns error for missing round_number" do
      message = create_test_message()
      metadata = Metadata.from_discord_message(message)
      timestamp = DateTime.utc_now()

      invalid_event = %{
        game_id: "game-123",
        guild_id: "guild-123",
        mode: :knockout,
        timestamp: timestamp,
        metadata: metadata
      }

      assert {:error, "round_number is required"} = EventStructure.validate(invalid_event)
    end

    test "returns error for missing timestamp" do
      message = create_test_message()
      metadata = Metadata.from_discord_message(message)

      invalid_event = %{
        game_id: "game-123",
        guild_id: "guild-123",
        mode: :knockout,
        round_number: 1,
        metadata: metadata
      }

      assert {:error, "timestamp is required"} = EventStructure.validate(invalid_event)
    end

    test "returns error for missing metadata" do
      timestamp = DateTime.utc_now()

      invalid_event = %{
        game_id: "game-123",
        guild_id: "guild-123",
        mode: :knockout,
        round_number: 1,
        timestamp: timestamp
      }

      assert {:error, "metadata is required"} = EventStructure.validate(invalid_event)
    end

    test "validates an actual game event" do
      message = create_test_message()
      metadata = Metadata.from_discord_message(message)

      event = %GameEvents.GameStarted{
        game_id: "game-123",
        guild_id: "guild-123",
        mode: :knockout,
        round_number: 1,
        teams: %{
          "team-1" => ["player-1", "player-2"],
          "team-2" => ["player-3", "player-4"]
        },
        team_ids: ["team-1", "team-2"],
        player_ids: ["player-1", "player-2", "player-3", "player-4"],
        roles: %{},
        config: %{},
        started_at: DateTime.utc_now(),
        timestamp: DateTime.utc_now(),
        metadata: metadata
      }

      assert :ok = EventStructure.validate(event)
    end
  end

  describe "parse_timestamp/1" do
    test "parses a valid ISO8601 timestamp" do
      timestamp_str = "2023-01-01T12:00:00Z"
      {:ok, expected, _} = DateTime.from_iso8601(timestamp_str)

      assert ^expected = EventStructure.parse_timestamp(timestamp_str)
    end

    test "raises an error for invalid timestamp format" do
      assert_raise RuntimeError, fn ->
        EventStructure.parse_timestamp("invalid-timestamp")
      end
    end
  end

  describe "create_event_map/3" do
    test "creates a valid event map with all base fields" do
      message = create_test_message()
      metadata = Metadata.from_discord_message(message)

      event_map = EventStructure.create_event_map("game-123", "guild-123", :knockout, metadata)

      assert event_map.game_id == "game-123"
      assert event_map.guild_id == "guild-123"
      assert event_map.mode == :knockout
      assert event_map.round_number == 1
      assert %DateTime{} = event_map.timestamp
      assert event_map.metadata == metadata
    end

    test "creates a valid event map with custom round number" do
      message = create_test_message()
      metadata = Metadata.from_discord_message(message)

      event_map = EventStructure.create_event_map("game-123", "guild-123", :knockout, metadata, round_number: 3)

      assert event_map.game_id == "game-123"
      assert event_map.guild_id == "guild-123"
      assert event_map.mode == :knockout
      assert event_map.round_number == 3
      assert %DateTime{} = event_map.timestamp
      assert event_map.metadata == metadata
    end

    test "creates a valid event map with custom timestamp" do
      message = create_test_message()
      metadata = Metadata.from_discord_message(message)
      custom_timestamp = DateTime.from_naive!(~N[2023-01-01 00:00:00], "Etc/UTC")

      event_map = EventStructure.create_event_map("game-123", "guild-123", :knockout, metadata, timestamp: custom_timestamp)

      assert event_map.game_id == "game-123"
      assert event_map.guild_id == "guild-123"
      assert event_map.mode == :knockout
      assert event_map.round_number == 1
      assert event_map.timestamp == custom_timestamp
      assert event_map.metadata == metadata
    end
  end
end
