defmodule GameBot.Domain.GameModes.Behaviour.RoundManager do
  @moduledoc """
  Defines round management behavior. Different for each game mode.
  """

  alias GameBot.Domain.GameState
  alias GameBot.Domain.Events.GameEvents.{RoundStarted, RoundCompleted}

  @type error :: {:error, term()}
  @type team_id :: String.t()

  @doc """
  Starts a new round.
  """
  @callback start_round(GameState.t()) ::
    {:ok, GameState.t(), RoundStarted.t()} | error()

  @doc """
  Ends the current round.
  """
  @callback end_round(GameState.t(), [team_id()]) ::
    {:ok, GameState.t(), RoundCompleted.t()} | error()

  @doc """
  Checks if the current round should complete.
  """
  @callback check_round_completion(GameState.t()) ::
    {:complete, GameState.t()} | {:continue, GameState.t()} | error()

  @doc """
  Validates that a round can be started.
  """
  @callback validate_round_start(GameState.t()) ::
    :ok | error()

  @doc """
  Validates that a round can be ended.
  """
  @callback validate_round_end(GameState.t()) ::
    :ok | error()
end
