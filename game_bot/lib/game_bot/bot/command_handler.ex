defmodule GameBot.Bot.CommandHandler do
  @moduledoc """
  Handles command processing for the bot.
  """

  require Logger
  alias Nostrum.Struct.Message
  alias GameBot.Bot.Commands.{GameCommands, StatsCommands, ReplayCommands}

  # ETS table for tracking active games per user
  @active_games_table :active_games

  @doc """
  Initialize the command handler.
  Creates the ETS table for tracking active games.
  """
  def init do
    :ets.new(@active_games_table, [:named_table, :set, :public])
    :ok
  end

  @doc """
  Set the active game for a user.
  """
  def set_active_game(user_id, game_id) do
    :ets.insert(@active_games_table, {user_id, game_id})
    :ok
  end

  @doc """
  Clear the active game for a user.
  """
  def clear_active_game(user_id) do
    :ets.delete(@active_games_table, user_id)
    :ok
  end

  @doc """
  Get the active game for a user.
  """
  def get_active_game(user_id) do
    case :ets.lookup(@active_games_table, user_id) do
      [{^user_id, game_id}] -> game_id
      [] -> nil
    end
  end

  @doc """
  Handle incoming Discord messages.
  """
  def handle_message(%Message{type: 1} = message) do
    # DM message
    handle_dm_message(message)
  end

  def handle_message(%Message{content: "!" <> command} = message) do
    # Command message
    handle_command_message(command, message)
  end

  def handle_message(_message), do: :ok

  # Private Functions

  defp handle_dm_message(message) do
    case get_active_game(message.author.id) do
      nil ->
        :ok  # No active game, ignore DM
      game_id ->
        GameCommands.handle_guess(game_id, message.author.id, message.content)
    end
  end

  defp handle_command_message("stats" <> rest, message) do
    StatsCommands.handle_command(rest, message)
  end

  defp handle_command_message("replay" <> rest, message) do
    ReplayCommands.handle_command(rest, message)
  end

  defp handle_command_message(command, message) do
    GameCommands.handle_command(command, message)
  end
end
