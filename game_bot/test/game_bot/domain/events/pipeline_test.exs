defmodule GameBot.Domain.Events.PipelineTest do
  use ExUnit.Case, async: true
  alias GameBot.Domain.Events.Pipeline
  alias GameBot.Domain.Events.GameEvents.GuessProcessed

  describe "validate/1" do
    test "validates a valid event with player durations" do
      event = %GuessProcessed{
        game_id: "game-123",
        guild_id: "guild-456",
        mode: :two_player,
        round_number: 1,
        team_id: "team-789",
        player1_id: "playerbob",
        player2_id: "playeralice",
        player1_word: "word1",
        player2_word: "word2",
        guess_successful: true,
        match_score: 10,
        guess_count: 1,
        round_guess_count: 1,
        total_guesses: 1,
        guess_duration: 100,
        player1_duration: 60,
        player2_duration: 100,
        timestamp: DateTime.utc_now(),
        metadata: %{
          source_id: "msg-123",
          correlation_id: "corr-123"
        }
      }

      assert {:ok, ^event} = Pipeline.validate(event)
    end

    test "fails validation for invalid event" do
      event = %GuessProcessed{
        game_id: "game-123",
        guild_id: "guild-456",
        mode: :two_player,
        round_number: 1,
        team_id: "team-789",
        player1_id: "playerbob",
        player2_id: "playeralice",
        player1_word: "word1",
        player2_word: "word2",
        guess_successful: true,
        match_score: 10,
        guess_count: -1,  # Invalid negative count
        round_guess_count: 1,
        total_guesses: 1,
        guess_duration: 100,
        player1_duration: 70,
        player2_duration: 100,
        timestamp: DateTime.utc_now(),
        metadata: %{
          source_id: "msg-123",
          correlation_id: "corr-123"
        }
      }

      assert {:error, _} = Pipeline.validate(event)
    end

    test "fails validation for negative player1_duration" do
      event = %GuessProcessed{
        game_id: "game-123",
        guild_id: "guild-456",
        mode: :two_player,
        round_number: 1,
        team_id: "team-789",
        player1_id: "playerbob",
        player2_id: "playeralice",
        player1_word: "word1",
        player2_word: "word2",
        guess_successful: true,
        match_score: 10,
        guess_count: 1,
        round_guess_count: 1,
        total_guesses: 1,
        guess_duration: 100,
        player1_duration: -5,  # Invalid negative duration
        player2_duration: 100,
        timestamp: DateTime.utc_now(),
        metadata: %{
          source_id: "msg-123",
          correlation_id: "corr-123"
        }
      }

      assert {:error, error_msg} = Pipeline.validate(event)
      assert error_msg =~ "player1_duration must be a non-negative integer"
    end

    test "fails validation for negative player2_duration" do
      event = %GuessProcessed{
        game_id: "game-123",
        guild_id: "guild-456",
        mode: :two_player,
        round_number: 1,
        team_id: "team-789",
        player1_id: "playerbob",
        player2_id: "playeralice",
        player1_word: "word1",
        player2_word: "word2",
        guess_successful: true,
        match_score: 10,
        guess_count: 1,
        round_guess_count: 1,
        total_guesses: 1,
        guess_duration: 100,
        player1_duration: 50,
        player2_duration: -10,  # Invalid negative duration
        timestamp: DateTime.utc_now(),
        metadata: %{
          source_id: "msg-123",
          correlation_id: "corr-123"
        }
      }

      assert {:error, error_msg} = Pipeline.validate(event)
      assert error_msg =~ "player2_duration must be a non-negative integer"
    end
  end

  describe "enrich/1" do
    test "enriches event metadata" do
      event = %GuessProcessed{
        game_id: "game-123",
        guild_id: "guild-456",
        mode: :two_player,
        round_number: 1,
        team_id: "team-789",
        player1_id: "playerbob",
        player2_id: "playeralice",
        player1_word: "word1",
        player2_word: "word2",
        guess_successful: true,
        match_score: 10,
        guess_count: 1,
        round_guess_count: 1,
        total_guesses: 1,
        guess_duration: 100,
        player1_duration: 90,
        player2_duration: 100,
        timestamp: DateTime.utc_now(),
        metadata: %{
          source_id: "msg-123",
          correlation_id: "corr-123"
        }
      }

      assert {:ok, enriched_event} = Pipeline.enrich({:ok, event})
      assert enriched_event.metadata.processed_at
      assert enriched_event.metadata.processor_id
    end

    test "passes through error" do
      error = {:error, :invalid_event}
      assert ^error = Pipeline.enrich(error)
    end
  end
end
