defmodule GameBot.Benchmarks.EventProcessing do
  @moduledoc """
  Benchmark suite for event processing operations.
  Measures performance of event validation, serialization, and processing.
  """

  alias GameBot.Domain.Events.{Pipeline, GameEvents}
  require Logger

  def run do
    now = DateTime.utc_now()

    # Sample events for benchmarking
    game_started = %GameEvents.GameStarted{
      game_id: "game-123",
      guild_id: "guild-456",
      mode: :two_player,
      round_number: 1,
      teams: %{
        "team-789" => ["player1", "player2"]
      },
      team_ids: ["team-789"],
      player_ids: ["player1", "player2"],
      roles: %{
        "player1" => :giver,
        "player2" => :guesser
      },
      config: %{
        round_limit: 10,
        time_limit: 300,
        score_limit: 100
      },
      started_at: now,
      timestamp: now,
      metadata: %{
        source_id: "msg-123",
        correlation_id: "corr-123"
      }
    }

    game_ended = %GameEvents.GameCompleted{
      game_id: "game-123",
      guild_id: "guild-456",
      mode: :two_player,
      round_number: 10,
      winners: ["team-789"],
      final_scores: %{
        "team-789" => %{
          score: 100,
          matches: 10,
          total_guesses: 20,
          average_guesses: 2.0,
          player_stats: %{
            "player1" => %{
              total_guesses: 10,
              successful_matches: 5,
              abandoned_guesses: 0,
              average_guess_count: 2.0
            },
            "player2" => %{
              total_guesses: 10,
              successful_matches: 5,
              abandoned_guesses: 0,
              average_guess_count: 2.0
            }
          }
        }
      },
      game_duration: 300,
      total_rounds: 10,
      timestamp: now,
      finished_at: now,
      metadata: %{
        source_id: "msg-123",
        correlation_id: "corr-123"
      }
    }

    Logger.info("Starting event processing benchmarks...")

    Benchee.run(
      %{
        "validate_game_started" => fn -> Pipeline.validate(game_started) end,
        "validate_game_ended" => fn -> Pipeline.validate(game_ended) end,
        "serialize_game_started" => fn -> GameBot.Domain.Events.EventSerializer.to_map(game_started) end,
        "serialize_game_ended" => fn -> GameBot.Domain.Events.EventSerializer.to_map(game_ended) end,
        "deserialize_game_started" => fn ->
          game_started
          |> GameBot.Domain.Events.EventSerializer.to_map()
          |> GameBot.Domain.Events.EventSerializer.from_map()
        end,
        "deserialize_game_ended" => fn ->
          game_ended
          |> GameBot.Domain.Events.EventSerializer.to_map()
          |> GameBot.Domain.Events.EventSerializer.from_map()
        end,
        "process_game_started" => fn -> Pipeline.process_event(game_started) end,
        "process_game_ended" => fn -> Pipeline.process_event(game_ended) end
      },
      time: 10,
      memory_time: 2,
      formatters: [
        {Benchee.Formatters.HTML, file: "benchmarks/event_processing.html"},
        Benchee.Formatters.Console
      ],
      print: [
        fast_warning: false
      ],
      warmup: 2
    )
  end

  @doc """
  Run benchmarks and save results to HTML and console output.
  """
  def benchmark do
    # Ensure benchmark directory exists
    File.mkdir_p!("benchmarks")
    run()
  end
end
