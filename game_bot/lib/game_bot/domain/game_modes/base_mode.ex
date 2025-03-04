defmodule GameBot.Domain.GameModes.BaseMode do
  @moduledoc """
  Base module for game modes with common functionality.
  
  All game mode implementations should extend this module.
  """
  
  @callback start_game(map()) :: {:ok, map()} | {:error, String.t()}
  @callback join_game(map(), String.t()) :: {:ok, map()} | {:error, String.t()}
  @callback submit_answer(map(), String.t(), String.t()) :: {:ok, map(), :correct | :incorrect} | {:error, String.t()}
  @callback end_game(map()) :: {:ok, map()} | {:error, String.t()}
  
  @doc """
  Validates if a game can be started with the given parameters.
  
  Common validation logic shared by all game modes.
  """
  def validate_game_start(params) do
    # Basic validation that applies to all game modes
    cond do
      !Map.has_key?(params, :channel_id) ->
        {:error, "Channel ID is required"}
      
      !Map.has_key?(params, :initiator_id) ->
        {:error, "Initiator ID is required"}
        
      true ->
        {:ok, params}
    end
  end
  
  @doc """
  Checks if an answer is correct.
  
  This is a simple implementation that can be overridden by specific game modes.
  """
  def check_answer(expected, provided) do
    String.downcase(provided) == String.downcase(expected)
  end
  
  @doc """
  Calculates scores based on response time and correctness.
  
  Default scoring algorithm that can be overridden by specific game modes.
  """
  def calculate_score(response_time_ms, is_correct) do
    if is_correct do
      # Base score for correct answer
      base_score = 1000
      
      # Time penalty (faster answers get higher scores)
      time_factor = min(1.0, 10000 / max(1, response_time_ms))
      
      # Final score
      round(base_score * time_factor)
    else
      # No points for incorrect answers
      0
    end
  end
  
  @doc """
  Determines if a game has ended.
  
  Default implementation based on number of rounds completed.
  Can be overridden by specific game modes.
  """
  def game_ended?(game_state) do
    # Default: game ends after 10 rounds
    rounds_completed = Map.get(game_state, :rounds_completed, 0)
    max_rounds = Map.get(game_state, :max_rounds, 10)
    
    rounds_completed >= max_rounds
  end
  
  @doc """
  Determines winner(s) of the game.
  
  Default implementation based on highest score.
  Can be overridden by specific game modes.
  """
  def determine_winners(game_state) do
    # Get player scores
    scores = Map.get(game_state, :scores, %{})
    
    if Enum.empty?(scores) do
      []
    else
      # Find highest score
      max_score = scores
                 |> Map.values()
                 |> Enum.max(fn -> 0 end)
      
      # Get all players with the highest score
      scores
      |> Enum.filter(fn {_player, score} -> score == max_score end)
      |> Enum.map(fn {player, _score} -> player end)
    end
  end
end 