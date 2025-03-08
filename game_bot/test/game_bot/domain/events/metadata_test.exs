defmodule GameBot.Domain.Events.MetadataTest do
  use ExUnit.Case, async: true
  alias GameBot.Domain.Events.Metadata

  describe "new/2" do
    test "creates metadata with required fields" do
      attrs = %{source_id: "test-123"}
      {:ok, metadata} = Metadata.new(attrs)

      assert metadata.source_id == "test-123"
      assert is_binary(metadata.correlation_id)
      assert String.length(metadata.correlation_id) > 0
      assert is_binary(metadata.server_version)
    end

    test "allows overriding with options" do
      attrs = %{source_id: "test-123"}
      {:ok, metadata} = Metadata.new(attrs, correlation_id: "custom-correlation")

      assert metadata.source_id == "test-123"
      assert metadata.correlation_id == "custom-correlation"
    end

    test "handles string keys in attrs" do
      attrs = %{"source_id" => "test-123"}
      {:ok, metadata} = Metadata.new(attrs)

      assert metadata.source_id == "test-123"
    end

    test "returns error when source_id is missing" do
      attrs = %{other_field: "value"}
      result = Metadata.new(attrs)

      assert {:error, :missing_field} = result
    end
  end

  describe "from_discord_message/2" do
    test "creates metadata from discord message" do
      # Create a mock Discord message
      message = %Nostrum.Struct.Message{
        id: 123456,
        guild_id: 789012,
        author: %{id: 345678}
      }

      {:ok, metadata} = Metadata.from_discord_message(message)

      assert metadata.source_id == "123456"
      assert metadata.guild_id == "789012"
      assert metadata.actor_id == "345678"
      assert is_binary(metadata.correlation_id)
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
    test "validates required fields exist" do
      valid_metadata = %{
        source_id: "test-123",
        correlation_id: "corr-456"
      }

      assert :ok = Metadata.validate(valid_metadata)
    end

    test "validates source_id is required" do
      invalid_metadata = %{
        correlation_id: "corr-456"
      }

      assert {:error, :missing_field} = Metadata.validate(invalid_metadata)
    end

    test "validates correlation_id is required" do
      invalid_metadata = %{
        source_id: "test-123"
      }

      assert {:error, :missing_field} = Metadata.validate(invalid_metadata)
    end

    test "validates input must be a map" do
      assert {:error, :invalid_type} = Metadata.validate("not a map")
    end
  end
end
