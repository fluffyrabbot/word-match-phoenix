defmodule GameBot.Domain.Events.EventValidatorTest do
  use ExUnit.Case, async: true

  alias GameBot.Domain.Events.{EventValidator, EventStructure, Metadata}

  # Test event struct for validation
  defmodule TestEvent do
    @moduledoc "Test event struct for validation tests"
    defstruct [:game_id, :guild_id, :mode, :timestamp, :metadata, :count, :score]

    defimpl EventValidator do
      def validate(event) do
        with :ok <- validate_base_fields(event),
             :ok <- validate_event_fields(event) do
          :ok
        end
      end

      defp validate_base_fields(event) do
        EventStructure.validate_base_fields(event)
      end

      defp validate_event_fields(event) do
        with :ok <- validate_count(event.count),
             :ok <- validate_score(event.score) do
          :ok
        end
      end

      defp validate_count(nil), do: {:error, "count is required"}
      defp validate_count(count) when is_integer(count) and count > 0, do: :ok
      defp validate_count(_), do: {:error, "count must be a positive integer"}

      defp validate_score(nil), do: {:error, "score is required"}
      defp validate_score(score) when is_integer(score), do: :ok
      defp validate_score(_), do: {:error, "score must be an integer"}
    end
  end

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
    metadata = Metadata.from_discord_message(message)
    timestamp = Keyword.get(opts, :timestamp, DateTime.utc_now())

    %TestEvent{
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
      assert :ok = EventValidator.validate(event)
    end

    test "returns error for missing base fields" do
      event = create_valid_event() |> Map.delete(:game_id)
      assert {:error, "game_id is required"} = EventValidator.validate(event)

      event = create_valid_event() |> Map.delete(:guild_id)
      assert {:error, "guild_id is required"} = EventValidator.validate(event)

      event = create_valid_event() |> Map.delete(:mode)
      assert {:error, "mode is required"} = EventValidator.validate(event)

      event = create_valid_event() |> Map.delete(:timestamp)
      assert {:error, "timestamp is required"} = EventValidator.validate(event)

      event = create_valid_event() |> Map.delete(:metadata)
      assert {:error, "metadata is required"} = EventValidator.validate(event)
    end

    test "returns error for invalid base field values" do
      event = create_valid_event(game_id: "")
      assert {:error, "game_id and guild_id must be non-empty strings"} = EventValidator.validate(event)

      event = create_valid_event(guild_id: "")
      assert {:error, "game_id and guild_id must be non-empty strings"} = EventValidator.validate(event)

      event = create_valid_event() |> Map.put(:mode, "not_an_atom")
      assert {:error, "mode must be an atom"} = EventValidator.validate(event)

      future_time = DateTime.add(DateTime.utc_now(), 3600, :second)
      event = create_valid_event(timestamp: future_time)
      assert {:error, "timestamp cannot be in the future"} = EventValidator.validate(event)
    end

    test "returns error for missing event-specific fields" do
      event = create_valid_event() |> Map.delete(:count)
      assert {:error, "count is required"} = EventValidator.validate(event)

      event = create_valid_event() |> Map.delete(:score)
      assert {:error, "score is required"} = EventValidator.validate(event)
    end

    test "returns error for invalid event-specific field values" do
      event = create_valid_event(count: 0)
      assert {:error, "count must be a positive integer"} = EventValidator.validate(event)

      event = create_valid_event(count: -1)
      assert {:error, "count must be a positive integer"} = EventValidator.validate(event)

      event = create_valid_event(count: "not_a_number")
      assert {:error, "count must be a positive integer"} = EventValidator.validate(event)

      event = create_valid_event(score: "not_a_number")
      assert {:error, "score must be an integer"} = EventValidator.validate(event)
    end

    test "validates metadata content" do
      event = create_valid_event()
      |> Map.put(:metadata, %{})
      assert {:error, "metadata must include guild_id or source_id"} = EventValidator.validate(event)

      event = create_valid_event()
      |> Map.put(:metadata, "not_a_map")
      assert {:error, "metadata must be a map"} = EventValidator.validate(event)

      event = create_valid_event()
      |> Map.put(:metadata, %{"source_id" => "source-123"})
      assert :ok = EventValidator.validate(event)
    end
  end

  describe "validate_fields/1" do
    defmodule OptionalFieldsEvent do
      @moduledoc "Test event with optional fields"
      defstruct [:game_id, :guild_id, :mode, :timestamp, :metadata, :optional_field]

      defimpl EventValidator do
        def validate(event) do
          with :ok <- validate_base_fields(event),
               :ok <- validate_fields(event) do
            :ok
          end
        end

        defp validate_base_fields(event) do
          EventStructure.validate_base_fields(event)
        end

        def validate_fields(event) do
          case event.optional_field do
            nil -> :ok
            value when is_binary(value) -> :ok
            _ -> {:error, "optional_field must be a string or nil"}
          end
        end
      end
    end

    test "handles optional fields correctly" do
      event = %OptionalFieldsEvent{
        game_id: "game-123",
        guild_id: "guild-123",
        mode: :knockout,
        timestamp: DateTime.utc_now(),
        metadata: %{"guild_id" => "guild-123"}
      }
      assert :ok = EventValidator.validate(event)

      event = %OptionalFieldsEvent{
        game_id: "game-123",
        guild_id: "guild-123",
        mode: :knockout,
        timestamp: DateTime.utc_now(),
        metadata: %{"guild_id" => "guild-123"},
        optional_field: "valid string"
      }
      assert :ok = EventValidator.validate(event)

      event = %OptionalFieldsEvent{
        game_id: "game-123",
        guild_id: "guild-123",
        mode: :knockout,
        timestamp: DateTime.utc_now(),
        metadata: %{"guild_id" => "guild-123"},
        optional_field: 123
      }
      assert {:error, "optional_field must be a string or nil"} = EventValidator.validate(event)
    end
  end

  describe "error messages" do
    test "provides descriptive error messages" do
      event = create_valid_event(count: "invalid")
      assert {:error, message} = EventValidator.validate(event)
      assert message =~ "count must be a positive integer"

      event = create_valid_event(score: "invalid")
      assert {:error, message} = EventValidator.validate(event)
      assert message =~ "score must be an integer"

      event = create_valid_event() |> Map.put(:metadata, %{})
      assert {:error, message} = EventValidator.validate(event)
      assert message =~ "metadata must include guild_id or source_id"
    end
  end
end
