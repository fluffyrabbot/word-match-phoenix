defmodule GameBot.Domain.GameModes do
  @moduledoc """
  Provides high-level interface for game mode operations.
  Handles mode resolution and team management.
  """

  alias GameBot.Domain.GameState
  alias GameBot.Domain.GameModes.{RaceMode, KnockoutMode}

  @doc """
  Gets the appropriate game mode module based on the mode name.

  ## Parameters
    * `mode_name` - String name of the game mode

  ## Returns
    * `{:ok, module}` - The resolved game mode module
    * `{:error, :invalid_mode}` - If mode name is invalid

  ## Examples
      iex> GameModes.get_mode("race")
      {:ok, GameBot.Domain.GameModes.RaceMode}

      iex> GameModes.get_mode("invalid")
      {:error, :invalid_mode}
  """
  @spec get_mode(String.t()) :: {:ok, module()} | {:error, :invalid_mode}
  def get_mode(mode_name) when is_binary(mode_name) do
    case String.downcase(mode_name) do
      "race" -> {:ok, RaceMode}
      "knockout" -> {:ok, KnockoutMode}
      "two_player" -> {:ok, RaceMode} # Default to race mode for now
      _ -> {:error, :invalid_mode}
    end
  end

  @doc """
  Gets player information from a game state.

  ## Parameters
    * `game` - The current game state
    * `player_id` - ID of the player to look up

  ## Returns
    * `{:ok, player_info}` - Player's team information
    * `{:error, :player_not_found}` - If player is not in the game

  ## Examples
      iex> GameModes.get_player_info(game, "player123")
      {:ok, %{player_id: "player123", team_id: "team1"}}
  """
  @spec get_player_info(GameState.t(), String.t()) ::
    {:ok, %{player_id: String.t(), team_id: String.t()}} |
    {:error, :player_not_found}
  def get_player_info(%GameState{teams: teams} = _game, player_id) do
    case find_player_team(teams, player_id) do
      {:ok, team_id} ->
        {:ok, %{
          player_id: player_id,
          team_id: team_id
        }}
      :error ->
        {:error, :player_not_found}
    end
  end

  @doc """
  Gets teammate information for a player in a team.

  ## Parameters
    * `game` - The current game state
    * `player_info` - The current player's info

  ## Returns
    * Teammate's information map
  """
  @spec get_teammate_info(GameState.t(), map()) :: %{player_id: String.t(), team_id: String.t()}
  def get_teammate_info(%GameState{teams: teams}, %{team_id: team_id, player_id: player_id}) do
    team = Map.get(teams, team_id)
    teammate_id = Enum.find(team.player_ids, fn id -> id != player_id end)

    %{
      player_id: teammate_id,
      team_id: team_id
    }
  end

  # Private Helpers

  defp find_player_team(teams, player_id) do
    Enum.find_value(teams, :error, fn {team_id, team} ->
      if player_id in team.player_ids, do: {:ok, team_id}, else: nil
    end)
  end
end
