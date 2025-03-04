defmodule GameBot.Domain.GameState do
  @moduledoc """
  Defines the core game state structure used across all game modes.
  """

  @type team_state :: %{
    player_ids: [String.t()],
    current_words: [String.t()],
    guess_count: pos_integer(),    # Always >= 1, represents current attempt number
    pending_guess: %{              # Tracks incomplete guess pairs
      player_id: String.t(),
      word: String.t(),
      timestamp: DateTime.t()
    } | nil
  }

  @type t :: %__MODULE__{
    mode: atom(),                 # Module implementing the game mode
    teams: %{String.t() => team_state()},  # Map of team_id to team_state
    forbidden_words: %{String.t() => [String.t()]},  # Map of player_id to [forbidden words]
    round_number: pos_integer(),  # Current round number
    start_time: DateTime.t() | nil,  # Game start timestamp
    last_activity: DateTime.t() | nil,  # Last guess timestamp
    matches: [map()],            # List of successful matches with metadata
    scores: %{String.t() => term()},  # Map of team_id to current score
    status: :waiting | :in_progress | :completed  # Game status
  }

  defstruct [
    mode: nil,
    teams: %{},
    forbidden_words: %{},
    round_number: 1,
    start_time: nil,
    last_activity: nil,
    matches: [],
    scores: %{},
    status: :waiting
  ]

  @doc """
  Creates a new game state for the given mode and teams.
  """
  @spec new(atom(), %{String.t() => [String.t()]}) :: t()
  def new(mode, teams) when is_atom(mode) and is_map(teams) do
    team_states = Map.new(teams, fn {team_id, player_ids} ->
      {team_id, %{
        player_ids: player_ids,
        current_words: [],
        guess_count: 1,  # Start at 1 for first attempt
        pending_guess: nil
      }}
    end)

    forbidden_words = teams
    |> Enum.flat_map(fn {_team_id, player_ids} -> player_ids end)
    |> Map.new(fn player_id -> {player_id, []} end)

    %__MODULE__{
      mode: mode,
      teams: team_states,
      forbidden_words: forbidden_words
    }
  end

  @doc """
  Updates the forbidden words list for a player.
  """
  @spec add_forbidden_word(t(), String.t(), String.t()) :: t()
  def add_forbidden_word(state, player_id, word) do
    update_in(state.forbidden_words[player_id], fn words ->
      [word | words]
      |> Enum.take(12)  # Keep only the last 12 words
    end)
  end

  @doc """
  Checks if a word is forbidden for a player.
  """
  @spec word_forbidden?(t(), String.t(), String.t()) :: boolean()
  def word_forbidden?(state, player_id, word) do
    player_words = Map.get(state.forbidden_words, player_id, [])
    word in player_words
  end

  @doc """
  Increments the guess count for a team after a failed match.
  """
  @spec increment_guess_count(t(), String.t()) :: t()
  def increment_guess_count(state, team_id) do
    state
    |> update_in([Access.key(:teams), Access.key(team_id)], fn team_state ->
      %{team_state |
        guess_count: team_state.guess_count + 1,
        pending_guess: nil  # Clear any pending guess on increment
      }
    end)
  end

  @doc """
  Records a pending guess for a player in a team.
  Returns {:ok, updated_state} if this completes a pair,
  {:pending, updated_state} if waiting for partner,
  or {:error, reason} if invalid.
  """
  @spec record_pending_guess(t(), String.t(), String.t(), String.t()) ::
    {:ok, t(), %{player1_id: String.t(), player2_id: String.t(),
                 player1_word: String.t(), player2_word: String.t()}} |
    {:pending, t()} |
    {:error, term()}
  def record_pending_guess(state, team_id, player_id, word) do
    case get_in(state.teams, [team_id]) do
      nil ->
        {:error, :invalid_team}

      team_state ->
        case team_state.pending_guess do
          nil ->
            # No pending guess, record this one
            state = put_in(state.teams[team_id].pending_guess, %{
              player_id: player_id,
              word: word,
              timestamp: DateTime.utc_now()
            })
            {:pending, state}

          %{player_id: pending_player_id} when pending_player_id == player_id ->
            {:error, :duplicate_player_guess}

          %{player_id: other_player_id, word: other_word} ->
            # Complete the pair
            state = put_in(state.teams[team_id].pending_guess, nil)
            {:ok, state, %{
              player1_id: other_player_id,
              player2_id: player_id,
              player1_word: other_word,
              player2_word: word
            }}
        end
    end
  end

  @doc """
  Clears a pending guess for a team.
  """
  @spec clear_pending_guess(t(), String.t()) :: t()
  def clear_pending_guess(state, team_id) do
    put_in(state.teams[team_id].pending_guess, nil)
  end
end
