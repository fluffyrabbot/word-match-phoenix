defmodule GameBot.Domain.Events.PipelineTest do
  use ExUnit.Case, async: true
  alias GameBot.Domain.Events.Pipeline

  describe "process_event/1" do
    test "processes a valid event successfully" do
      event = %GameBot.Domain.Events.GuessEvents.GuessProcessed{
        game_id: "game-123",
        guild_id: "guild-456",
        mode: :two_player,
        round_number: 1,
        team_id: "team-789",
        player1_info: %{player_id: "player1"},
        player2_info: %{player_id: "player2"},
        player1_word: "word1",
        player2_word: "word2",
        guess_successful: true,
        match_score: 10,
        guess_count: 1,
        round_guess_count: 1,
        total_guesses: 1,
        guess_duration: 100,
        timestamp: DateTime.utc_now(),
        metadata: %{
          source_id: "msg-123",
          correlation_id: "corr-123"
        }
      }

      assert {:ok, processed_event} = Pipeline.process_event(event)
      assert processed_event.game_id == event.game_id
      assert processed_event.metadata.processed_at
      assert processed_event.metadata.processor_id
    end

    test "fails validation for invalid event" do
      event = %GameBot.Domain.Events.GuessEvents.GuessProcessed{
        game_id: "game-123",
        guild_id: "guild-456",
        mode: :two_player,
        round_number: 1,
        team_id: "team-789",
        player1_info: %{player_id: "player1"},
        player2_info: %{player_id: "player2"},
        player1_word: "word1",
        player2_word: "word2",
        guess_successful: true,
        match_score: 10,
        guess_count: -1,  # Invalid negative count
        round_guess_count: 1,
        total_guesses: 1,
        guess_duration: 100,
        timestamp: DateTime.utc_now(),
        metadata: %{
          source_id: "msg-123",
          correlation_id: "corr-123"
        }
      }

      assert {:error, _} = Pipeline.process_event(event)
    end

    test "fails validation for missing metadata" do
      event = %GameBot.Domain.Events.GuessEvents.GuessProcessed{
        game_id: "game-123",
        guild_id: "guild-456",
        mode: :two_player,
        round_number: 1,
        team_id: "team-789",
        player1_info: %{player_id: "player1"},
        player2_info: %{player_id: "player2"},
        player1_word: "word1",
        player2_word: "word2",
        guess_successful: true,
        match_score: 10,
        guess_count: 1,
        round_guess_count: 1,
        total_guesses: 1,
        guess_duration: 100,
        timestamp: DateTime.utc_now(),
        metadata: %{}  # Missing required metadata
      }

      assert {:error, _} = Pipeline.process_event(event)
    end
  end

  describe "validate/1" do
    test "validates a valid event" do
      event = %GameBot.Domain.Events.GuessEvents.GuessProcessed{
        game_id: "game-123",
        guild_id: "guild-456",
        mode: :two_player,
        round_number: 1,
        team_id: "team-789",
        player1_info: %{player_id: "player1"},
        player2_info: %{player_id: "player2"},
        player1_word: "word1",
        player2_word: "word2",
        guess_successful: true,
        match_score: 10,
        guess_count: 1,
        round_guess_count: 1,
        total_guesses: 1,
        guess_duration: 100,
        timestamp: DateTime.utc_now(),
        metadata: %{
          source_id: "msg-123",
          correlation_id: "corr-123"
        }
      }

      assert {:ok, ^event} = Pipeline.validate(event)
    end

    test "fails validation for invalid event" do
      event = %GameBot.Domain.Events.GuessEvents.GuessProcessed{
        game_id: "game-123",
        guild_id: "guild-456",
        mode: :two_player,
        round_number: 1,
        team_id: "team-789",
        player1_info: %{player_id: "player1"},
        player2_info: %{player_id: "player2"},
        player1_word: "word1",
        player2_word: "word2",
        guess_successful: true,
        match_score: 10,
        guess_count: -1,  # Invalid negative count
        round_guess_count: 1,
        total_guesses: 1,
        guess_duration: 100,
        timestamp: DateTime.utc_now(),
        metadata: %{
          source_id: "msg-123",
          correlation_id: "corr-123"
        }
      }

      assert {:error, _} = Pipeline.validate(event)
    end
  end

  describe "enrich/1" do
    test "enriches event metadata" do
      event = %GameBot.Domain.Events.GuessEvents.GuessProcessed{
        game_id: "game-123",
        guild_id: "guild-456",
        mode: :two_player,
        round_number: 1,
        team_id: "team-789",
        player1_info: %{player_id: "player1"},
        player2_info: %{player_id: "player2"},
        player1_word: "word1",
        player2_word: "word2",
        guess_successful: true,
        match_score: 10,
        guess_count: 1,
        round_guess_count: 1,
        total_guesses: 1,
        guess_duration: 100,
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
