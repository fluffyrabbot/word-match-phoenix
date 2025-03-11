defmodule GameBot.Infrastructure.Persistence.EventStore.Serialization.JsonSerializerTest do
  use ExUnit.Case, async: false

  # This test doesn't require database access, so we can run it in isolation
  @moduletag :skip_db

  alias GameBot.Infrastructure.Error
  alias GameBot.Infrastructure.Persistence.EventStore.Serialization.JsonSerializer

  # Simple test event for serialization
  defmodule TestGuessError do
    defstruct [:game_id, :guild_id, :team_id, :player_id, :word, :reason, :timestamp, :metadata]

    def event_type, do: "guess_error"
    def event_version, do: 1

    # Simple constructor function
    def new(game_id, guild_id, team_id, player_id, word, reason) do
      %__MODULE__{
        game_id: game_id,
        guild_id: guild_id,
        team_id: team_id,
        player_id: player_id,
        word: word,
        reason: reason,
        timestamp: DateTime.utc_now(),
        metadata: %{}
      }
    end

    # Direct serialization method
    def to_map(%__MODULE__{} = event) do
      reason_string = if is_atom(event.reason), do: Atom.to_string(event.reason), else: event.reason
      timestamp_string = if is_struct(event.timestamp), do: DateTime.to_iso8601(event.timestamp), else: event.timestamp

      %{
        "game_id" => event.game_id,
        "guild_id" => event.guild_id,
        "team_id" => event.team_id,
        "player_id" => event.player_id,
        "word" => event.word,
        "reason" => reason_string,
        "timestamp" => timestamp_string
      }
    end

    # Direct deserialization method
    def from_map(data) do
      timestamp = case data["timestamp"] do
        t when is_binary(t) ->
          case DateTime.from_iso8601(t) do
            {:ok, dt, _} -> dt
            _ -> DateTime.utc_now()
          end
        t when is_struct(t) -> t
        _ -> DateTime.utc_now()
      end

      reason = case data["reason"] do
        r when is_binary(r) -> String.to_existing_atom(r)
        r when is_atom(r) -> r
        _ -> :invalid_word
      end

      %__MODULE__{
        game_id: data["game_id"],
        guild_id: data["guild_id"],
        team_id: data["team_id"],
        player_id: data["player_id"],
        word: data["word"],
        reason: reason,
        timestamp: timestamp
      }
    end
  end

  defmodule TestGuessPairError do
    defstruct [:game_id, :guild_id, :team_id, :word1, :word2, :reason, :timestamp, :metadata]

    def event_type, do: "guess_pair_error"
    def event_version, do: 1
  end

  # Define a simple invalid event struct for testing
  defmodule InvalidEvent do
    defstruct [:id]
    # deliberately missing required event_type and event_version functions
  end

  # Setting up required modules for tests to run in isolation
  defmodule TestRegistryMock do
    alias GameBot.Infrastructure.Persistence.EventStore.Serialization.JsonSerializerTest.{
      TestGuessError, TestGuessPairError, InvalidEvent
    }

    # Only return event type for valid events, not for InvalidEvent
    def event_type_for(%InvalidEvent{}), do: nil
    def event_type_for(_), do: "test_event"

    # Only return event version for valid events, not for InvalidEvent
    def event_version_for(%InvalidEvent{}), do: nil
    def event_version_for(_), do: 1

    def module_for_type("guess_error"), do: {:ok, TestGuessError}
    def module_for_type("guess_pair_error"), do: {:ok, TestGuessPairError}
    def module_for_type("unknown_event"), do: {:error, "Unknown event type"}

    # Custom decoder/encoder functions
    def decode_event(TestGuessError, data), do: TestGuessError.from_map(data)
    def decode_event(_, _), do: nil

    def encode_event(%TestGuessError{} = event), do: TestGuessError.to_map(event)
    def encode_event(%InvalidEvent{}), do: nil
    def encode_event(_), do: %{}

    def migrate_event(_, _, _, _), do: {:error, "Migration not supported"}
  end

  setup do
    # Temporarily override the EventRegistry with our test mock
    original_registry = Application.get_env(:game_bot, :event_registry)
    Application.put_env(:game_bot, :event_registry, TestRegistryMock)

    on_exit(fn ->
      # Restore the original registry after test
      Application.put_env(:game_bot, :event_registry, original_registry)
    end)

    :ok
  end

  describe "serialize/2" do
    test "successfully serializes a valid event" do
      event = TestGuessError.new(
        "game_123",
        "guild_456",
        "team_789",
        "player_012",
        "word",
        :invalid_word
      )

      assert {:ok, serialized} = JsonSerializer.serialize(event)
      assert serialized["type"] == "guess_error"
      assert serialized["version"] == 1
      assert is_map(serialized["data"])
      assert is_map(serialized["metadata"])
    end

    test "preserves metadata during serialization" do
      metadata = %{"key" => "value"}
      event = %TestGuessError{
        game_id: "game_123",
        guild_id: "guild_456",
        team_id: "team_789",
        player_id: "player_012",
        word: "word",
        reason: :invalid_word,
        timestamp: DateTime.utc_now(),
        metadata: metadata
      }

      assert {:ok, serialized} = JsonSerializer.serialize(event)
      assert serialized["metadata"] == metadata
    end

    test "returns error for invalid event struct" do
      assert {:error, %Error{type: :validation}} = JsonSerializer.serialize(%{not: "an event"})
    end

    test "returns error for event missing required functions" do
      # This should fail validation because InvalidEvent doesn't have event_type/event_version
      # and we've set our registry to return nil for these values
      assert {:error, %Error{type: :validation}} = JsonSerializer.serialize(%InvalidEvent{})
    end
  end

  describe "deserialize/2" do
    test "successfully deserializes valid data" do
      event = TestGuessError.new(
        "game_123",
        "guild_456",
        "team_789",
        "player_012",
        "word",
        :invalid_word
      )
      {:ok, serialized} = JsonSerializer.serialize(event)

      assert {:ok, deserialized} = JsonSerializer.deserialize(serialized)
      assert deserialized.__struct__ == TestGuessError
      assert deserialized.game_id == "game_123"
      assert deserialized.guild_id == "guild_456"
      assert deserialized.team_id == "team_789"
      assert deserialized.player_id == "player_012"
      assert deserialized.word == "word"
      assert deserialized.reason == :invalid_word
    end

    test "preserves metadata during deserialization" do
      metadata = %{"key" => "value"}
      event = %TestGuessError{
        game_id: "game_123",
        guild_id: "guild_456",
        team_id: "team_789",
        player_id: "player_012",
        word: "word",
        reason: :invalid_word,
        timestamp: DateTime.utc_now(),
        metadata: metadata
      }
      {:ok, serialized} = JsonSerializer.serialize(event)

      assert {:ok, deserialized} = JsonSerializer.deserialize(serialized)
      assert deserialized.metadata == metadata
    end

    test "returns error for invalid data format" do
      assert {:error, %Error{type: :validation}} = JsonSerializer.deserialize("not a map")
    end

    test "returns error for missing required fields" do
      assert {:error, %Error{type: :validation}} = JsonSerializer.deserialize(%{})
      assert {:error, %Error{type: :validation}} = JsonSerializer.deserialize(%{"type" => "guess_error"})
    end

    test "returns error for unknown event type" do
      data = %{
        "type" => "unknown_event",
        "version" => 1,
        "data" => %{},
        "metadata" => %{}
      }

      assert {:error, %Error{type: :not_found}} = JsonSerializer.deserialize(data)
    end
  end

  describe "validate/2" do
    test "validates valid data" do
      data = %{
        "type" => "guess_error",
        "version" => 1,
        "data" => %{},
        "metadata" => %{}
      }

      assert :ok = JsonSerializer.validate(data)
    end

    test "returns error for invalid data" do
      assert {:error, %Error{}} = JsonSerializer.validate("not a map")
      assert {:error, %Error{}} = JsonSerializer.validate(%{})
      assert {:error, %Error{}} = JsonSerializer.validate(%{"type" => "test"})
      assert {:error, %Error{}} = JsonSerializer.validate(%{
        "type" => "test",
        "version" => 1,
        "data" => %{},
        "metadata" => "not a map"
      })
    end
  end

  describe "migrate/4" do
    test "returns same data when versions match" do
      data = %{"version" => 1}
      assert {:ok, ^data} = JsonSerializer.migrate(data, 1, 1)
    end

    test "returns error when migrating to older version" do
      assert {:error, %Error{type: :validation}} = JsonSerializer.migrate(%{}, 2, 1)
    end

    test "returns error when migration not supported" do
      assert {:error, %Error{type: :validation}} = JsonSerializer.migrate(%{}, 1, 2)
    end
  end

  describe "version/0" do
    test "returns current version" do
      assert is_integer(JsonSerializer.version())
      assert JsonSerializer.version() > 0
    end
  end
end
