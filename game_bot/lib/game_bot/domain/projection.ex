defmodule GameBot.Domain.Projection do
  @moduledoc """
  Handles read model projections for game stats and history.
  
  Projections are derived from events and provide an optimized view
  of the current state for querying.
  """
  
  alias GameBot.Domain.Event
  alias GameBot.Infrastructure.Cache
  
  @doc """
  Gets the current state of a game session.
  """
  def get_game_state(channel_id) do
    # Try to get from cache first
    case Cache.get(:game_states, channel_id) do
      nil ->
        # If not in cache, rebuild from events
        rebuild_game_state(channel_id)
        
      state ->
        {:ok, state}
    end
  end
  
  @doc """
  Gets player statistics.
  """
  def get_player_stats(user_id) do
    # Try to get from cache first
    case Cache.get(:player_stats, user_id) do
      nil ->
        # If not in cache, rebuild from events
        rebuild_player_stats(user_id)
        
      stats ->
        {:ok, stats}
    end
  end
  
  @doc """
  Apply an event to update projections.
  
  Called when new events occur to keep projections up-to-date.
  """
  def apply_event(event) do
    case event.type do
      :game_started ->
        update_game_state(event)
        
      :player_joined ->
        update_game_state(event)
        update_player_stats(event)
        
      # Add more event handlers as needed
        
      _ ->
        :ok
    end
  end
  
  # Private helper functions
  
  defp rebuild_game_state(channel_id) do
    # Get all events for the channel
    # Apply them in sequence to build current state
    # Store in cache
    # Return the state
    
    # Placeholder implementation
    state = %{
      status: :no_game,
      players: []
    }
    
    Cache.put(:game_states, channel_id, state)
    {:ok, state}
  end
  
  defp rebuild_player_stats(user_id) do
    # Get all events related to the player
    # Calculate stats from events
    # Store in cache
    # Return the stats
    
    # Placeholder implementation
    stats = %{
      games_played: 0,
      wins: 0,
      losses: 0
    }
    
    Cache.put(:player_stats, user_id, stats)
    {:ok, stats}
  end
  
  defp update_game_state(event) do
    # Handle specific event types to update game state
    channel_id = event.channel_id
    
    {:ok, current_state} = get_game_state(channel_id)
    
    new_state = case event.type do
      :game_started ->
        %{
          status: :in_progress,
          mode: event.game_mode,
          players: [event.initiator_id],
          started_at: event.timestamp
        }
        
      :player_joined ->
        # Only add player if not already in the game
        if event.user_id in current_state.players do
          current_state
        else
          %{current_state | players: [event.user_id | current_state.players]}
        end
        
      # Add more event handlers as needed
        
      _ ->
        current_state
    end
    
    # Update cache with new state
    Cache.put(:game_states, channel_id, new_state)
    
    {:ok, new_state}
  end
  
  defp update_player_stats(event) do
    # Handle specific event types to update player stats
    user_id = event.user_id
    
    {:ok, current_stats} = get_player_stats(user_id)
    
    new_stats = case event.type do
      :player_joined ->
        # Increment games played counter when player joins a game
        %{current_stats | games_played: current_stats.games_played + 1}
        
      # Add more event handlers as needed
        
      _ ->
        current_stats
    end
    
    # Update cache with new stats
    Cache.put(:player_stats, user_id, new_stats)
    
    {:ok, new_stats}
  end
end 