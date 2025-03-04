defmodule GameBot.Domain.GameModes.State do
  @moduledoc """
  Common state management functionality for game modes.
  """

  @type t :: %__MODULE__{
    mode: atom(),
    round_number: pos_integer(),
    teams: %{String.t() => team_state()},
    status: game_status(),
    scores: %{String.t() => integer()},
    matches: [match()],
    last_activity: DateTime.t(),
    start_time: DateTime.t(),
    mode_state: map()
  }

  @type team_state :: %{
    player_ids: [String.t()],
    guess_count: non_neg_integer(),
    forbidden_words: MapSet.t(String.t()),
    status: team_status()
  }

  @type match :: %{
    team_id: String.t(),
    word: String.t(),
    guess_count: pos_integer(),
    timestamp: DateTime.t()
  }

  @type game_status :: :initialized | :in_round | :round_ended | :completed
  @type team_status :: :ready | :guessing | :eliminated

  defstruct [
    :mode,
    :round_number,
    :teams,
    :status,
    :scores,
    :matches,
    :last_activity,
    :start_time,
    mode_state: %{}
  ]

  @doc """
  Creates a new game state.
  """
  def new(mode, teams) do
    now = DateTime.utc_now()

    %__MODULE__{
      mode: mode,
      round_number: 1,
      teams: initialize_teams(teams),
      status: :initialized,
      scores: initialize_scores(teams),
      matches: [],
      last_activity: now,
      start_time: now
    }
  end

  @doc """
  Updates state after a guess attempt.
  """
  def update_after_guess(state, team_id, result) do
    state
    |> update_in([:teams, team_id, :guess_count], &(&1 + 1))
    |> Map.put(:last_activity, DateTime.utc_now())
    |> maybe_update_score(team_id, result)
  end

  @doc """
  Updates state for a new round.
  """
  def update_round(state, round_number) do
    %{state |
      round_number: round_number,
      status: :in_round,
      teams: reset_team_guesses(state.teams)
    }
  end

  @doc """
  Adds a forbidden word for a player.
  """
  def add_forbidden_word(state, player_id, word) do
    team_id = find_team_for_player(state, player_id)
    update_in(state.teams[team_id].forbidden_words, &MapSet.put(&1, String.downcase(word)))
  end

  @doc """
  Checks if a word is forbidden for a player.
  """
  def word_forbidden?(state, player_id, word) do
    team_id = find_team_for_player(state, player_id)
    word = String.downcase(word)
    MapSet.member?(get_in(state.teams, [team_id, :forbidden_words]), word)
  end

  @doc """
  Increments the guess count for a team.
  """
  def increment_guess_count(state, team_id) do
    update_in(state.teams[team_id].guess_count, &(&1 + 1))
  end

  # Private helpers

  defp initialize_teams(teams) do
    Map.new(teams, fn {team_id, player_ids} ->
      {team_id, %{
        player_ids: player_ids,
        guess_count: 0,
        forbidden_words: MapSet.new(),
        status: :ready
      }}
    end)
  end

  defp initialize_scores(teams) do
    Map.new(Map.keys(teams), &{&1, 0})
  end

  defp maybe_update_score(state, team_id, %{match?: true} = result) do
    update_in(state.scores[team_id], &(&1 + Map.get(result, :score, 1)))
  end
  defp maybe_update_score(state, _team_id, _result), do: state

  defp reset_team_guesses(teams) do
    Map.new(teams, fn {team_id, team} ->
      {team_id, %{team | guess_count: 0}}
    end)
  end

  defp find_team_for_player(state, player_id) do
    Enum.find_value(state.teams, fn {team_id, team} ->
      if player_id in team.player_ids, do: team_id, else: nil
    end)
  end
end
