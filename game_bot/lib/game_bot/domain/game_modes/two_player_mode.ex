defmodule GameBot.Domain.GameModes.TwoPlayerMode do
  @moduledoc """
  Two player game mode implementation.
  
  This game mode supports exactly two players who compete against each other.
  """
  
  @behaviour GameBot.Domain.GameModes.BaseMode
  
  alias GameBot.Domain.GameModes.BaseMode
  
  @doc """
  Starts a new two-player game.
  """
  @impl true
  def start_game(params) do
    with {:ok, validated_params} <- BaseMode.validate_game_start(params) do
      # Initialize game state
      game_state = %{
        mode: :two_player,
        status: :waiting_for_players,
        channel_id: validated_params.channel_id,
        players: [validated_params.initiator_id],
        scores: %{validated_params.initiator_id => 0},
        current_round: 0,
        max_rounds: 5,
        rounds_completed: 0,
        created_at: DateTime.utc_now()
      }
      
      {:ok, game_state}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Handles a player joining the game.
  """
  @impl true
  def join_game(game_state, player_id) do
    cond do
      # Player already in the game
      player_id in game_state.players ->
        {:error, "You are already in this game"}
        
      # Game already has two players
      length(game_state.players) >= 2 ->
        {:error, "Game is already full"}
        
      # Game is in progress
      game_state.status != :waiting_for_players ->
        {:error, "Game is already in progress"}
        
      # Player can join
      true ->
        new_players = [player_id | game_state.players]
        new_scores = Map.put(game_state.scores, player_id, 0)
        
        new_state = %{
          game_state |
          players: new_players,
          scores: new_scores
        }
        
        # If we have two players, game can start
        new_state = if length(new_players) == 2 do
          %{new_state | status: :ready_to_start}
        else
          new_state
        end
        
        {:ok, new_state}
    end
  end
  
  @doc """
  Processes a player's submitted answer.
  """
  @impl true
  def submit_answer(game_state, player_id, answer) do
    cond do
      # Player not in game
      player_id not in game_state.players ->
        {:error, "You are not in this game"}
        
      # Game not in active round
      game_state.status != :round_active ->
        {:error, "No active round to submit answers to"}
        
      # Process the answer
      true ->
        expected_answer = Map.get(game_state, :current_answer)
        is_correct = BaseMode.check_answer(expected_answer, answer)
        
        response_time_ms = DateTime.diff(
          DateTime.utc_now(),
          Map.get(game_state, :round_start_time),
          :millisecond
        )
        
        score = BaseMode.calculate_score(response_time_ms, is_correct)
        
        # Update player's score
        new_scores = Map.update(
          game_state.scores,
          player_id,
          score,
          &(&1 + score)
        )
        
        # Update game state
        new_state = %{
          game_state |
          scores: new_scores,
          rounds_completed: game_state.rounds_completed + 1,
          status: if(BaseMode.game_ended?(%{game_state | rounds_completed: game_state.rounds_completed + 1}), do: :game_over, else: :round_completed)
        }
        
        result = if is_correct, do: :correct, else: :incorrect
        
        {:ok, new_state, result}
    end
  end
  
  @doc """
  Ends the game and determines the winner.
  """
  @impl true
  def end_game(game_state) do
    winners = BaseMode.determine_winners(game_state)
    
    final_state = %{
      game_state |
      status: :game_over,
      winners: winners,
      ended_at: DateTime.utc_now()
    }
    
    {:ok, final_state}
  end
end 