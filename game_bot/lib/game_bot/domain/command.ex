defmodule GameBot.Domain.Command do
  @moduledoc """
  Defines and processes game commands.
  
  This module is responsible for validating and processing commands
  from the Discord interface before generating appropriate events.
  """
  
  alias GameBot.Domain.Event
  
  @doc """
  Processes a command and generates appropriate events.
  
  Returns {:ok, message} on success or {:error, reason} on failure.
  """
  def process(command_type, params)

  def process(:start_game, %{channel_id: channel_id, user_id: user_id, args: args}) do
    # Validate command parameters
    with {:ok, game_mode} <- validate_game_mode(args),
         {:ok, _event} <- Event.create(:game_started, %{
           channel_id: channel_id,
           initiator_id: user_id,
           game_mode: game_mode,
           timestamp: DateTime.utc_now()
         }) do
      {:ok, "Game started with mode: #{game_mode}"}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def process(:join_game, %{channel_id: channel_id, user_id: user_id}) do
    # Check if a game is in progress in this channel
    # Generate player_joined event if valid
    with {:ok, _event} <- Event.create(:player_joined, %{
           channel_id: channel_id,
           user_id: user_id,
           timestamp: DateTime.utc_now()
         }) do
      {:ok, "You have joined the game!"}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Add more command handlers as needed

  # Validation functions
  defp validate_game_mode([]) do
    # Default to two_player mode if not specified
    {:ok, "two_player"}
  end
  
  defp validate_game_mode([mode | _]) when mode in ["two_player", "knockout", "race", "golf_race", "longform"] do
    {:ok, mode}
  end
  
  defp validate_game_mode(_) do
    {:error, "Invalid game mode. Available modes: two_player, knockout, race, golf_race, longform"}
  end
end 