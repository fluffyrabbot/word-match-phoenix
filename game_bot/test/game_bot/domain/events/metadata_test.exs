defmodule GameBot.Domain.Events.MetadataTest do
  use ExUnit.Case, async: true
  alias GameBot.Domain.Events.Metadata

  describe "new/2" do
    test "creates valid metadata with required fields" do
      attrs = %{
        source_id: "source_123",
        correlation_id: "corr_123",
        guild_id: "guild_123"
      }

      assert {:ok, metadata} = Metadata.new(attrs)
      assert metadata.source_id == "source_123"
      assert metadata.correlation_id == "corr_123"
      assert metadata.guild_id == "guild_123"
    end

    test "accepts string keys" do
      attrs = %{
        "source_id" => "source_123",
        "correlation_id" => "corr_123",
        "guild_id" => "guild_123"
      }

      assert {:ok, metadata} = Metadata.new(attrs)
      assert metadata.source_id == "source_123"
    end

    test "returns error when source_id is missing" do
      result = Metadata.new(%{correlation_id: "corr_123"})
      assert {:error, "source_id is required in metadata"} = result
    end

    test "returns error when correlation_id is missing" do
      result = Metadata.new(%{source_id: "source_123"})
      assert {:error, "correlation_id is required in metadata"} = result
    end

    test "accepts source_id as first argument" do
      assert {:ok, metadata} = Metadata.new("source_123", correlation_id: "corr_123")
      assert metadata.source_id == "source_123"
      assert metadata.correlation_id == "corr_123"
    end
  end

  describe "from_discord_message/2" do
    test "creates metadata from Discord message" do
      msg = %Nostrum.Struct.Message{
        id: 123456,
        guild_id: 789012,
        author: %{id: 345678}
      }

      assert {:ok, metadata} = Metadata.from_discord_message(msg)
      assert metadata.source_id == "123456"
      assert metadata.guild_id == "789012"
      assert metadata.actor_id == "345678"
    end

    test "handles missing guild_id" do
      msg = %Nostrum.Struct.Message{
        id: 123456,
        author: %{id: 345678}
      }

      assert {:ok, metadata} = Metadata.from_discord_message(msg)
      assert metadata.source_id == "123456"
      assert metadata.guild_id == nil
      assert metadata.actor_id == "345678"
    end
  end

  describe "from_discord_interaction/2" do
    test "creates metadata from discord interaction" do
      # Create a mock Discord interaction
      interaction = %Nostrum.Struct.Interaction{
        id: 123456,
        guild_id: 789012,
        user: %{id: 345678}
      }

      {:ok, metadata} = Metadata.from_discord_interaction(interaction)

      assert metadata.source_id == "123456"
      assert metadata.guild_id == "789012"
      assert metadata.actor_id == "345678"
      assert is_binary(metadata.correlation_id)
    end
  end

  describe "from_parent_event/2" do
    test "preserves correlation and adds causation" do
      parent_metadata = %{
        source_id: "parent-123",
        correlation_id: "corr-456",
        guild_id: "guild-789"
      }

      {:ok, metadata} = Metadata.from_parent_event(parent_metadata)

      assert is_binary(metadata.source_id)
      assert metadata.correlation_id == "corr-456"
      assert metadata.causation_id == "corr-456"
      assert metadata.guild_id == "guild-789"
    end
  end

  describe "with_causation/2" do
    test "adds causation ID from event" do
      metadata = %{source_id: "test-123", correlation_id: "corr-456"}
      event = %{metadata: %{source_id: "cause-789"}}

      result = Metadata.with_causation(metadata, event)

      assert result.causation_id == "cause-789"
    end

    test "adds causation ID from string" do
      metadata = %{source_id: "test-123", correlation_id: "corr-456"}

      result = Metadata.with_causation(metadata, "cause-789")

      assert result.causation_id == "cause-789"
    end
  end

  describe "validate/1" do
    test "validates source_id is required" do
      invalid_metadata = %{
        correlation_id: "corr_123",
        guild_id: "guild_123"
      }

      assert {:error, "source_id is required in metadata"} = Metadata.validate(invalid_metadata)
    end

    test "validates correlation_id is required" do
      invalid_metadata = %{
        source_id: "source_123",
        guild_id: "guild_123"
      }

      assert {:error, "correlation_id is required in metadata"} = Metadata.validate(invalid_metadata)
    end

    test "validates input must be a map" do
      assert {:error, "metadata must be a map"} = Metadata.validate("not a map")
    end

    test "accepts valid metadata" do
      valid_metadata = %{
        source_id: "source_123",
        correlation_id: "corr_123",
        guild_id: "guild_123"
      }

      assert :ok = Metadata.validate(valid_metadata)
    end
  end
end
