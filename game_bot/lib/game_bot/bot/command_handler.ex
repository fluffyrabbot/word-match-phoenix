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

  @doc """
  Handles a Discord interaction.
  This is a placeholder for future implementation.
  """
  def handle_interaction(_interaction) do
    # Placeholder for future implementation
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
        command = String.slice(content, 1..-1//1) |> String.trim()
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

  @doc """
  Handle game start command from an interaction.
  """
  def handle_start_game(interaction, mode, options) do
    # Create metadata from interaction
    metadata = %{
      guild_id: interaction.guild_id,
      correlation_id: UUID.uuid4(),
      timestamp: DateTime.utc_now(),
      source: :interaction,
      source_id: interaction.user.id,
      interaction_id: interaction.id,
      user_id: interaction.user.id
    }

    # Create game started event
    event = GameBot.Domain.Events.GameEvents.GameStarted.new(
      UUID.uuid4(),  # game_id
      interaction.guild_id,  # guild_id
      mode,
      options.teams.team_map,  # teams
      options.teams.team_ids,
      options.teams.player_ids,
      %{},  # roles (empty map as default)
      %{},  # config (empty map as default)
      nil,  # started_at (nil uses current time)
      metadata  # pass the metadata we created
    )

    # Return {:ok, event} tuple as expected by tests
    {:ok, event}
  end

  @doc """
  Handle team creation command from an interaction.
  """
  def handle_team_create(interaction, params) do
    # Create metadata from interaction
    metadata = %{
      guild_id: interaction.guild_id,
      correlation_id: UUID.uuid4(),
      timestamp: DateTime.utc_now(),
      source: :interaction,
      source_id: interaction.user.id,
      interaction_id: interaction.id,
      user_id: interaction.user.id
    }

    # If a parent_event was provided, use its correlation_id to maintain the chain
    metadata = if Map.has_key?(params, :parent_event) do
      parent_event = params.parent_event
      correlation_id = parent_event.metadata.correlation_id
      # Use parent's correlation_id if available
      if correlation_id do
        Map.put(metadata, :correlation_id, correlation_id) |> Map.put(:causation_id, correlation_id)
      else
        Map.put(metadata, :causation_id, metadata.correlation_id)
      end
    else
      Map.put(metadata, :causation_id, metadata.correlation_id)
    end

    # Create team created event
    {:ok, event} = GameBot.Domain.Events.TeamEvents.TeamCreated.new(
      UUID.uuid4(),  # team_id
      params.name,
      params.players,
      interaction.guild_id,
      metadata
    )

    {:ok, event}
  end

  @doc """
  Handle guess command from an interaction.
  """
  def handle_guess(interaction, game_id, word, parent_metadata) do
    # Create metadata from interaction and parent
    # Ensure we preserve the correlation_id from parent metadata
    parent_correlation_id = Map.get(parent_metadata, :correlation_id) ||
                           Map.get(parent_metadata, "correlation_id")

    metadata = Map.merge(parent_metadata, %{
      timestamp: DateTime.utc_now(),
      source: :interaction,
      source_id: interaction.user.id,
      interaction_id: interaction.id,
      user_id: interaction.user.id
    })

    # Preserve correlation chain - keep same correlation_id and set causation_id
    metadata = metadata
      |> Map.put(:correlation_id, parent_correlation_id)
      |> Map.put(:causation_id, parent_correlation_id)

    # Create guess processed event
    {:ok, event} = GameBot.Domain.Events.GameEvents.GuessProcessed.new(
      game_id,
      interaction.user.id,
      word,
      metadata
    )

    {:ok, event}
  end
end
