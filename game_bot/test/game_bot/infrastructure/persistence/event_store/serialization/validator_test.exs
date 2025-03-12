defmodule GameBot.Infrastructure.Persistence.EventStore.Serialization.ValidatorTest do
  @moduledoc """
  Tests for the event store serialization validator.
  """

  use ExUnit.Case, async: true
  alias GameBot.Infrastructure.Persistence.EventStore.Serialization.Validator
  alias GameBot.Domain.Events.GameEvents.{GameStarted, GuessProcessed}

  describe "validate/1" do
    test "validates valid events" do
      valid_game_started = %GameStarted{
        game_id: "game123",
        guild_id: "guild456",
        mode: :standard,
        timestamp: DateTime.utc_now(),
        metadata: %{source_id: "src123", correlation_id: "corr123"},
        round_number: 1,
        teams: %{"team1" => ["player1", "player2"], "team2" => ["player3", "player4"]},
        team_ids: ["team1", "team2"],
        player_ids: ["player1", "player2", "player3", "player4"],
        roles: %{"player1" => :guesser, "player2" => :clue_giver, "player3" => :guesser, "player4" => :clue_giver},
        config: %{},
        started_at: DateTime.utc_now()
      }

      valid_guess_processed = %GuessProcessed{
        game_id: "game123",
        guild_id: "guild456",
        mode: :standard,
        timestamp: DateTime.utc_now(),
        metadata: %{source_id: "src123", correlation_id: "corr123"},
        round_number: 1,
        team_id: "team1",
        player1_info: %{id: "player1", name: "Player 1"},
        player2_info: %{id: "player2", name: "Player 2"},
        player1_word: "apple",
        player2_word: "banana",
        guess_successful: true,
        match_score: 10,
        guess_count: 1,
        round_guess_count: 1,
        total_guesses: 5,
        guess_duration: 30
      }

      assert :ok = Validator.validate(valid_game_started)
      assert :ok = Validator.validate(valid_guess_processed)
    end

    test "returns error for invalid events" do
      invalid_event = %GameStarted{
        game_id: "game123",
        guild_id: "guild456",
        mode: :standard,
        timestamp: DateTime.utc_now(),
        metadata: %{source_id: "src123", correlation_id: "corr123"},
        # Invalid round number for GameStarted (must be 1)
        round_number: 2,
        teams: %{"team1" => ["player1", "player2"]},
        team_ids: ["team1"],
        player_ids: ["player1", "player2"],
        roles: %{"player1" => :guesser, "player2" => :clue_giver},
        config: %{},
        started_at: DateTime.utc_now()
      }

      assert {:error, error} = Validator.validate(invalid_event)
      assert error.message == "round_number must be 1 for game start"
    end

    test "handles protocol not implemented gracefully" do
      # Create a struct that doesn't implement EventValidator
      not_implemented = %{__struct__: NotImplementedStruct}

      assert {:error, error} = Validator.validate(not_implemented)
      assert error.message =~ "No validator defined for event type"
    end
  end

  describe "validate_structure/1" do
    test "validates properly structured event data" do
      valid_data = %{
        "type" => "game_started",
        "version" => 1,
        "data" => %{
          "game_id" => "game123",
          "guild_id" => "guild456",
          "mode" => "standard"
        },
        "metadata" => %{
          "source_id" => "src123",
          "correlation_id" => "corr123"
        }
      }

      assert :ok = Validator.validate_structure(valid_data)
    end

    test "accepts alternative key names" do
      valid_data = %{
        "event_type" => "game_started",
        "event_version" => 1,
        "data" => %{},
        "metadata" => %{}
      }

      assert :ok = Validator.validate_structure(valid_data)
    end

    test "detects missing fields" do
      missing_type = %{"version" => 1, "data" => %{}, "metadata" => %{}}
      missing_version = %{"type" => "game_started", "data" => %{}, "metadata" => %{}}
      missing_data = %{"type" => "game_started", "version" => 1, "metadata" => %{}}

      assert {:error, error} = Validator.validate_structure(missing_type)
      assert error.message =~ "missing type field"

      assert {:error, error} = Validator.validate_structure(missing_version)
      assert error.message =~ "missing version field"

      assert {:error, error} = Validator.validate_structure(missing_data)
      assert error.message =~ "missing data field"
    end

    test "validates field types" do
      invalid_data_type = %{
        "type" => "game_started",
        "version" => 1,
        "data" => "not a map",
        "metadata" => %{}
      }

      invalid_metadata_type = %{
        "type" => "game_started",
        "version" => 1,
        "data" => %{},
        "metadata" => "not a map"
      }

      assert {:error, error} = Validator.validate_structure(invalid_data_type)
      assert error.message =~ "data must be a map"

      assert {:error, error} = Validator.validate_structure(invalid_metadata_type)
      assert error.message =~ "metadata must be a map"
    end

    test "rejects non-map inputs" do
      assert {:error, _} = Validator.validate_structure("not a map")
      assert {:error, _} = Validator.validate_structure(nil)
      assert {:error, _} = Validator.validate_structure(123)
    end
  end

  describe "validate_event_data/2" do
    test "validates game_started data" do
      valid_data = %{
        "game_id" => "game123",
        "guild_id" => "guild456",
        "mode" => "standard",
        "teams" => %{"team1" => ["player1", "player2"]}
      }

      missing_fields = %{
        "game_id" => "game123"
      }

      invalid_teams = %{
        "game_id" => "game123",
        "guild_id" => "guild456",
        "mode" => "standard",
        "teams" => "not a map"
      }

      assert :ok = Validator.validate_event_data(valid_data, "game_started")
      assert {:error, _} = Validator.validate_event_data(missing_fields, "game_started")
      assert {:error, _} = Validator.validate_event_data(invalid_teams, "game_started")
    end

    test "validates guess_processed data" do
      valid_data = %{
        "game_id" => "game123",
        "guild_id" => "guild456",
        "team_id" => "team1",
        "player1_info" => %{"id" => "player1", "name" => "Player 1"},
        "player2_info" => %{"id" => "player2", "name" => "Player 2"},
        "player1_word" => "apple",
        "player2_word" => "banana"
      }

      missing_fields = %{
        "game_id" => "game123"
      }

      assert :ok = Validator.validate_event_data(valid_data, "guess_processed")
      assert {:error, _} = Validator.validate_event_data(missing_fields, "guess_processed")
    end

    test "accepts unknown event types with basic validation" do
      valid_data = %{
        "game_id" => "game123",
        "guild_id" => "guild456"
      }

      assert :ok = Validator.validate_event_data(valid_data, "unknown_event_type")
    end

    test "rejects invalid input types" do
      assert {:error, _} = Validator.validate_event_data("not a map", "game_started")
      assert {:error, _} = Validator.validate_event_data(%{}, nil)
    end
  end
end

# Fake struct for testing protocol errors
defmodule NotImplementedStruct do
  defstruct []
end
