defmodule GameBot.Domain.GameModes.Events do
  @moduledoc """
  Common event building functionality for game modes.
  """

  alias GameBot.Domain.Events.GameEvents
  alias GameBot.Domain.GameModes.State

  @doc """
  Builds a base event with common fields.
  """
  def build_base_event(state, type, fields) do
    Map.merge(
      %{
        game_id: game_id(state),
        mode: state.mode,
        round_number: state.round_number,
        timestamp: DateTime.utc_now(),
        metadata: build_metadata(state)
      },
      fields
    )
    |> struct(type)
  end

  @doc """
  Builds event metadata.
  """
  def build_metadata(state, opts \\ []) do
    base = %{
      client_version: Application.spec(:game_bot, :vsn),
      server_version: System.version(),
      correlation_id: opts[:correlation_id] || generate_correlation_id(),
      timestamp: DateTime.utc_now()
    }

    # Add optional fields if provided
    Enum.reduce(opts, base, fn
      {:causation_id, id}, acc -> Map.put(acc, :causation_id, id)
      {:user_agent, ua}, acc -> Map.put(acc, :user_agent, ua)
      {:ip_address, ip}, acc -> Map.put(acc, :ip_address, ip)
      _, acc -> acc
    end)
  end

  @doc """
  Builds a GameStarted event.
  """
  def build_game_started(state, game_id, teams, config) do
    build_base_event(state, GameEvents.GameStarted, %{
      game_id: game_id,
      teams: teams,
      team_ids: Map.keys(teams),
      player_ids: List.flatten(Map.values(teams)),
      config: config
    })
  end

  @doc """
  Builds a GuessProcessed event.
  """
  def build_guess_processed(state, team_id, guess_pair, result) do
    build_base_event(state, GameEvents.GuessProcessed, %{
      team_id: team_id,
      player1_info: %{
        player_id: guess_pair.player1_id,
        team_id: team_id
      },
      player2_info: %{
        player_id: guess_pair.player2_id,
        team_id: team_id
      },
      player1_word: guess_pair.player1_word,
      player2_word: guess_pair.player2_word,
      guess_successful: result.match?,
      guess_count: get_in(state.teams, [team_id, :guess_count]),
      match_score: Map.get(result, :score, 0)
    })
  end

  @doc """
  Builds a GuessAbandoned event.
  """
  def build_guess_abandoned(state, team_id, reason, last_guess) do
    build_base_event(state, GameEvents.GuessAbandoned, %{
      team_id: team_id,
      player1_info: %{
        player_id: last_guess["player1_id"],
        team_id: team_id
      },
      player2_info: %{
        player_id: last_guess["player2_id"],
        team_id: team_id
      },
      reason: reason,
      abandoning_player_id: last_guess["abandoning_player_id"],
      last_guess: last_guess,
      guess_count: get_in(state.teams, [team_id, :guess_count])
    })
  end

  @doc """
  Builds a TeamEliminated event.
  """
  def build_team_eliminated(state, team_id, reason) do
    build_base_event(state, GameEvents.TeamEliminated, %{
      team_id: team_id,
      reason: reason,
      final_state: Map.get(state.teams, team_id),
      final_score: get_in(state.scores, [team_id])
    })
  end

  @doc """
  Builds a GameCompleted event.
  """
  def build_game_completed(state, winners) do
    build_base_event(state, GameEvents.GameCompleted, %{
      winners: winners,
      final_scores: state.scores,
      game_duration: game_duration(state),
      total_rounds: state.round_number
    })
  end

  # Private helpers

  defp game_id(%State{mode: mode, start_time: start_time}) do
    "#{mode}-#{DateTime.to_unix(start_time)}"
  end

  defp game_duration(%State{start_time: start_time}) do
    DateTime.diff(DateTime.utc_now(), start_time)
  end

  defp generate_correlation_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
