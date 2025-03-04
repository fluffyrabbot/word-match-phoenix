defmodule GameBot.Domain.GameModes.Behaviour.Scoring do
  @moduledoc """
  Defines scoring behavior. Implementation varies by mode.
  """

  alias GameBot.Domain.GameState

  @type team_id :: String.t()
  @type score :: integer()
  @type error :: {:error, term()}
  @type guess_result :: %{
    match?: boolean(),
    guess_count: pos_integer(),
    time_taken: integer() | nil,
    word: String.t() | nil
  }

  @doc """
  Calculates the score for a guess result.
  """
  @callback calculate_score(GameState.t(), team_id(), guess_result()) ::
    {:ok, score(), GameState.t()} | error()

  @doc """
  Updates team rankings based on current scores.
  """
  @callback update_rankings(GameState.t(), team_id(), score()) ::
    {:ok, GameState.t()} | error()

  @doc """
  Gets the current rankings.
  """
  @callback get_rankings(GameState.t()) ::
    {:ok, [{team_id(), score()}]} | error()

  @doc """
  Validates a score update.
  """
  @callback validate_score(GameState.t(), team_id(), score()) ::
    :ok | error()

  @doc """
  Gets the final scores for game completion.
  """
  @callback get_final_scores(GameState.t()) ::
    {:ok, %{team_id() => score()}} | error()
end
