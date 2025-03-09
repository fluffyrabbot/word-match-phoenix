defmodule GameBot.Domain.Events.EventValidatorTest do
  use ExUnit.Case, async: true

  alias GameBot.Domain.Events.{EventValidator, EventStructure, Metadata}
  alias GameBot.Domain.Events.TestEvents.{ValidatorTestEvent, ValidatorOptionalFieldsEvent}
  alias GameBot.Domain.Events.TestEvents.Validator, as: TestValidator

  # Helper to create a test message
  defp create_test_message do
    %{
      id: "1234",
      channel_id: "channel_id",
      guild_id: "guild_id",
      author: %{id: "1234"}
    }
  end

  # Helper to create a valid test event
  defp create_valid_event(opts \\ []) do
    message = create_test_message()
    {:ok, metadata} = Metadata.from_discord_message(message)
    timestamp = Keyword.get(opts, :timestamp, DateTime.utc_now())

    %ValidatorTestEvent{
      game_id: Keyword.get(opts, :game_id, "game-123"),
      guild_id: Keyword.get(opts, :guild_id, "guild-123"),
      mode: Keyword.get(opts, :mode, :knockout),
      timestamp: timestamp,
      metadata: metadata,
      count: Keyword.get(opts, :count, 1),
      score: Keyword.get(opts, :score, 100)
    }
  end

  describe "validate/1" do
    test "returns :ok for a valid event" do
      event = create_valid_event()
      assert :ok = TestValidator.validate(event)
    end

    test "returns error for missing base fields" do
      event = create_valid_event() |> Map.delete(:game_id)
      assert {:error, "game_id is required"} = TestValidator.validate(event)

      event = create_valid_event() |> Map.delete(:guild_id)
      assert {:error, "guild_id is required"} = TestValidator.validate(event)

      event = create_valid_event() |> Map.delete(:mode)
      assert {:error, "mode is required"} = TestValidator.validate(event)

      event = create_valid_event() |> Map.delete(:timestamp)
      assert {:error, "timestamp is required"} = TestValidator.validate(event)

      event = create_valid_event() |> Map.delete(:metadata)
      assert {:error, "metadata is required"} = TestValidator.validate(event)
    end

    test "returns error for invalid base field values" do
      event = create_valid_event(game_id: "")
      assert {:error, "game_id and guild_id must be non-empty strings"} = TestValidator.validate(event)

      event = create_valid_event(guild_id: "")
      assert {:error, "game_id and guild_id must be non-empty strings"} = TestValidator.validate(event)

      event = create_valid_event() |> Map.put(:mode, "not_an_atom")
      assert {:error, "mode must be an atom"} = TestValidator.validate(event)

      future_time = DateTime.add(DateTime.utc_now(), 3600, :second)
      event = create_valid_event(timestamp: future_time)
      assert {:error, "timestamp cannot be in the future"} = TestValidator.validate(event)
    end

    test "returns error for missing event-specific fields" do
      event = create_valid_event() |> Map.delete(:count)
      assert {:error, "count is required"} = TestValidator.validate(event)

      event = create_valid_event() |> Map.delete(:score)
      assert {:error, "score is required"} = TestValidator.validate(event)
    end

    test "returns error for invalid event-specific field values" do
      event = create_valid_event(count: 0)
      assert {:error, "count must be a positive integer"} = TestValidator.validate(event)

      event = create_valid_event(count: -1)
      assert {:error, "count must be a positive integer"} = TestValidator.validate(event)

      event = create_valid_event(count: "not_a_number")
      assert {:error, "count must be a positive integer"} = TestValidator.validate(event)

      event = create_valid_event(score: "not_a_number")
      assert {:error, "score must be an integer"} = TestValidator.validate(event)
    end

    test "validates metadata content" do
      # Test with empty map but missing required source_id
      event = create_valid_event()
      |> Map.put(:metadata, %{correlation_id: "corr-123"})
      assert {:error, "source_id is required in metadata"} = TestValidator.validate(event)

      # Test with empty map but missing required correlation_id
      event = create_valid_event()
      |> Map.put(:metadata, %{source_id: "source-123"})
      assert {:error, "correlation_id is required in metadata"} = TestValidator.validate(event)

      # Test with non-map value
      event = create_valid_event()
      |> Map.put(:metadata, "not_a_map")
      assert {:error, "metadata must be a map"} = TestValidator.validate(event)

      # Test with valid metadata
      event = create_valid_event()
      |> Map.put(:metadata, %{source_id: "source-123", correlation_id: "corr-123"})
      assert :ok = TestValidator.validate(event)
    end
  end

  describe "validate_fields/1" do
    test "handles optional fields correctly" do
      message = create_test_message()
      {:ok, metadata} = Metadata.from_discord_message(message)

      event = %ValidatorOptionalFieldsEvent{
        game_id: "game-123",
        guild_id: "guild-123",
        mode: :knockout,
        timestamp: DateTime.utc_now(),
        metadata: metadata
      }
      assert :ok = TestValidator.validate(event)

      event = %ValidatorOptionalFieldsEvent{
        game_id: "game-123",
        guild_id: "guild-123",
        mode: :knockout,
        timestamp: DateTime.utc_now(),
        metadata: metadata,
        optional_field: "valid string"
      }
      assert :ok = TestValidator.validate(event)

      event = %ValidatorOptionalFieldsEvent{
        game_id: "game-123",
        guild_id: "guild-123",
        mode: :knockout,
        timestamp: DateTime.utc_now(),
        metadata: metadata,
        optional_field: 123
      }
      assert {:error, "optional_field must be a string or nil"} = TestValidator.validate(event)
    end
  end

  describe "error messages" do
    test "provides descriptive error messages" do
      event = create_valid_event(count: "invalid")
      assert {:error, message} = TestValidator.validate(event)
      assert message =~ "count must be a positive integer"

      event = create_valid_event(score: "invalid")
      assert {:error, message} = TestValidator.validate(event)
      assert message =~ "score must be an integer"

      # Test with metadata missing required field
      event = create_valid_event() |> Map.put(:metadata, %{correlation_id: "corr-123"})
      assert {:error, message} = TestValidator.validate(event)
      assert message =~ "source_id is required in metadata"
    end
  end
end
