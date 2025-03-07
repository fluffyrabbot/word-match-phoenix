defmodule GameBot.Bot.Commands.ReplayCommands do
  @moduledoc """
  Handles Discord commands related to game replays, match history,
  and game summaries.
  Supports message commands with the following format:

  - `wmreplay [game_id]` - View full game replay
  - `wmreplay history` - View match history
  - `wmreplay summary [game_id]` - View game summary
  """

  alias GameBot.Domain.Commands.ReplayCommands
  alias GameBot.Domain.Events.Metadata
  alias Nostrum.Struct.{Message, Interaction}

  @command_prefix "wmreplay"

  @doc """
  Handles replay-related message commands.

  Returns:
  * `{:ok, response}` - Successfully processed command
  * `{:error, reason}` - Failed to process command
  """
  @spec handle_command(Message.t()) :: {:ok, map()} | {:error, any()}
  def handle_command(%Message{content: @command_prefix <> rest} = message) do
    args = rest |> String.trim() |> String.split(" ", trim: true)

    case args do
      [game_id] when byte_size(game_id) > 0 ->
        handle_game_replay(message, game_id)

      ["history"] ->
        handle_match_history(message)

      ["summary", game_id] when byte_size(game_id) > 0 ->
        handle_game_summary(message, game_id)

      _ ->
        {:error, :invalid_command}
    end
  end

  def handle_command(_), do: {:error, :unknown_command}

  @spec handle_game_replay(Message.t(), String.t()) :: {:ok, map()} | {:error, any()}
  defp handle_game_replay(message, game_id) do
    metadata = Metadata.from_discord_message(message)
    guild_id = Map.get(metadata, :guild_id)

    command = %ReplayCommands.FetchGameReplay{
      game_id: game_id,
      guild_id: guild_id
    }

    case ReplayCommands.FetchGameReplay.execute(command) do
      {:ok, events} ->
        case ReplayCommands.validate_replay_access(message.author.id, events) do
          :ok ->
            {:ok, format_game_replay(events)}
          error ->
            error
        end

      {:error, _reason} = error ->
        error
    end
  end

  @spec handle_match_history(Message.t()) :: {:ok, map()} | {:error, any()}
  defp handle_match_history(message) do
    metadata = Metadata.from_discord_message(message)
    guild_id = Map.get(metadata, :guild_id)

    command = %ReplayCommands.FetchMatchHistory{
      guild_id: guild_id,
      options: %{}
    }

    case ReplayCommands.FetchMatchHistory.execute(command) do
      {:ok, matches} ->
        {:ok, format_match_history(matches)}

      {:error, _reason} = error ->
        error
    end
  end

  @spec handle_game_summary(Message.t(), String.t()) :: {:ok, map()} | {:error, any()}
  defp handle_game_summary(message, game_id) do
    metadata = Metadata.from_discord_message(message)
    guild_id = Map.get(metadata, :guild_id)

    command = %ReplayCommands.FetchGameSummary{
      game_id: game_id,
      guild_id: guild_id
    }

    case ReplayCommands.FetchGameSummary.execute(command) do
      {:ok, summary} ->
        {:ok, format_game_summary(summary)}

      {:error, _reason} = error ->
        error
    end
  end

  # Private helpers
  defp format_game_replay(events) do
    # Format replay events for Discord display
    %{
      content: "Game Replay",
      embeds: [
        %{
          title: "Game Events",
          description: "Here's what happened in the game:",
          fields: Enum.map(events, fn event ->
            %{
              name: format_event_name(event),
              value: format_event_details(event),
              inline: false
            }
          end)
        }
      ]
    }
  end

  defp format_match_history(matches) do
    # Format match history for Discord display
    %{
      content: "Match History",
      embeds: [
        %{
          title: "Recent Matches",
          description: if(Enum.empty?(matches), do: "No matches found", else: nil),
          fields: Enum.map(matches, fn match ->
            %{
              name: "Game #{match.game_id}",
              value: "Mode: #{match.mode}\nWinner: #{match.winner || "In Progress"}",
              inline: true
            }
          end)
        }
      ]
    }
  end

  defp format_game_summary(summary) do
    # Format game summary for Discord display
    %{
      content: "Game Summary",
      embeds: [
        %{
          title: "Game #{summary.game_id}",
          fields: [
            %{
              name: "Mode",
              value: summary.mode,
              inline: true
            },
            %{
              name: "Teams",
              value: format_teams(summary.teams),
              inline: true
            },
            %{
              name: "Winner",
              value: summary.winner || "In Progress",
              inline: true
            }
          ]
        }
      ]
    }
  end

  defp format_event_name(%{__struct__: module}) do
    module
    |> Module.split()
    |> List.last()
    |> String.replace(~r/([A-Z])/, " \\1")
    |> String.trim()
  end

  defp format_event_details(event) do
    # Format event details based on event type
    case event do
      %{timestamp: timestamp} = e ->
        time_str = Calendar.strftime(timestamp, "%H:%M:%S")
        details = get_event_details(e)
        "#{time_str} - #{details}"
      _ ->
        "Event details not available"
    end
  end

  defp get_event_details(event) do
    case event do
      %{player1_word: word1, player2_word: word2} when not is_nil(word1) and not is_nil(word2) ->
        "Words: #{word1} / #{word2}"
      %{winner: winner} when not is_nil(winner) ->
        "Winner: #{winner}"
      _ ->
        "No details available"
    end
  end

  defp format_teams([]), do: "No teams"
  defp format_teams(teams) do
    teams
    |> Enum.map(fn team -> team.name end)
    |> Enum.join("\n")
  end
end
