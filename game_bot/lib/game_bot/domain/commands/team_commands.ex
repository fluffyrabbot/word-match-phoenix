defmodule GameBot.Domain.Commands.TeamCommandStructs do
  @moduledoc """
  Defines team-related command structures.
  """

  defmodule CreateTeamInvitation do
    @enforce_keys [:inviter_id, :invitee_id]
    defstruct [:inviter_id, :invitee_id, :name, :guild_id]

    @typedoc "Command to create a team invitation"
    @type t :: %__MODULE__{
      inviter_id: String.t(),
      invitee_id: String.t(),
      name: String.t() | nil,
      guild_id: String.t()
    }

    @spec validate(t()) :: :ok | {:error, atom()}
    def validate(%__MODULE__{inviter_id: inviter_id, invitee_id: invitee_id, guild_id: guild_id}) do
      cond do
        is_nil(guild_id) ->
          {:error, :missing_guild_id}

        inviter_id == invitee_id ->
          {:error, :self_invitation}

        # Add other validation rules as needed
        true ->
          :ok
      end
    end
  end

  defmodule AcceptInvitation do
    @enforce_keys [:invitee_id]
    defstruct [:invitee_id, :guild_id]

    @typedoc "Command to accept a team invitation"
    @type t :: %__MODULE__{
      invitee_id: String.t(),
      guild_id: String.t()
    }
  end

  defmodule RenameTeam do
    @enforce_keys [:team_id, :requester_id, :new_name]
    defstruct [:team_id, :requester_id, :new_name, :guild_id]

    @typedoc "Command to rename a team"
    @type t :: %__MODULE__{
      team_id: String.t(),
      requester_id: String.t(),
      new_name: String.t(),
      guild_id: String.t()
    }

    @spec validate(t()) :: :ok | {:error, atom()}
    def validate(%__MODULE__{new_name: new_name, guild_id: guild_id}) do
      cond do
        is_nil(guild_id) ->
          {:error, :missing_guild_id}

        is_nil(new_name) or String.trim(new_name) == "" ->
          {:error, :empty_name}

        String.length(new_name) > 50 ->
          {:error, :name_too_long}

        # Add other validation rules as needed
        true ->
          :ok
      end
    end
  end
end
