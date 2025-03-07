defmodule GameBot.Bot.CommandHandler do
  @moduledoc """
  Handles command processing for both interactions and messages.
  """

  require Logger
  alias Nostrum.Struct.Message
  alias GameBot.Bot.Commands.{GameCommands, StatsCommands, ReplayCommands}

  # ETS table for tracking active games
  @active_games_table :active_games

  @doc """
  Initialize the command handler.
  Creates the ETS table for tracking active games.
  """
  def init do
    :ets.new(@active_games_table, [:named_table, :set, :public])
  end

  @doc """
  Set the active game for a user.
  """
  def set_active_game(user_id, game_id, guild_id) do
    :ets.insert(@active_games_table, {user_id, game_id, guild_id})
  end

  @doc """
  Clear the active game for a user.
  """
  def clear_active_game(user_id, guild_id) do
    :ets.delete(@active_games_table, {user_id, guild_id})
  end

  @doc """
  Get the active game for a user.
  """
  def get_active_game(user_id, guild_id) do
    case :ets.lookup(@active_games_table, {user_id, guild_id}) do
      [{_, game_id, _}] -> game_id
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

  def handle_interaction(interaction) do
    # Stub for testing
    :ok
  end

  @doc """
  Extract a command from a message.
  Parses the command prefix and returns the command details.

  ## Parameters
    * `message` - Discord message to extract command from

  ## Returns
    * `{:ok, command}` - Successfully extracted command
    * `{:error, reason}` - Failed to extract command
  """
  def extract_command(%Message{content: content} = message) when is_binary(content) do
    cond do
      # Prefix command (e.g., !stats)
      String.starts_with?(content, "!") ->
        command = String.slice(content, 1..-1) |> String.trim()
        {:ok, %{type: :prefix, content: command, message: message}}

      # Direct message guess
      message.guild_id == nil ->
        {:ok, %{type: :dm, content: content, message: message}}

      # Not a command
      true ->
        {:error, :not_command}
    end
  end

  def extract_command(_), do: {:error, :invalid_message}

  # Private Functions

  defp handle_dm_message(message) do
    case get_active_game(message.author.id, message.guild_id) do
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
