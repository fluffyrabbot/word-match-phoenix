defmodule GameBot.Domain.Events.TeamEventsTest do
  use ExUnit.Case, async: true

  alias GameBot.Domain.Events.TeamEvents
  alias GameBot.Domain.Events.TeamEvents.{TeamCreated, TeamUpdated, TeamMemberAdded, TeamMemberRemoved}

  describe "TeamCreated" do
    test "new/5 creates a valid event" do
      team_id = "team_123"
      name = "Test Team"
      player_ids = ["player_1", "player_2"]
      guild_id = "guild_123"
      metadata = %{source: "test"}

      {:ok, event} = TeamCreated.new(team_id, name, player_ids, guild_id, metadata)

      assert event.team_id == team_id
      assert event.name == name
      assert event.player_ids == player_ids
      assert event.guild_id == guild_id
      assert event.metadata.source == "test"
      assert event.metadata.guild_id == guild_id
      assert is_binary(event.metadata.source_id)
      assert is_binary(event.metadata.correlation_id)
      assert %DateTime{} = event.created_at
      assert %DateTime{} = event.timestamp
      assert event.type == "team_created"
      assert event.version == 1
    end

    test "new/5 returns error for invalid team" do
      # Missing player
      {:error, _} = TeamCreated.new("team_123", "Test Team", ["player_1"], "guild_123")

      # Too many players
      {:error, _} = TeamCreated.new("team_123", "Test Team", ["player_1", "player_2", "player_3"], "guild_123")

      # Empty team_id
      {:error, _} = TeamCreated.new("", "Test Team", ["player_1", "player_2"], "guild_123")

      # Empty name
      {:error, _} = TeamCreated.new("team_123", "", ["player_1", "player_2"], "guild_123")
    end

    test "validate/1 validates the event" do
      valid_event = %TeamCreated{
        team_id: "team_123",
        name: "Test Team",
        player_ids: ["player_1", "player_2"],
        guild_id: "guild_123",
        created_at: DateTime.utc_now(),
        timestamp: DateTime.utc_now(),
        metadata: %{guild_id: "guild_123", source_id: "test_source", correlation_id: "test_correlation"}
      }

      assert :ok = TeamCreated.validate(valid_event)

      # Invalid event (missing player_ids)
      invalid_event = %{valid_event | player_ids: ["player_1"]}
      assert {:error, _} = TeamCreated.validate(invalid_event)
    end

    test "to_map/1 converts event to map" do
      event = %TeamCreated{
        team_id: "team_123",
        name: "Test Team",
        player_ids: ["player_1", "player_2"],
        guild_id: "guild_123",
        game_id: "game_123",
        created_at: ~U[2023-01-01 12:00:00Z],
        metadata: %{guild_id: "guild_123"}
      }

      map = TeamCreated.to_map(event)

      assert map["team_id"] == "team_123"
      assert map["name"] == "Test Team"
      assert map["player_ids"] == ["player_1", "player_2"]
      assert map["guild_id"] == "guild_123"
      assert map["game_id"] == "game_123"
      assert map["created_at"] == "2023-01-01T12:00:00Z"
      assert map["metadata"] == %{guild_id: "guild_123"}
    end

    test "from_map/1 creates event from map" do
      map = %{
        "team_id" => "team_123",
        "name" => "Test Team",
        "player_ids" => ["player_1", "player_2"],
        "guild_id" => "guild_123",
        "game_id" => "game_123",
        "created_at" => "2023-01-01T12:00:00Z",
        "metadata" => %{"guild_id" => "guild_123"}
      }

      event = TeamCreated.from_map(map)

      assert event.team_id == "team_123"
      assert event.name == "Test Team"
      assert event.player_ids == ["player_1", "player_2"]
      assert event.guild_id == "guild_123"
      assert event.game_id == "game_123"
      assert event.created_at == ~U[2023-01-01 12:00:00Z]
      assert event.timestamp == ~U[2023-01-01 12:00:00Z]
      assert event.metadata == %{"guild_id" => "guild_123"}
      assert event.type == "team_created"
      assert event.version == 1
    end
  end

  describe "TeamUpdated" do
    test "new/4 creates a valid event" do
      team_id = "team_123"
      name = "Updated Team"
      guild_id = "guild_123"
      metadata = %{source: "test"}

      {:ok, event} = TeamUpdated.new(team_id, name, guild_id, metadata)

      assert event.team_id == team_id
      assert event.name == name
      assert event.guild_id == guild_id
      assert event.metadata.source == "test"
      assert event.metadata.guild_id == guild_id
      assert is_binary(event.metadata.source_id)
      assert is_binary(event.metadata.correlation_id)
      assert %DateTime{} = event.team_updated_at
      assert %DateTime{} = event.timestamp
      assert event.type == "team_updated"
      assert event.version == 1
    end

    test "new/4 returns error for invalid team" do
      # Empty team_id
      {:error, _} = TeamUpdated.new("", "Updated Team", "guild_123")

      # Empty name
      {:error, _} = TeamUpdated.new("team_123", "", "guild_123")
    end

    test "validate/1 validates the event" do
      valid_event = %TeamUpdated{
        team_id: "team_123",
        name: "Updated Team",
        guild_id: "guild_123",
        team_updated_at: DateTime.utc_now(),
        timestamp: DateTime.utc_now(),
        metadata: %{guild_id: "guild_123", source_id: "test_source", correlation_id: "test_correlation"}
      }

      assert :ok = TeamUpdated.validate(valid_event)

      # Invalid event (missing name)
      invalid_event = %{valid_event | name: ""}
      assert {:error, _} = TeamUpdated.validate(invalid_event)
    end

    test "to_map/1 converts event to map" do
      event = %TeamUpdated{
        team_id: "team_123",
        name: "Updated Team",
        guild_id: "guild_123",
        game_id: "game_123",
        team_updated_at: ~U[2023-01-01 12:00:00Z],
        metadata: %{guild_id: "guild_123"}
      }

      map = TeamUpdated.to_map(event)

      assert map["team_id"] == "team_123"
      assert map["name"] == "Updated Team"
      assert map["guild_id"] == "guild_123"
      assert map["game_id"] == "game_123"
      assert map["updated_at"] == "2023-01-01T12:00:00Z"
      assert map["metadata"] == %{guild_id: "guild_123"}
    end

    test "from_map/1 creates event from map" do
      map = %{
        "team_id" => "team_123",
        "name" => "Updated Team",
        "guild_id" => "guild_123",
        "game_id" => "game_123",
        "updated_at" => "2023-01-01T12:00:00Z",
        "metadata" => %{"guild_id" => "guild_123"}
      }

      event = TeamUpdated.from_map(map)

      assert event.team_id == "team_123"
      assert event.name == "Updated Team"
      assert event.guild_id == "guild_123"
      assert event.game_id == "game_123"
      assert event.team_updated_at == ~U[2023-01-01 12:00:00Z]
      assert event.timestamp == ~U[2023-01-01 12:00:00Z]
      assert event.metadata == %{"guild_id" => "guild_123"}
      assert event.type == "team_updated"
      assert event.version == 1
    end
  end

  describe "TeamMemberAdded" do
    test "new/5 creates a valid event" do
      team_id = "team_123"
      player_id = "player_3"
      added_by = "admin_1"
      guild_id = "guild_123"
      metadata = %{source: "test"}

      {:ok, event} = TeamMemberAdded.new(team_id, player_id, added_by, guild_id, metadata)

      assert event.team_id == team_id
      assert event.player_id == player_id
      assert event.added_by == added_by
      assert event.guild_id == guild_id
      assert event.metadata.source == "test"
      assert event.metadata.guild_id == guild_id
      assert is_binary(event.metadata.source_id)
      assert is_binary(event.metadata.correlation_id)
      assert %DateTime{} = event.added_at
      assert %DateTime{} = event.timestamp
      assert event.type == "team_member_added"
      assert event.version == 1
    end

    test "new/5 returns error for invalid data" do
      # Empty team_id
      {:error, _} = TeamMemberAdded.new("", "player_3", "admin_1", "guild_123")

      # Empty player_id
      {:error, _} = TeamMemberAdded.new("team_123", "", "admin_1", "guild_123")

      # Empty added_by
      {:error, _} = TeamMemberAdded.new("team_123", "player_3", "", "guild_123")
    end

    test "validate/1 validates the event" do
      valid_event = %TeamMemberAdded{
        team_id: "team_123",
        player_id: "player_3",
        added_by: "admin_1",
        guild_id: "guild_123",
        added_at: DateTime.utc_now(),
        timestamp: DateTime.utc_now(),
        metadata: %{guild_id: "guild_123", source_id: "test_source", correlation_id: "test_correlation"}
      }

      assert :ok = TeamMemberAdded.validate(valid_event)

      # Invalid event (missing player_id)
      invalid_event = %{valid_event | player_id: ""}
      assert {:error, _} = TeamMemberAdded.validate(invalid_event)
    end
  end

  describe "TeamMemberRemoved" do
    test "new/6 creates a valid event" do
      team_id = "team_123"
      player_id = "player_2"
      removed_by = "admin_1"
      reason = "Left the team"
      guild_id = "guild_123"
      metadata = %{source: "test"}

      {:ok, event} = TeamMemberRemoved.new(team_id, player_id, removed_by, reason, guild_id, metadata)

      assert event.team_id == team_id
      assert event.player_id == player_id
      assert event.removed_by == removed_by
      assert event.reason == reason
      assert event.guild_id == guild_id
      assert event.metadata.source == "test"
      assert event.metadata.guild_id == guild_id
      assert is_binary(event.metadata.source_id)
      assert is_binary(event.metadata.correlation_id)
      assert %DateTime{} = event.removed_at
      assert %DateTime{} = event.timestamp
      assert event.type == "team_member_removed"
      assert event.version == 1
    end

    test "new/6 works with nil reason" do
      {:ok, event} = TeamMemberRemoved.new("team_123", "player_2", "admin_1", nil, "guild_123")
      assert is_nil(event.reason)
    end

    test "new/6 returns error for invalid data" do
      # Empty team_id
      {:error, _} = TeamMemberRemoved.new("", "player_2", "admin_1", "Left", "guild_123")

      # Empty player_id
      {:error, _} = TeamMemberRemoved.new("team_123", "", "admin_1", "Left", "guild_123")

      # Empty removed_by
      {:error, _} = TeamMemberRemoved.new("team_123", "player_2", "", "Left", "guild_123")
    end

    test "validate/1 validates the event" do
      valid_event = %TeamMemberRemoved{
        team_id: "team_123",
        player_id: "player_2",
        removed_by: "admin_1",
        reason: "Left the team",
        guild_id: "guild_123",
        removed_at: DateTime.utc_now(),
        timestamp: DateTime.utc_now(),
        metadata: %{guild_id: "guild_123", source_id: "test_source", correlation_id: "test_correlation"}
      }

      assert :ok = TeamMemberRemoved.validate(valid_event)

      # Invalid event (missing player_id)
      invalid_event = %{valid_event | player_id: ""}
      assert {:error, _} = TeamMemberRemoved.validate(invalid_event)
    end
  end
end
