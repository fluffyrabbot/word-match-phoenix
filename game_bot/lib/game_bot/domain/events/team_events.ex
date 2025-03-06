defmodule GameBot.Domain.Events.TeamEvents do
  @moduledoc """
  Defines team-related events in the domain.
  """

  alias GameBot.Domain.Events.GameEvents

  defmodule TeamCreated do
    @derive Jason.Encoder
    defstruct [:team_id, :name, :player_ids, :created_at, :metadata, :guild_id]

    def event_type, do: "team.created"

    def validate(%__MODULE__{} = event) do
      cond do
        is_nil(event.team_id) -> {:error, "team_id is required"}
        is_nil(event.name) -> {:error, "name is required"}
        is_nil(event.player_ids) -> {:error, "player_ids is required"}
        is_nil(event.guild_id) -> {:error, "guild_id is required"}
        is_nil(event.metadata) -> {:error, "metadata is required"}
        is_nil(event.metadata["guild_id"]) -> {:error, "guild_id is required in metadata"}
        length(event.player_ids) != 2 -> {:error, "team must have exactly 2 players"}
        true -> :ok
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "team_id" => event.team_id,
        "name" => event.name,
        "player_ids" => event.player_ids,
        "created_at" => DateTime.to_iso8601(event.created_at),
        "metadata" => event.metadata || %{},
        "guild_id" => event.guild_id
      }
    end

    def from_map(data) do
      %__MODULE__{
        team_id: data["team_id"],
        name: data["name"],
        player_ids: data["player_ids"],
        created_at: GameEvents.parse_timestamp(data["created_at"]),
        metadata: data["metadata"] || %{},
        guild_id: data["guild_id"]
      }
    end
  end

  defmodule TeamUpdated do
    @derive Jason.Encoder
    defstruct [:team_id, :name, :updated_at, :metadata]

    def event_type, do: "team.updated"

    def validate(%__MODULE__{} = event) do
      cond do
        is_nil(event.team_id) -> {:error, "team_id is required"}
        is_nil(event.name) -> {:error, "name is required"}
        is_nil(event.metadata) -> {:error, "metadata is required"}
        is_nil(event.metadata["guild_id"]) -> {:error, "guild_id is required in metadata"}
        true -> :ok
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "team_id" => event.team_id,
        "name" => event.name,
        "updated_at" => DateTime.to_iso8601(event.updated_at),
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        team_id: data["team_id"],
        name: data["name"],
        updated_at: GameEvents.parse_timestamp(data["updated_at"]),
        metadata: data["metadata"] || %{}
      }
    end
  end

  defmodule TeamMemberAdded do
    @derive Jason.Encoder
    defstruct [:team_id, :player_id, :added_at, :added_by]

    def event_type, do: "team.member_added"
  end

  defmodule TeamMemberRemoved do
    @derive Jason.Encoder
    defstruct [:team_id, :player_id, :removed_at, :removed_by, :reason]

    def event_type, do: "team.member_removed"
  end

  defmodule TeamInvitationCreated do
    @derive Jason.Encoder
    defstruct [:invitation_id, :inviter_id, :invitee_id, :proposed_name,
               :created_at, :expires_at, :guild_id]

    def event_type, do: "team.invitation_created"

    def validate(%__MODULE__{} = event) do
      cond do
        is_nil(event.invitation_id) -> {:error, "invitation_id is required"}
        is_nil(event.inviter_id) -> {:error, "inviter_id is required"}
        is_nil(event.invitee_id) -> {:error, "invitee_id is required"}
        is_nil(event.guild_id) -> {:error, "guild_id is required"}
        true -> :ok
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "invitation_id" => event.invitation_id,
        "inviter_id" => event.inviter_id,
        "invitee_id" => event.invitee_id,
        "proposed_name" => event.proposed_name,
        "created_at" => DateTime.to_iso8601(event.created_at),
        "expires_at" => DateTime.to_iso8601(event.expires_at),
        "guild_id" => event.guild_id
      }
    end

    def from_map(data) do
      %__MODULE__{
        invitation_id: data["invitation_id"],
        inviter_id: data["inviter_id"],
        invitee_id: data["invitee_id"],
        proposed_name: data["proposed_name"],
        created_at: GameEvents.parse_timestamp(data["created_at"]),
        expires_at: GameEvents.parse_timestamp(data["expires_at"]),
        guild_id: data["guild_id"]
      }
    end
  end

  defmodule TeamInvitationAccepted do
    @derive Jason.Encoder
    defstruct [:invitation_id, :team_id, :accepted_at]

    def event_type, do: "team.invitation_accepted"
  end

  defmodule TeamInvitationDeclined do
    @derive Jason.Encoder
    defstruct [:invitation_id, :declined_at, :reason]

    def event_type, do: "team.invitation_declined"
  end
end
