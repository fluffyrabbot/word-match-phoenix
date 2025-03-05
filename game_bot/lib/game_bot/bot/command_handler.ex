defmodule GameBot.Bot.CommandHandler do
  @moduledoc """
  Handles Discord message commands using the prefix format and DM guesses.
  """

  alias GameBot.Bot.Commands.GameCommands
  alias Nostrum.Struct.Message

  @command_prefix "!"  # Can be configured
  @active_games_table :active_games

  # Initialize ETS table in the module's init
  def init do
    :ets.new(@active_games_table, [:set, :public, :named_table])
    :ok
  end

  @doc """
  Handles messages from Discord channels and DMs.
  Returns {:ok, event} if a command was processed, :ignore for non-command messages.
  """
  def handle_message(%Message{content: "!" <> _ = content} = message) do
    case parse_command(content) do
      {"team", [mentioned_user_id]} when not is_nil(mentioned_user_id) ->
        options = %{
          name: generate_team_name(message.author.id, mentioned_user_id),
          players: [message.author.id, mentioned_user_id]
        }
        GameCommands.handle_team_create(message, options)

      # Add other message commands here
      _ ->
        {:error, :unknown_command}
    end
  end

  @doc """
  Handles direct message guesses. These are passed directly to game commands.
  """
  def handle_message(%Message{channel_type: 1} = message) do
    # Channel type 1 is DM
    case get_active_game_for_user(message.author.id) do
      {:ok, game_id} ->
        GameCommands.handle_guess(message, game_id, message.content, nil)
      _ ->
        {:error, :no_active_game}
    end
  end

  def handle_message(_message), do: :ignore

  # Private helpers

  defp parse_command(content) do
    [cmd | args] = String.split(String.trim_prefix(content, @command_prefix))
    {cmd, parse_args(args)}
  end

  defp parse_args(args) do
    args
    |> Enum.map(&parse_mention/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_mention(<<"<@", rest::binary>>) do
    case Integer.parse(String.trim_trailing(rest, ">")) do
      {user_id, ""} -> user_id
      _ -> nil
    end
  end
  defp parse_mention(_), do: nil

  defp generate_team_name(user1_id, user2_id) do
    # Simple team name generation - could be made more sophisticated
    "Team_#{min(user1_id, user2_id)}_#{max(user1_id, user2_id)}"
  end

  defp get_active_game_for_user(user_id) do
    case :ets.lookup(@active_games_table, user_id) do
      [{^user_id, game_id}] -> {:ok, game_id}
      [] -> {:error, :no_active_game}
    end
  end

  # Public API for managing active games (to be called by game management code)

  @doc """
  Associates a user with an active game.
  """
  def set_active_game(user_id, game_id) do
    :ets.insert(@active_games_table, {user_id, game_id})
    :ok
  end

  @doc """
  Removes a user's active game association.
  """
  def clear_active_game(user_id) do
    :ets.delete(@active_games_table, user_id)
    :ok
  end
end
