defmodule GameBot.Bot.ErrorHandler do
  require Logger
  alias Nostrum.Struct.{Message, Interaction}
  alias Nostrum.Api

  @spec format_error_message(atom()) :: String.t()
  def format_error_message(:rate_limited), do: "You're sending commands too quickly. Please wait a moment."
  def format_error_message(:message_too_long), do: "Your message is too long. Maximum allowed is 2000 characters."
  def format_error_message(:message_too_short), do: "Your message is too short. Please provide a valid message."
  def format_error_message(:word_too_long), do: "The word is too long. Please use a shorter word."
  def format_error_message(:word_too_short), do: "The word is too short. Please use a longer word."
  def format_error_message(:invalid_characters), do: "Your message contains invalid characters."
  def format_error_message(:excessive_mentions), do: "Too many mentions in your message."
  def format_error_message(:suspicious_content), do: "Your message was flagged as potentially suspicious."
  def format_error_message(:game_not_found), do: "Game not found."
  def format_error_message(:game_already_completed), do: "This game has already ended."
  def format_error_message(:game_not_ready), do: "The game is still initializing."
  def format_error_message(:invalid_game_state), do: "The game is not in a valid state for that action."
  def format_error_message(:unknown_command), do: "Unknown command."
  def format_error_message(:unknown_subcommand), do: "Unknown subcommand."
  def format_error_message(_), do: "An error occurred processing your request."

  @spec notify_user(Message.t(), atom()) :: :ok
  def notify_user(%Message{channel_id: channel_id}, reason) do
    message = %{
      content: format_error_message(reason),
      flags: 64  # Set the ephemeral flag
    }
    case Api.create_message(channel_id, message) do
      {:ok, _} -> :ok
      {:error, _} ->
        Logger.warning("Failed to send message: #{inspect(reason)}")
        :ok # We still return :ok even on failure
    end
  end

    @spec notify_interaction_error(Interaction.t(), atom()) :: :ok
    def notify_interaction_error(%Interaction{} = interaction, reason) do
        respond_with_error(interaction, reason)
    end

    defp respond_with_error(interaction, reason) do
        response = %{
          type: 4,
          data: %{
            content: format_error_message(reason),
            flags: 64
          }
        }

        case Api.create_interaction_response(
               interaction.id,
               interaction.token,
               response
             ) do
          {:ok, _} -> :ok
          {:error, _} ->
            Logger.warning("Failed to send interaction error response")
            :ok # Return :ok even on failure
        end
      end
end
