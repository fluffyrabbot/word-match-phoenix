defmodule GameBot.Infrastructure.Postgres.Queries do
  @moduledoc """
  Query modules to encapsulate database interactions.
  
  This module provides structured query functions for the application's data needs.
  """
  
  import Ecto.Query
  alias GameBot.Infrastructure.Repo
  alias GameBot.Infrastructure.Postgres.Models.{GameSession, User, Event}
  
  @doc """
  Gets events for a specific game session ordered by timestamp.
  """
  def get_events_for_game(game_session_id) do
    Event
    |> where([e], e.game_session_id == ^game_session_id)
    |> order_by([e], asc: e.timestamp)
    |> Repo.all()
  end
  
  @doc """
  Gets active game session for a Discord channel, if one exists.
  """
  def get_active_game_for_channel(channel_id) do
    GameSession
    |> where([g], g.channel_id == ^channel_id and g.status != "completed")
    |> limit(1)
    |> Repo.one()
  end
  
  @doc """
  Gets or creates a user record for a Discord user.
  """
  def get_or_create_user(discord_id, username) do
    case Repo.get_by(User, discord_id: discord_id) do
      nil ->
        # Create new user
        %User{}
        |> User.changeset(%{discord_id: discord_id, username: username})
        |> Repo.insert()
        
      user ->
        # Update username if it changed
        if user.username != username do
          user
          |> User.changeset(%{username: username})
          |> Repo.update()
        else
          {:ok, user}
        end
    end
  end
  
  @doc """
  Gets leaderboard statistics for all users.
  """
  def get_leaderboard(limit \\ 10) do
    User
    |> select([u], %{
      id: u.id,
      username: u.username,
      games_played: u.games_played,
      wins: u.wins,
      score: u.total_score
    })
    |> order_by([u], desc: u.total_score)
    |> limit(^limit)
    |> Repo.all()
  end
  
  @doc """
  Gets player statistics for a specific Discord user.
  """
  def get_player_stats(discord_id) do
    # Using a different approach for the max calculation
    user = User
    |> where([u], u.discord_id == ^discord_id)
    |> Repo.one()
    
    if user do
      games_played = max(user.games_played, 1)
      avg_score = user.total_score / games_played
      
      %{
        username: user.username,
        games_played: user.games_played,
        wins: user.wins,
        losses: user.losses,
        total_score: user.total_score,
        avg_score: avg_score
      }
    else
      nil
    end
  end
  
  @doc """
  Stores a new game event.
  """
  def store_event(params) do
    %Event{}
    |> Event.changeset(params)
    |> Repo.insert()
  end
  
  @doc """
  Creates a new game session.
  """
  def create_game_session(params) do
    %GameSession{}
    |> GameSession.changeset(params)
    |> Repo.insert()
  end
  
  @doc """
  Updates an existing game session.
  """
  def update_game_session(game_session, params) do
    game_session
    |> GameSession.changeset(params)
    |> Repo.update()
  end
end 