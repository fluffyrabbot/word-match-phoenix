defmodule GameBot.Domain.Commands.TeamCommands do
  @moduledoc """
  Defines commands for team management.
  """

  defmodule CreateTeam do
    @moduledoc "Command to create a new team"

    @type t :: %__MODULE__{
      team_id: String.t(),
      name: String.t(),
      player_ids: [String.t()]
    }
    defstruct [:team_id, :name, :player_ids]

    def validate(%__MODULE__{} = command) do
      cond do
        is_nil(command.team_id) -> {:error, "team_id is required"}
        is_nil(command.name) -> {:error, "name is required"}
        is_nil(command.player_ids) -> {:error, "player_ids is required"}
        length(command.player_ids) != 2 -> {:error, "team must have exactly 2 players"}
        String.length(command.name) < 3 -> {:error, "name must be at least 3 characters"}
        String.length(command.name) > 32 -> {:error, "name must be at most 32 characters"}
        !Regex.match?(~r/^[a-zA-Z0-9\s-]+$/, command.name) -> {:error, "name contains invalid characters"}
        true -> :ok
      end
    end
  end

  defmodule UpdateTeam do
    @moduledoc "Command to update a team's details"

    @type t :: %__MODULE__{
      team_id: String.t(),
      name: String.t()
    }
    defstruct [:team_id, :name]

    def validate(%__MODULE__{} = command) do
      cond do
        is_nil(command.team_id) -> {:error, "team_id is required"}
        is_nil(command.name) -> {:error, "name is required"}
        String.length(command.name) < 3 -> {:error, "name must be at least 3 characters"}
        String.length(command.name) > 32 -> {:error, "name must be at most 32 characters"}
        !Regex.match?(~r/^[a-zA-Z0-9\s-]+$/, command.name) -> {:error, "name contains invalid characters"}
        true -> :ok
      end
    end
  end
end
