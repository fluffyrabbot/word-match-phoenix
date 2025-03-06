defmodule GameBot.Bot.Commands.GameCommands do
  @moduledoc """
  Handles game-related commands and generates appropriate game events.
  """

  alias GameBot.Domain.Events.{Metadata, GameEvents, TeamEvents}
  alias Nostrum.Struct.{Interaction, Message}

  @doc """
  Handles the /start command to begin a new game.
  """
  def handle_start_game(%Interaction{} = interaction, mode, options) do
    with {:ok, metadata} <- create_metadata(interaction),
         guild_id = interaction.guild_id || metadata.guild_id,
         # Validate we have a guild context
         {:ok, _} <- validate_guild_context(guild_id),
         {:ok, game_id} <- generate_game_id(),
         {:ok, teams} <- validate_teams(options.teams),
         {:ok, config} <- build_game_config(mode, options) do

      event = %GameEvents.GameStarted{
        game_id: game_id,
        guild_id: guild_id,  # Explicitly include guild_id
        mode: mode,
        round_number: 1,
        teams: teams.team_map,
        team_ids: teams.team_ids,
        player_ids: teams.player_ids,
        roles: teams.roles,
        config: config,
        timestamp: DateTime.utc_now(),
        metadata: metadata
      }

      {:ok, event}
    end
  end

  @doc """
  Handles the /team create command to create a new team.
  """
  def handle_team_create(%Interaction{} = interaction, %{name: name, players: players}) do
    with {:ok, metadata} <- create_metadata(interaction),
         {:ok, team_id} <- generate_team_id(),
         {:ok, player_ids} <- validate_players(players) do

      event = %TeamEvents.TeamCreated{
        team_id: team_id,
        name: name,
        player_ids: player_ids,
        created_at: DateTime.utc_now(),
        metadata: metadata
      }

      {:ok, event}
    end
  end

  @doc """
  Handles a guess submission in an active game.
  """
  def handle_guess(%Interaction{} = interaction, game_id, word, parent_metadata) do
    with {:ok, game} <- fetch_active_game(game_id),
         {:ok, metadata} <- create_metadata(interaction, parent_metadata, game.guild_id),
         {:ok, player_info} <- get_player_info(interaction.user.id, game) do

      event = %GameEvents.GuessProcessed{
        game_id: game_id,
        mode: game.mode,
        round_number: game.current_round,
        team_id: player_info.team_id,
        player1_info: player_info,
        player2_info: get_partner_info(player_info, game),
        player1_word: word,
        player2_word: nil,
        guess_successful: false,
        guess_count: game.guess_count + 1,
        match_score: 0,
        timestamp: DateTime.utc_now(),
        metadata: metadata
      }

      {:ok, event}
    end
  end

  # Private helpers

  defp create_metadata(message_or_interaction, parent_metadata \\ nil)
  defp create_metadata(message_or_interaction, parent_metadata, game_guild_id)

  defp create_metadata(%Message{} = message, parent_metadata) do
    metadata = if parent_metadata do
      Metadata.from_parent_event(parent_metadata, correlation_id: parent_metadata.correlation_id)
    else
      Metadata.from_discord_message(message)
    end
    {:ok, metadata}
  end

  defp create_metadata(%Interaction{} = interaction, parent_metadata) do
    metadata = if parent_metadata do
      Metadata.from_parent_event(parent_metadata, correlation_id: parent_metadata.correlation_id)
    else
      Metadata.from_discord_interaction(interaction)
    end
    {:ok, metadata}
  end

  defp create_metadata(%Interaction{} = interaction, parent_metadata, game_guild_id) do
    metadata = if parent_metadata do
      Metadata.from_parent_event(parent_metadata, correlation_id: parent_metadata.correlation_id)
    else
      Metadata.from_discord_interaction(interaction, guild_id: game_guild_id)
    end
    {:ok, metadata}
  end

  defp generate_game_id do
    id = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    {:ok, "game_" <> id}
  end

  defp generate_team_id do
    id = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    {:ok, "team_" <> id}
  end

  defp validate_teams(teams) do
    # Placeholder for team validation logic
    # Should verify team structure, player counts, etc.
    {:ok, teams}
  end

  defp validate_players(players) do
    # Placeholder for player validation logic
    # Should verify player existence, permissions, etc.
    {:ok, players}
  end

  defp build_game_config(mode, options) do
    # Placeholder for building mode-specific configuration
    {:ok, %{
      mode: mode,
      settings: options
    }}
  end

  defp fetch_active_game(game_id) do
    # Placeholder for game state retrieval
    {:ok, %{
      mode: :classic,
      current_round: 1,
      guess_count: 0
    }}
  end

  defp get_player_info(user_id, game) do
    # Placeholder for getting player's role and team info
    {:ok, %{
      player_id: user_id,
      team_id: "team_1",
      role: :giver
    }}
  end

  defp get_partner_info(player_info, game) do
    # Placeholder for getting partner's info
    %{
      player_id: "partner_id",
      team_id: player_info.team_id,
      role: :guesser
    }
  end

  # Add validation function for guild context
  defp validate_guild_context(nil), do: {:error, :missing_guild_id}
  defp validate_guild_context(_guild_id), do: {:ok, true}
end
