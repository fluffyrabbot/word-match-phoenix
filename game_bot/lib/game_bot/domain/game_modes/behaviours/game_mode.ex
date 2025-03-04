defmodule GameBot.Domain.GameModes.Behaviour.GameMode do
  @moduledoc """
  Defines the core behavior that all game modes must implement.
  """

  alias GameBot.Domain.GameState
  alias GameBot.Domain.Events.GameEvents.{GuessProcessed, GuessAbandoned}

  @type game_id :: String.t()
  @type team_id :: String.t()
  @type player_id :: String.t()
  @type teams :: %{team_id() => [player_id()]}
  @type config :: map()
  @type error :: {:error, term()}
  @type guess :: %{
    player1_id: player_id(),
    player2_id: player_id(),
    player1_word: String.t(),
    player2_word: String.t()
  }

  @doc """
  Initializes a new game session.
  """
  @callback init(game_id(), teams(), config()) ::
    {:ok, GameState.t()} | error()

  @doc """
  Handles a guess attempt from a team.
  """
  @callback handle_guess(GameState.t(), team_id(), guess()) ::
    {:ok, GameState.t(), GuessProcessed.t()} | error()

  @doc """
  Handles an abandoned guess attempt.
  """
  @callback handle_guess_abandoned(GameState.t(), team_id(), :timeout | :player_quit, map() | nil) ::
    {:ok, GameState.t(), GuessAbandoned.t()} | error()

  @doc """
  Checks if the current round should end.
  """
  @callback check_round_end(GameState.t()) ::
    {:round_end, [team_id()]} | :continue | error()

  @doc """
  Checks if the game should end.
  """
  @callback check_game_end(GameState.t()) ::
    {:game_end, [team_id()]} | :continue | error()
end
