defmodule GameBot.Domain.Commands.TeamCommands do
  @moduledoc """
  Defines team-related command structures and validation.
  """

  defmodule CreateTeam do
    @moduledoc "Command to create a new team"

    @enforce_keys [:team_id, :name, :player_ids, :guild_id]
    defstruct [:team_id, :name, :player_ids, :guild_id]

    @type t :: %__MODULE__{
      team_id: String.t(),
      name: String.t(),
      player_ids: [String.t()],
      guild_id: String.t()
    }

    # Regex for validating team names - allows letters, numbers, spaces, hyphens, and emoji (using a broader pattern)
    # This more lenient regex allows any character except control characters
    @team_name_regex ~r/^[^\p{C}]+$/u

    def validate(%__MODULE__{} = command) do
      cond do
        is_nil(command.guild_id) -> {:error, :missing_guild_id}
        is_nil(command.team_id) -> {:error, :missing_team_id}
        is_nil(command.name) -> {:error, :missing_name}
        is_nil(command.player_ids) -> {:error, :missing_player_ids}
        length(command.player_ids) != 2 -> {:error, :invalid_player_count}
        String.length(command.name) < 3 -> {:error, :name_too_short}
        String.length(command.name) > 32 -> {:error, :name_too_long}
        !validate_team_name(command.name) -> {:error, :invalid_name_format}
        true -> :ok
      end
    end

    # Helper function to validate team names with emoji support
    defp validate_team_name(name) do
      # Check if the name matches our regex pattern
      Regex.match?(@team_name_regex, name) &&
      # Ensure the name isn't just emoji/spaces
      String.match?(name, ~r/[\p{L}\p{N}]/u)
    end
  end

  defmodule UpdateTeam do
    @moduledoc "Command to update a team's details"

    @enforce_keys [:team_id, :name, :guild_id]
    defstruct [:team_id, :name, :guild_id]

    @type t :: %__MODULE__{
      team_id: String.t(),
      name: String.t(),
      guild_id: String.t()
    }

    # Share the same regex pattern for consistency
    # This more lenient regex allows any character except control characters
    @team_name_regex ~r/^[^\p{C}]+$/u

    def validate(%__MODULE__{} = command) do
      cond do
        is_nil(command.guild_id) -> {:error, :missing_guild_id}
        is_nil(command.team_id) -> {:error, :missing_team_id}
        is_nil(command.name) -> {:error, :missing_name}
        String.length(command.name) < 3 -> {:error, :name_too_short}
        String.length(command.name) > 32 -> {:error, :name_too_long}
        !validate_team_name(command.name) -> {:error, :invalid_name_format}
        true -> :ok
      end
    end

    # Helper function to validate team names with emoji support
    defp validate_team_name(name) do
      # Check if the name matches our regex pattern
      Regex.match?(@team_name_regex, name) &&
      # Ensure the name isn't just emoji/spaces
      String.match?(name, ~r/[\p{L}\p{N}]/u)
    end
  end

  defmodule CreateTeamInvitation do
    @moduledoc "Command to create a team invitation"

    @enforce_keys [:inviter_id, :invitee_id, :guild_id]
    defstruct [:inviter_id, :invitee_id, :name, :guild_id]

    @type t :: %__MODULE__{
      inviter_id: String.t(),
      invitee_id: String.t(),
      name: String.t() | nil,
      guild_id: String.t()
    }

    def validate(%__MODULE__{} = command) do
      cond do
        is_nil(command.guild_id) -> {:error, :missing_guild_id}
        is_nil(command.inviter_id) -> {:error, :missing_inviter}
        is_nil(command.invitee_id) -> {:error, :missing_invitee}
        command.inviter_id == command.invitee_id -> {:error, :self_invitation}
        true -> :ok
      end
    end
  end

  defmodule AcceptInvitation do
    @moduledoc "Command to accept a team invitation"

    @enforce_keys [:invitee_id, :guild_id]
    defstruct [:invitee_id, :guild_id]

    @type t :: %__MODULE__{
      invitee_id: String.t(),
      guild_id: String.t()
    }

    def validate(%__MODULE__{} = command) do
      cond do
        is_nil(command.guild_id) -> {:error, :missing_guild_id}
        is_nil(command.invitee_id) -> {:error, :missing_invitee}
        true -> :ok
      end
    end
  end

  defmodule RenameTeam do
    @moduledoc "Command to rename a team"

    @enforce_keys [:team_id, :requester_id, :new_name, :guild_id]
    defstruct [:team_id, :requester_id, :new_name, :guild_id]

    @type t :: %__MODULE__{
      team_id: String.t(),
      requester_id: String.t(),
      new_name: String.t(),
      guild_id: String.t()
    }

    # Share the same regex pattern for consistency
    # This more lenient regex allows any character except control characters
    @team_name_regex ~r/^[^\p{C}]+$/u

    def validate(%__MODULE__{} = command) do
      cond do
        is_nil(command.guild_id) -> {:error, :missing_guild_id}
        is_nil(command.team_id) -> {:error, :missing_team_id}
        is_nil(command.requester_id) -> {:error, :missing_requester}
        is_nil(command.new_name) or String.trim(command.new_name) == "" -> {:error, :empty_name}
        String.length(command.new_name) > 50 -> {:error, :name_too_long}
        !validate_team_name(command.new_name) -> {:error, :invalid_name_format}
        true -> :ok
      end
    end

    # Helper function to validate team names with emoji support
    defp validate_team_name(name) do
      # Check if the name matches our regex pattern
      Regex.match?(@team_name_regex, name) &&
      # Ensure the name isn't just emoji/spaces
      String.match?(name, ~r/[\p{L}\p{N}]/u)
    end
  end
end
