defmodule GameBot.Bot.CommandRegistry do
  @moduledoc """
  Routes Discord commands to their appropriate handlers.
  Provides a central registry for all bot commands.
  """

  alias GameBot.Bot.Commands.{
    GameCommands,
    TeamCommands,
    StatsCommands,
    ReplayCommands
  }

  alias Nostrum.Struct.Interaction

  @dm_allowed_commands ["guess"]

  @doc """
  Routes a Discord interaction to the appropriate command handler.
  Returns {:ok, response} on success, {:error, reason} on failure.
  """
  def handle_interaction(%Interaction{data: %{name: name}} = interaction) do
    cond do
      # Allow certain commands in DMs
      name in @dm_allowed_commands and is_nil(interaction.guild_id) ->
        handle_dm_command(name, interaction)

      # Require guild context for all other commands
      is_nil(interaction.guild_id) ->
        {:error, :guild_required}

      # Normal guild command handling
      true ->
        handle_guild_command(name, interaction)
    end
  end

  defp handle_dm_command(name, interaction) do
    case name do
      "guess" ->
        GameCommands.handle_guess(
          interaction,
          get_option(interaction, "game_id"),
          get_option(interaction, "word"),
          get_option(interaction, "metadata")
        )
      _ ->
        {:error, :unknown_command}
    end
  end

  defp handle_guild_command(name, interaction) do
    case name do
      # Game commands
      "start" ->
        GameCommands.handle_start_game(
          interaction,
          get_option(interaction, "mode"),
          parse_game_options(interaction)
        )

      # Team commands
      "team create" ->
        TeamCommands.handle_team_create(interaction, %{
          name: get_option(interaction, "name"),
          players: get_option(interaction, "players")
        })
      "team update" ->
        TeamCommands.handle_team_update(
          interaction,
          get_option(interaction, "team_id"),
          %{name: get_option(interaction, "name")}
        )

      # Stats commands
      "stats player" ->
        StatsCommands.handle_player_stats(
          interaction,
          get_option(interaction, "player_id")
        )
      "stats team" ->
        StatsCommands.handle_team_stats(
          interaction,
          get_option(interaction, "team_id")
        )
      "leaderboard" ->
        StatsCommands.handle_leaderboard(
          interaction,
          get_option(interaction, "type"),
          parse_leaderboard_options(interaction)
        )

      # Replay commands
      "replay" ->
        ReplayCommands.handle_view_replay(
          interaction,
          get_option(interaction, "game_id")
        )
      "history" ->
        ReplayCommands.handle_match_history(
          interaction,
          parse_history_options(interaction)
        )
      "summary" ->
        ReplayCommands.handle_game_summary(
          interaction,
          get_option(interaction, "game_id")
        )

      _ ->
        {:error, :unknown_command}
    end
  end

  # Private helpers

  defp get_option(interaction, name) do
    case Enum.find(interaction.data.options || [], &(&1.name == name)) do
      nil -> nil
      option -> option.value
    end
  end

  defp parse_game_options(interaction) do
    %{
      teams: parse_teams_option(get_option(interaction, "teams")),
      time_limit: get_option(interaction, "time_limit"),
      max_rounds: get_option(interaction, "max_rounds")
    }
  end

  defp parse_teams_option(teams) when is_list(teams) do
    # Convert raw teams data into proper structure
    %{
      team_map: teams |> Enum.into(%{}, &{&1.id, &1.players}),
      team_ids: Enum.map(teams, & &1.id),
      player_ids: teams |> Enum.flat_map(& &1.players),
      roles: teams |> Enum.flat_map(&assign_roles/1) |> Enum.into(%{})
    }
  end
  defp parse_teams_option(_), do: %{}

  defp assign_roles(team) do
    [giver | guessers] = team.players
    [{giver, :giver} | Enum.map(guessers, &{&1, :guesser})]
  end

  defp parse_leaderboard_options(interaction) do
    %{
      timeframe: get_option(interaction, "timeframe") || "all",
      limit: get_option(interaction, "limit") || 10
    }
  end

  defp parse_history_options(interaction) do
    %{
      player_id: get_option(interaction, "player_id"),
      team_id: get_option(interaction, "team_id"),
      limit: get_option(interaction, "limit") || 10
    }
  end
end
