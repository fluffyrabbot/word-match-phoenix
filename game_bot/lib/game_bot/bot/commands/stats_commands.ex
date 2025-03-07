defmodule GameBot.Bot.Commands.StatsCommands do
  @moduledoc """
  Handles Discord commands related to game statistics, leaderboards,
  and player/team performance metrics.
  """

  alias GameBot.Domain.Commands.StatsCommands
  alias GameBot.Domain.Events.Metadata
  alias Nostrum.Struct.Interaction

  @doc """
  Main command handler for stats-related commands.

  ## Parameters
    * `command` - Map containing command details including:
      - `:type` - Command type (e.g., :interaction)
      - `:name` - Command name (e.g., "stats")
      - `:options` - Command options map
      - `:interaction` - Discord interaction struct if type is :interaction

  ## Returns
    * `{:ok, response}` - Successfully processed command with response data
    * `{:error, reason}` - Failed to process command
  """
  @spec handle_command(Interaction.t()) :: {:ok, map()} | {:error, any()}
  def handle_command(%Interaction{data: %{name: "stats"}} = interaction) do
    case interaction.data.options do
      [%{name: "player", value: player_id}] ->
        handle_player_stats(interaction, player_id)

      [%{name: "team", value: team_id}] ->
        handle_team_stats(interaction, team_id)

      [%{name: "leaderboard", options: [%{name: "type", value: type}]}] ->
        handle_leaderboard(interaction, type, [])

      _ ->
        {:error, :invalid_command}
    end
  end

  def handle_command(_command) do
    {:error, :unknown_command}
  end

  @doc """
  Handles stats commands from messages.
  Processes commands like "!stats player 123456789" or "!stats leaderboard".

  ## Parameters
    * `command_text` - The text of the command after the prefix
    * `message` - The Discord message containing the command

  ## Returns
    * `{:ok, response}` - Successfully processed command with response data
    * `{:error, reason}` - Failed to process command
  """
  @spec handle_command(String.t(), Nostrum.Struct.Message.t()) :: {:ok, map()} | {:error, any()}
  def handle_command(command_text, %Nostrum.Struct.Message{} = message) do
    parts = String.trim(command_text) |> String.split(" ", trim: true)

    case parts do
      ["player", player_id] ->
        handle_player_stats_message(message, player_id)

      ["team", team_id] ->
        handle_team_stats_message(message, team_id)

      ["leaderboard" | opts] ->
        type = List.first(opts) || "score"
        handle_leaderboard_message(message, type, %{})

      _ ->
        {:error, :invalid_command}
    end
  end

  @doc """
  Handles player statistics command.
  """
  @spec handle_player_stats(Interaction.t(), String.t()) :: {:ok, map()} | {:error, any()}
  defp handle_player_stats(interaction, player_id) do
    guild_id = interaction.guild_id
    metadata = create_metadata(interaction)

    case StatsCommands.FetchPlayerStats.execute(%{player_id: player_id, guild_id: guild_id}) do
      {:ok, stats} ->
        {:ok, format_player_stats(stats)}

      {:error, reason} = error ->
        error
    end
  end

  @doc """
  Handles team statistics command.
  """
  @spec handle_team_stats(Interaction.t(), String.t()) :: {:ok, map()} | {:error, any()}
  defp handle_team_stats(interaction, team_id) do
    metadata = Metadata.from_discord_interaction(interaction)
    guild_id = Map.get(metadata, :guild_id)

    case StatsCommands.FetchTeamStats.execute(%{team_id: team_id, guild_id: guild_id}) do
      {:ok, stats} ->
        {:ok, format_team_stats(stats)}

      {:error, reason} = error ->
        error
    end
  end

  @doc """
  Handles leaderboard command.
  """
  @spec handle_leaderboard(Interaction.t(), String.t(), map()) :: {:ok, map()} | {:error, any()}
  defp handle_leaderboard(interaction, type, options) do
    metadata = Metadata.from_discord_interaction(interaction)
    guild_id = Map.get(metadata, :guild_id)

    case StatsCommands.FetchLeaderboard.execute(%{type: type, guild_id: guild_id, options: options}) do
      {:ok, entries} ->
        {:ok, format_leaderboard(type, entries)}

      {:error, reason} = error ->
        error
    end
  end

  # Message-based command handlers

  defp handle_player_stats_message(message, player_id) do
    guild_id = message.guild_id
    metadata = Metadata.from_discord_message(message)

    case StatsCommands.FetchPlayerStats.execute(%{player_id: player_id, guild_id: guild_id}) do
      {:ok, stats} ->
        {:ok, format_player_stats(stats)}

      {:error, reason} = error ->
        error
    end
  end

  defp handle_team_stats_message(message, team_id) do
    metadata = Metadata.from_discord_message(message)
    guild_id = Map.get(metadata, :guild_id)

    case StatsCommands.FetchTeamStats.execute(%{team_id: team_id, guild_id: guild_id}) do
      {:ok, stats} ->
        {:ok, format_team_stats(stats)}

      {:error, reason} = error ->
        error
    end
  end

  defp handle_leaderboard_message(message, type, options) do
    metadata = Metadata.from_discord_message(message)
    guild_id = Map.get(metadata, :guild_id)

    case StatsCommands.FetchLeaderboard.execute(%{type: type, guild_id: guild_id, options: options}) do
      {:ok, entries} ->
        {:ok, format_leaderboard(type, entries)}

      {:error, reason} = error ->
        error
    end
  end

  # Private helpers
  defp create_metadata(%Interaction{} = interaction) do
    Metadata.from_discord_interaction(interaction)
  end

  defp format_player_stats(stats) do
    # Placeholder for formatting player stats for Discord display
    %{
      content: "Player Stats",
      embeds: [
        %{
          title: "Player Statistics",
          fields: [
            %{
              name: "Games Played",
              value: stats.games_played,
              inline: true
            },
            %{
              name: "Wins",
              value: stats.wins,
              inline: true
            },
            %{
              name: "Average Score",
              value: stats.average_score,
              inline: true
            }
          ]
        }
      ]
    }
  end

  defp format_team_stats(stats) do
    # Placeholder for formatting team stats for Discord display
    %{
      content: "Team Stats",
      embeds: [
        %{
          title: "Team Statistics",
          fields: [
            %{
              name: "Games Played",
              value: stats.games_played,
              inline: true
            },
            %{
              name: "Wins",
              value: stats.wins,
              inline: true
            },
            %{
              name: "Average Score",
              value: stats.average_score,
              inline: true
            }
          ]
        }
      ]
    }
  end

  defp format_leaderboard(type, entries) do
    # Placeholder for formatting leaderboard for Discord display
    description = if Enum.empty?(entries), do: "No entries found", else: nil

    %{
      content: "Leaderboard",
      embeds: [
        %{
          title: String.capitalize(type) <> " Leaderboard",
          description: description,
          fields: Enum.map(entries, fn entry ->
            %{
              name: entry.name,
              value: "Score: #{entry.score}",
              inline: true
            }
          end)
        }
      ]
    }
  end
end
