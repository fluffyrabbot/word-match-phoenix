defmodule GameBot.Bot.CommandHandler do
  @moduledoc """
  Processes commands received from Discord.
  """
  
  alias Nostrum.Api
  alias GameBot.Domain.Command

  @command_prefix "!"

  @doc """
  Handles incoming Discord messages and processes commands.
  """
  def handle_message(msg) do
    # Ignore messages from bots (including ourselves)
    if msg.author.bot do
      :noop
    else
      process_content(msg)
    end
  end

  defp process_content(msg) do
    # Check if message content starts with command prefix
    if String.starts_with?(msg.content, @command_prefix) do
      # Extract command name and arguments
      [command_name | args] = msg.content
                             |> String.trim_leading(@command_prefix)
                             |> String.split(" ")

      # Process the command
      execute_command(String.downcase(command_name), args, msg)
    else
      :noop
    end
  end

  defp execute_command("start", args, msg) do
    # Example: Start a game session
    # Forward to domain command processor
    case Command.process(:start_game, %{
      channel_id: msg.channel_id,
      user_id: msg.author.id,
      args: args
    }) do
      {:ok, response} ->
        Api.create_message(msg.channel_id, response)
      
      {:error, reason} ->
        Api.create_message(msg.channel_id, "Error: #{reason}")
    end
  end

  defp execute_command(_unknown, _args, msg) do
    # Handle unknown commands
    Api.create_message(msg.channel_id, "Unknown command. Type !help for available commands.")
  end
end 