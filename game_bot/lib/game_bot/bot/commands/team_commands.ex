defmodule GameBot.Bot.Commands.TeamCommands do
  @moduledoc """
  Handles team-related commands from Discord.
  """

  alias Nostrum.Struct.{Interaction, User}
  alias GameBot.Domain.Commands.TeamCommands
  alias GameBot.Domain.Commands.TeamCommands.{CreateTeam, CreateTeamInvitation, AcceptInvitation, RenameTeam}
  alias GameBot.Domain.Projections.TeamProjection
  alias GameBot.Domain.Events.Metadata

  @doc """
  Main command handler for team-related commands.

  ## Parameters
    * `interaction` - The Discord interaction struct

  ## Returns
    * `{:ok, response}` - Successfully processed command with response data
    * `{:error, reason}` - Failed to process command
  """
  @spec handle_command(Interaction.t()) :: {:ok, map()} | {:error, any()}
  def handle_command(%Interaction{data: %{name: "team"}} = interaction) do
    options = interaction.data.options

    case options do
      [%{name: "create", options: create_opts}] ->
        handle_team_create(interaction, extract_create_options(create_opts))

      [%{name: "update", options: [%{name: "id", value: team_id}, %{name: "name", value: new_name}]}] ->
        handle_team_update(interaction, team_id, new_name)

      _ ->
        {:error, :invalid_command}
    end
  end

  def handle_command(_command) do
    {:error, :unknown_command}
  end

  # Extract create options from interaction data
  defp extract_create_options(options) do
    name = Enum.find_value(options, fn
      %{name: "name", value: value} -> value
      _ -> nil
    end)

    players = Enum.find_value(options, fn
      %{name: "players", value: value} -> value
      _ -> nil
    end)

    %{
      name: name,
      players: players
    }
  end

  defmodule CreateTeam do
    @moduledoc "Command to create a new team"

    @type t :: %__MODULE__{
      team_id: String.t(),
      name: String.t(),
      player_ids: [String.t()],
      guild_id: String.t()
    }
    defstruct [:team_id, :name, :player_ids, :guild_id]

    def validate(%__MODULE__{} = command) do
      cond do
        is_nil(command.team_id) -> {:error, :missing_team_id}
        is_nil(command.name) -> {:error, :missing_name}
        is_nil(command.player_ids) -> {:error, :missing_player_ids}
        length(command.player_ids) != 2 -> {:error, :invalid_player_count}
        String.length(command.name) < 3 -> {:error, :name_too_short}
        String.length(command.name) > 32 -> {:error, :name_too_long}
        !Regex.match?(~r/^[a-zA-Z0-9\s-]+$/, command.name) -> {:error, :invalid_name_format}
        true -> :ok
      end
    end
  end

  defmodule UpdateTeam do
    @moduledoc "Command to update a team's details"

    @type t :: %__MODULE__{
      team_id: String.t(),
      name: String.t(),
      guild_id: String.t()
    }
    defstruct [:team_id, :name, :guild_id]

    def validate(%__MODULE__{} = command) do
      cond do
        is_nil(command.team_id) -> {:error, :missing_team_id}
        is_nil(command.name) -> {:error, :missing_name}
        String.length(command.name) < 3 -> {:error, :name_too_short}
        String.length(command.name) > 32 -> {:error, :name_too_long}
        !Regex.match?(~r/^[a-zA-Z0-9\s-]+$/, command.name) -> {:error, :invalid_name_format}
        true -> :ok
      end
    end
  end

  @doc """
  Handles team creation command.
  """
  @spec handle_team_create(Interaction.t(), map()) :: {:ok, map()} | {:error, any()}
  def handle_team_create(%Interaction{} = interaction, %{name: name, players: players}) do
    metadata = Metadata.from_discord_interaction(interaction)

    # Generate team ID and validate players
    with {:ok, team_id} <- generate_team_id(),
         {:ok, player_ids} <- validate_players(players),
         # Create the command
         command = %TeamCommands.CreateTeam{
           team_id: team_id,
           name: name,
           player_ids: player_ids,
           guild_id: metadata.guild_id
         },
         # Validate and execute
         :ok <- TeamCommands.CreateTeam.validate(command),
         {:ok, team} <- TeamProjection.create_team(command) do

      {:ok, format_team_created(team)}
    else
      {:error, reason} -> {:ok, format_error_response(reason)}
    end
  end

  @doc """
  Handles team update command.
  """
  @spec handle_team_update(Interaction.t(), String.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def handle_team_update(%Interaction{} = interaction, team_id, new_name) do
    metadata = Metadata.from_discord_interaction(interaction)

    # Create and validate the command
    command = %TeamCommands.UpdateTeam{
      team_id: team_id,
      name: new_name,
      guild_id: metadata.guild_id
    }

    case TeamCommands.UpdateTeam.validate(command) do
      :ok ->
        try do
          case TeamProjection.update_team(command) do
            {:ok, team} -> {:ok, format_team_updated(team)}

            # General error handling - TeamProjection.update_team only returns success values
            # but we add this for future-proofing
            unexpected ->
              IO.warn("Unexpected result from TeamProjection.update_team: #{inspect(unexpected)}")
              {:ok, format_error_response("Internal error occurred")}
          end
        rescue
          e ->
            IO.warn("Error in team update: #{inspect(e)}")
            {:ok, format_error_response("Internal error occurred")}
        end
      {:error, reason} ->
        {:ok, format_error_response(reason)}
    end
  end

  # Private helpers

  defp generate_team_id do
    id = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    {:ok, "team_" <> id}
  end

  defp validate_players(players) do
    # Extract player IDs from Discord mentions/users
    player_ids = Enum.map(players, & &1.id)
    {:ok, player_ids}
  end

  defp format_team_created(team) do
    %{
      content: "Team created successfully! 🎉",
      embeds: [
        %{
          title: "✨ New Team",
          color: 0x7289DA, # Discord blurple
          fields: [
            %{
              name: "Name",
              value: team.name,
              inline: true
            },
            %{
              name: "ID",
              value: team.team_id,
              inline: true
            },
            %{
              name: "Players",
              value: format_player_list(team.player_ids),
              inline: false
            }
          ]
        }
      ]
    }
  end

  defp format_team_updated(team) do
    %{
      content: "Team updated successfully! 🔄",
      embeds: [
        %{
          title: "✏️ Team Updated",
          color: 0x43B581, # Discord green
          fields: [
            %{
              name: "New Name",
              value: team.name,
              inline: true
            },
            %{
              name: "ID",
              value: team.team_id,
              inline: true
            }
          ]
        }
      ]
    }
  end

  defp format_error_response(reason) do
    %{
      content: format_error(reason),
      flags: 64 # Ephemeral flag - only visible to command user
    }
  end

  defp format_player_list(player_ids) do
    player_ids
    |> Enum.map(&"<@#{&1}>")
    |> Enum.join(" and ")
  end

  defp format_error(:missing_guild_id), do: "❌ This command can only be used in a server."
  defp format_error(:missing_team_id), do: "❌ Team ID is required."
  defp format_error(:missing_name), do: "❌ Team name is required."
  defp format_error(:missing_player_ids), do: "❌ Players are required."
  defp format_error(:invalid_player_count), do: "❌ Team must have exactly 2 players."
  defp format_error(:name_too_short), do: "❌ Team name must be at least 3 characters."
  defp format_error(:name_too_long), do: "❌ Team name must be at most 32 characters."
  defp format_error(:invalid_name_format), do: "❌ Team name can only contain letters, numbers, spaces, hyphens, and emoji. It must include at least one letter or number."
  defp format_error(_), do: "❌ An error occurred while processing your request."
end
