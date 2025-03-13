defmodule GameBot.Domain.Events.ValidationHelpersTest do
  use ExUnit.Case, async: true

  alias GameBot.Domain.Events.ValidationHelpers

  describe "validate_string_value/1" do
    test "returns :ok for non-empty strings" do
      assert :ok = ValidationHelpers.validate_string_value("test")
      assert :ok = ValidationHelpers.validate_string_value("123")
    end

    test "returns error for nil" do
      assert {:error, "value is required"} = ValidationHelpers.validate_string_value(nil)
    end

    test "returns error for empty string" do
      assert {:error, "value must be a non-empty string"} = ValidationHelpers.validate_string_value("")
    end

    test "returns error for non-string values" do
      assert {:error, "value must be a string"} = ValidationHelpers.validate_string_value(123)
      assert {:error, "value must be a string"} = ValidationHelpers.validate_string_value(%{})
      assert {:error, "value must be a string"} = ValidationHelpers.validate_string_value([])
    end
  end

  describe "validate_string_value/2" do
    test "returns :ok for non-empty strings" do
      assert :ok = ValidationHelpers.validate_string_value("test", "field_name")
      assert :ok = ValidationHelpers.validate_string_value("123", "field_name")
    end

    test "returns error with field name for nil" do
      assert {:error, "field_name is required"} = ValidationHelpers.validate_string_value(nil, "field_name")
    end

    test "returns error with field name for empty string" do
      assert {:error, "field_name must be a non-empty string"} = ValidationHelpers.validate_string_value("", "field_name")
    end

    test "returns error with field name for non-string values" do
      assert {:error, "field_name must be a string"} = ValidationHelpers.validate_string_value(123, "field_name")
      assert {:error, "field_name must be a string"} = ValidationHelpers.validate_string_value(%{}, "field_name")
      assert {:error, "field_name must be a string"} = ValidationHelpers.validate_string_value([], "field_name")
    end
  end

  describe "validate_datetime_not_future/1" do
    test "returns :ok for past dates" do
      past_date = DateTime.add(DateTime.utc_now(), -3600, :second)
      assert :ok = ValidationHelpers.validate_datetime_not_future(past_date)
    end

    test "returns :ok for current date" do
      now = DateTime.utc_now()
      assert :ok = ValidationHelpers.validate_datetime_not_future(now)
    end

    test "returns error for future dates" do
      future_date = DateTime.add(DateTime.utc_now(), 3600, :second)
      assert {:error, "timestamp cannot be in the future"} = ValidationHelpers.validate_datetime_not_future(future_date)
    end

    test "returns error for nil" do
      assert {:error, "timestamp is required"} = ValidationHelpers.validate_datetime_not_future(nil)
    end

    test "returns error for non-DateTime values" do
      assert {:error, "timestamp must be a DateTime"} = ValidationHelpers.validate_datetime_not_future("2023-01-01")
      assert {:error, "timestamp must be a DateTime"} = ValidationHelpers.validate_datetime_not_future(123)
    end
  end

  describe "validate_not_future/2" do
    test "returns changeset with no errors for past dates" do
      past_date = DateTime.add(DateTime.utc_now(), -3600, :second)
      changeset = Ecto.Changeset.change(%{timestamp: past_date})
      result = ValidationHelpers.validate_not_future(changeset, :timestamp)
      refute result.errors[:timestamp]
    end

    test "returns changeset with no errors for current date" do
      now = DateTime.utc_now()
      changeset = Ecto.Changeset.change(%{timestamp: now})
      result = ValidationHelpers.validate_not_future(changeset, :timestamp)
      refute result.errors[:timestamp]
    end

    test "returns changeset with error for future dates" do
      future_date = DateTime.add(DateTime.utc_now(), 3600, :second)
      changeset = Ecto.Changeset.change(%{timestamp: future_date})
      result = ValidationHelpers.validate_not_future(changeset, :timestamp)
      assert {"cannot be in the future", _} = result.errors[:timestamp]
    end
  end

  describe "validate_player_info_tuple/2" do
    test "returns :ok for valid player info tuple" do
      assert :ok = ValidationHelpers.validate_player_info_tuple({"123", "Player Name"}, "player_info")
    end

    test "returns error for nil" do
      assert {:error, "player_info is required"} = ValidationHelpers.validate_player_info_tuple(nil, "player_info")
    end

    test "returns error for invalid tuple format" do
      assert {:error, "player_info must be a tuple of {id, name}"} = ValidationHelpers.validate_player_info_tuple({"123"}, "player_info")
      assert {:error, "player_info must be a tuple of {id, name}"} = ValidationHelpers.validate_player_info_tuple({123, "Name"}, "player_info")
      assert {:error, "player_info must be a tuple of {id, name}"} = ValidationHelpers.validate_player_info_tuple({"123", 123}, "player_info")
      assert {:error, "player_info must be a tuple of {id, name}"} = ValidationHelpers.validate_player_info_tuple(["123", "Name"], "player_info")
    end
  end

  describe "ensure_metadata_fields/2" do
    test "adds required fields to empty metadata" do
      guild_id = "123456"
      result = ValidationHelpers.ensure_metadata_fields(%{}, guild_id)

      assert result.guild_id == guild_id
      assert is_binary(result.source_id)
      assert is_binary(result.correlation_id)
    end

    test "preserves existing metadata fields" do
      guild_id = "123456"
      existing = %{
        custom_field: "value",
        another_field: 123
      }

      result = ValidationHelpers.ensure_metadata_fields(existing, guild_id)

      assert result.guild_id == guild_id
      assert result.custom_field == "value"
      assert result.another_field == 123
      assert is_binary(result.source_id)
      assert is_binary(result.correlation_id)
    end

    test "does not overwrite existing required fields" do
      guild_id = "123456"
      source_id = "existing-source-id"
      correlation_id = "existing-correlation-id"

      existing = %{
        guild_id: "existing-guild-id",
        source_id: source_id,
        correlation_id: correlation_id
      }

      result = ValidationHelpers.ensure_metadata_fields(existing, guild_id)

      # guild_id should be updated
      assert result.guild_id == guild_id
      # but source_id and correlation_id should be preserved
      assert result.source_id == source_id
      assert result.correlation_id == correlation_id
    end

    test "handles string keys in metadata" do
      guild_id = "123456"
      existing = %{
        "custom_field" => "value",
        "source_id" => "existing-source-id"
      }

      result = ValidationHelpers.ensure_metadata_fields(existing, guild_id)

      assert result.guild_id == guild_id
      assert result["custom_field"] == "value"
      assert result.source_id == "existing-source-id"
      assert is_binary(result.correlation_id)
    end
  end
end
