defmodule GameBot.Bot.Commands.UserCommands do
  @moduledoc """
  Handles user-related commands and automatic user registration.
  """

  alias GameBot.Domain.Events.{UserEvents, Metadata}
  alias Nostrum.Struct.{Interaction, Message}

  @doc """
  Automatically registers a user when they first interact with the bot.
  This should be called before processing any other command.
  """
  @spec register_user(Interaction.t() | Message.t()) :: {:ok, UserEvents.UserRegistered.t()} | {:error, term()}
  def register_user(%Interaction{user: user, guild_id: guild_id} = interaction) when not is_nil(guild_id) do
    metadata = Metadata.from_discord_interaction(interaction)

    event = %UserEvents.UserRegistered{
      user_id: "#{user.id}",
      guild_id: "#{guild_id}",
      username: user.username,
      display_name: user.global_name || user.username,
      created_at: DateTime.utc_now(),
      metadata: metadata
    }

    case UserEvents.UserRegistered.validate(event) do
      :ok -> {:ok, event}
      error -> error
    end
  end

  def register_user(%Message{author: author, guild_id: guild_id} = message) when not is_nil(guild_id) do
    metadata = Metadata.from_discord_message(message)

    event = %UserEvents.UserRegistered{
      user_id: "#{author.id}",
      guild_id: "#{guild_id}",
      username: author.username,
      display_name: author.global_name || author.username,
      created_at: DateTime.utc_now(),
      metadata: metadata
    }

    case UserEvents.UserRegistered.validate(event) do
      :ok -> {:ok, event}
      error -> error
    end
  end

  def register_user(_), do: {:error, :invalid_context}
end
