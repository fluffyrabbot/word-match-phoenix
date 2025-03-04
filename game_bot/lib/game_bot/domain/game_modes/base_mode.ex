defmodule GameBot.Domain.GameModes.BaseMode do
  @moduledoc """
  Defines the base behavior and common functionality for all game modes.
  """

  alias GameBot.Domain.GameState
  alias GameBot.Domain.Events.GameEvents.{
    GameStarted,
    GuessProcessed,
    GuessAbandoned,
    TeamEliminated,
    GameCompleted
  }

  @type config :: term()
  @type game_id :: String.t()
  @type team_id :: String.t()
  @type player_id :: String.t()
  @type word :: String.t()
  @type error :: {:error, term()}
  @type guess_pair :: %{
    player1_id: player_id(),
    player2_id: player_id(),
    player1_word: word(),
    player2_word: word()
  }

  @callback init(game_id(), %{team_id() => [player_id()]}, config()) ::
    {:ok, GameState.t()} | error()

  @callback process_guess_pair(GameState.t(), team_id(), guess_pair()) ::
    {:ok, GameState.t(), GuessProcessed.t()} | error()

  @callback handle_guess_abandoned(GameState.t(), team_id(), :timeout | :player_quit, map() | nil) ::
    {:ok, GameState.t(), GuessAbandoned.t()} | error()

  @callback check_round_end(GameState.t()) ::
    {:round_end, [team_id()]} | :continue | error()

  @callback check_game_end(GameState.t()) ::
    {:game_end, [team_id()]} | :continue | error()

  @doc """
  Common initialization logic for all game modes.
  """
  def initialize_game(mode, game_id, teams, config) do
    state = GameState.new(mode, teams)

    event = %GameStarted{
      game_id: game_id,
      mode: mode,
      round_number: 1,
      teams: teams,
      team_ids: Map.keys(teams),
      player_ids: List.flatten(Map.values(teams)),
      roles: %{},
      config: config,
      timestamp: DateTime.utc_now(),
      metadata: %{}
    }

    {:ok, state, [event]}
  end

  @doc """
  Common guess pair processing logic for all game modes.
  """
  def process_guess_pair(state, team_id, %{
    player1_id: player1_id,
    player2_id: player2_id,
    player1_word: player1_word,
    player2_word: player2_word
  } = guess_pair) do
    with :ok <- validate_guess_pair(state, team_id, guess_pair),
         state <- record_guess_pair(state, team_id, guess_pair) do

      guess_successful = player1_word == player2_word

      event = %GuessProcessed{
        game_id: game_id(state),
        mode: state.mode,
        round_number: state.round_number,
        team_id: team_id,
        player1_info: %{
          player_id: player1_id,
          team_id: team_id,
          role: :guesser
        },
        player2_info: %{
          player_id: player2_id,
          team_id: team_id,
          role: :guesser
        },
        player1_word: player1_word,
        player2_word: player2_word,
        guess_successful: guess_successful,
        guess_count: get_in(state.teams, [team_id, :guess_count]),
        match_score: if(guess_successful, do: 1, else: 0),
        timestamp: DateTime.utc_now(),
        metadata: %{}
      }

      state = if guess_successful do
        record_match(state, team_id, player1_word)
      else
        GameState.increment_guess_count(state, team_id)
      end

      {:ok, state, event}
    end
  end

  @doc """
  Common abandoned guess handling logic for all game modes.
  """
  def handle_guess_abandoned(state, team_id, reason, last_guess) do
    event = %GuessAbandoned{
      game_id: game_id(state),
      mode: state.mode,
      round_number: state.round_number,
      team_id: team_id,
      player1_info: %{
        player_id: last_guess["player1_id"],
        team_id: team_id,
        role: :guesser
      },
      player2_info: %{
        player_id: last_guess["player2_id"],
        team_id: team_id,
        role: :guesser
      },
      reason: reason,
      abandoning_player_id: last_guess["abandoning_player_id"],
      last_guess: last_guess,
      guess_count: get_in(state.teams, [team_id, :guess_count]),
      timestamp: DateTime.utc_now(),
      metadata: %{}
    }

    state = GameState.increment_guess_count(state, team_id)
    {:ok, state, event}
  end

  @doc """
  Validates a guess pair attempt.
  """
  def validate_guess_pair(state, team_id, %{
    player1_id: player1_id,
    player2_id: player2_id,
    player1_word: player1_word,
    player2_word: player2_word
  }) do
    team_players = get_in(state.teams, [team_id, :player_ids])

    cond do
      !Map.has_key?(state.teams, team_id) ->
        {:error, :invalid_team}

      player1_id not in team_players or player2_id not in team_players ->
        {:error, :invalid_player}

      player1_id == player2_id ->
        {:error, :same_player}

      GameState.word_forbidden?(state, player1_id, player1_word) ->
        {:error, :word_forbidden}

      GameState.word_forbidden?(state, player2_id, player2_word) ->
        {:error, :word_forbidden}

      true ->
        :ok
    end
  end

  @doc """
  Records a guess pair in the game state.
  """
  def record_guess_pair(state, team_id, %{
    player1_id: player1_id,
    player2_id: player2_id,
    player1_word: player1_word,
    player2_word: player2_word
  }) do
    now = DateTime.utc_now()

    state
    |> add_forbidden_words(player1_id, player1_word, player2_id, player2_word)
    |> Map.put(:last_activity, now)
  end

  @doc """
  Records a successful match in the game state.
  """
  def record_match(state, team_id, matched_word) do
    match = %{
      team_id: team_id,
      word: matched_word,
      guess_count: get_in(state.teams, [team_id, :guess_count]),
      timestamp: DateTime.utc_now()
    }

    %{state | matches: [match | state.matches]}
  end

  @doc """
  Handles team elimination.
  """
  def handle_elimination(state, team_id, reason) do
    event = %TeamEliminated{
      game_id: game_id(state),
      team_id: team_id,
      reason: reason,
      final_state: Map.get(state.teams, team_id),
      timestamp: DateTime.utc_now()
    }

    {:ok, state, event}
  end

  @doc """
  Handles game completion.
  """
  def handle_completion(state, winners) do
    event = %GameCompleted{
      game_id: game_id(state),
      winners: winners,
      final_scores: state.scores,
      timestamp: DateTime.utc_now()
    }

    state = %{state | status: :completed}
    {:ok, state, event}
  end

  # Private helpers

  defp game_id(%GameState{mode: mode, start_time: start_time}) do
    "#{mode}-#{DateTime.to_unix(start_time)}"
  end

  defp add_forbidden_words(state, player1_id, word1, player2_id, word2) do
    state
    |> GameState.add_forbidden_word(player1_id, word1)
    |> GameState.add_forbidden_word(player2_id, word2)
  end
end
