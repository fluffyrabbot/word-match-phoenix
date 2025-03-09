defmodule GameBot.Domain.Events.TeamEvents do
  @moduledoc """
  Defines team-related events in the domain.
  """

  alias GameBot.Domain.Events.GameEvents

  defmodule TeamCreated do
    @derive Jason.Encoder
    defstruct [:team_id, :name, :player_ids, :created_at, :metadata, :guild_id]

    def event_type, do: "team_created"

    def validate(%__MODULE__{} = event) do
      cond do
        is_nil(event.team_id) -> {:error, "team_id is required"}
        is_nil(event.name) -> {:error, "name is required"}
        is_nil(event.player_ids) -> {:error, "player_ids is required"}
        is_nil(event.guild_id) -> {:error, "guild_id is required"}
        is_nil(event.metadata) -> {:error, "metadata is required"}
        is_nil(Map.get(event.metadata, :guild_id)) && is_nil(Map.get(event.metadata, "guild_id")) -> {:error, "guild_id is required in metadata"}
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

    @doc """
    Creates a new TeamCreated event with the specified parameters.

    ## Parameters
      * `team_id` - Unique identifier for the team
      * `name` - Name of the team
      * `player_ids` - List of player IDs in the team
      * `guild_id` - Discord guild ID where the team is being created
      * `metadata` - Additional metadata for the event (optional)

    ## Returns
      * `{:ok, %TeamCreated{}}` - A new TeamCreated event struct with status

    ## Examples
        iex> TeamCreated.new(
        ...>   "team_123",
        ...>   "Awesome Team",
        ...>   ["player_1", "player_2"],
        ...>   "guild_456",
        ...>   %{"source" => "discord_command"}
        ...> )
    """
    @spec new(String.t(), String.t(), [String.t()], String.t(), map()) :: {:ok, %__MODULE__{}}
    def new(team_id, name, player_ids, guild_id, metadata \\ %{}) do
      now = DateTime.utc_now()

      # Ensure metadata is a map with atoms as keys
      metadata_map = if is_map(metadata) do
        metadata
      else
        %{}
      end

      # Ensure critical fields are present in metadata
      enhanced_metadata = metadata_map
        |> ensure_string_keys()
        |> Map.put(:guild_id, guild_id)
        |> Map.put("guild_id", guild_id) # Add both atom and string versions to be safe
        |> Map.put_new(:source_id, Map.get(metadata_map, :interaction_id) ||
                                  Map.get(metadata_map, "interaction_id") ||
                                  Map.get(metadata_map, :user_id) ||
                                  Map.get(metadata_map, "user_id") ||
                                  UUID.uuid4())
        |> Map.put_new(:correlation_id, Map.get(metadata_map, :correlation_id) ||
                                       Map.get(metadata_map, "correlation_id") ||
                                       UUID.uuid4())

      event = %__MODULE__{
        team_id: team_id,
        name: name,
        player_ids: player_ids,
        guild_id: guild_id,
        created_at: now,
        metadata: enhanced_metadata
      }

      # Validate the event before returning
      case validate(event) do
        :ok -> {:ok, event}
        {:error, reason} -> raise "Invalid TeamCreated event: #{reason}"
      end
    end

    # Helper to ensure string keys in metadata maps
    defp ensure_string_keys(metadata) do
      Enum.reduce(metadata, %{}, fn
        {key, value}, acc when is_binary(key) -> Map.put(acc, String.to_atom(key), value)
        {key, value}, acc when is_atom(key) -> Map.put(acc, key, value)
        _, acc -> acc
      end)
    rescue
      # If conversion fails, return original metadata
      _ -> metadata
    end
  end

  defmodule TeamUpdated do
    @derive Jason.Encoder
    defstruct [:team_id, :name, :updated_at, :metadata, :guild_id]

    def event_type, do: "team_updated"

    def validate(%__MODULE__{} = event) do
      cond do
        is_nil(event.team_id) -> {:error, "team_id is required"}
        is_nil(event.name) -> {:error, "name is required"}
        is_nil(event.guild_id) -> {:error, "guild_id is required"}
        is_nil(event.metadata) -> {:error, "metadata is required"}
        is_nil(event.metadata["guild_id"]) -> {:error, "guild_id is required in metadata"}
        true -> :ok
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "team_id" => event.team_id,
        "name" => event.name,
        "guild_id" => event.guild_id,
        "updated_at" => DateTime.to_iso8601(event.updated_at),
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        team_id: data["team_id"],
        name: data["name"],
        updated_at: GameEvents.parse_timestamp(data["updated_at"]),
        metadata: data["metadata"] || %{},
        guild_id: data["guild_id"]
      }
    end
  end

  defmodule TeamMemberAdded do
    @derive Jason.Encoder
    defstruct [:team_id, :player_id, :added_at, :added_by, :guild_id, :metadata]

    def event_type, do: "team_member_added"

    def validate(%__MODULE__{} = event) do
      cond do
        is_nil(event.team_id) -> {:error, "team_id is required"}
        is_nil(event.player_id) -> {:error, "player_id is required"}
        is_nil(event.added_by) -> {:error, "added_by is required"}
        is_nil(event.guild_id) -> {:error, "guild_id is required"}
        is_nil(event.metadata) -> {:error, "metadata is required"}
        true -> :ok
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "team_id" => event.team_id,
        "player_id" => event.player_id,
        "added_at" => DateTime.to_iso8601(event.added_at),
        "added_by" => event.added_by,
        "guild_id" => event.guild_id,
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        team_id: data["team_id"],
        player_id: data["player_id"],
        added_at: GameEvents.parse_timestamp(data["added_at"]),
        added_by: data["added_by"],
        guild_id: data["guild_id"],
        metadata: data["metadata"] || %{}
      }
    end
  end

  defmodule TeamMemberRemoved do
    @derive Jason.Encoder
    defstruct [:team_id, :player_id, :removed_at, :removed_by, :reason, :guild_id, :metadata]

    def event_type, do: "team_member_removed"

    def validate(%__MODULE__{} = event) do
      cond do
        is_nil(event.team_id) -> {:error, "team_id is required"}
        is_nil(event.player_id) -> {:error, "player_id is required"}
        is_nil(event.removed_by) -> {:error, "removed_by is required"}
        is_nil(event.guild_id) -> {:error, "guild_id is required"}
        is_nil(event.metadata) -> {:error, "metadata is required"}
        true -> :ok
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "team_id" => event.team_id,
        "player_id" => event.player_id,
        "removed_at" => DateTime.to_iso8601(event.removed_at),
        "removed_by" => event.removed_by,
        "reason" => event.reason,
        "guild_id" => event.guild_id,
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        team_id: data["team_id"],
        player_id: data["player_id"],
        removed_at: GameEvents.parse_timestamp(data["removed_at"]),
        removed_by: data["removed_by"],
        reason: data["reason"],
        guild_id: data["guild_id"],
        metadata: data["metadata"] || %{}
      }
    end
  end

  defmodule TeamInvitationCreated do
    @derive Jason.Encoder
    defstruct [:invitation_id, :inviter_id, :invitee_id, :proposed_name,
               :created_at, :expires_at, :guild_id, :metadata]

    def event_type, do: "team_invitation_created"

    def validate(%__MODULE__{} = event) do
      cond do
        is_nil(event.invitation_id) -> {:error, "invitation_id is required"}
        is_nil(event.inviter_id) -> {:error, "inviter_id is required"}
        is_nil(event.invitee_id) -> {:error, "invitee_id is required"}
        is_nil(event.guild_id) -> {:error, "guild_id is required"}
        is_nil(event.metadata) -> {:error, "metadata is required"}
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
        "guild_id" => event.guild_id,
        "metadata" => event.metadata || %{}
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
        guild_id: data["guild_id"],
        metadata: data["metadata"] || %{}
      }
    end
  end

  defmodule TeamInvitationAccepted do
    @derive Jason.Encoder
    defstruct [:invitation_id, :team_id, :accepted_at, :guild_id, :metadata]

    def event_type, do: "team_invitation_accepted"

    def validate(%__MODULE__{} = event) do
      cond do
        is_nil(event.invitation_id) -> {:error, "invitation_id is required"}
        is_nil(event.team_id) -> {:error, "team_id is required"}
        is_nil(event.guild_id) -> {:error, "guild_id is required"}
        is_nil(event.metadata) -> {:error, "metadata is required"}
        true -> :ok
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "invitation_id" => event.invitation_id,
        "team_id" => event.team_id,
        "accepted_at" => DateTime.to_iso8601(event.accepted_at),
        "guild_id" => event.guild_id,
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        invitation_id: data["invitation_id"],
        team_id: data["team_id"],
        accepted_at: GameEvents.parse_timestamp(data["accepted_at"]),
        guild_id: data["guild_id"],
        metadata: data["metadata"] || %{}
      }
    end
  end

  defmodule TeamInvitationDeclined do
    @derive Jason.Encoder
    defstruct [:invitation_id, :declined_at, :reason, :guild_id, :metadata]

    def event_type, do: "team_invitation_declined"

    def validate(%__MODULE__{} = event) do
      cond do
        is_nil(event.invitation_id) -> {:error, "invitation_id is required"}
        is_nil(event.guild_id) -> {:error, "guild_id is required"}
        is_nil(event.metadata) -> {:error, "metadata is required"}
        true -> :ok
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "invitation_id" => event.invitation_id,
        "declined_at" => DateTime.to_iso8601(event.declined_at),
        "reason" => event.reason,
        "guild_id" => event.guild_id,
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        invitation_id: data["invitation_id"],
        declined_at: GameEvents.parse_timestamp(data["declined_at"]),
        reason: data["reason"],
        guild_id: data["guild_id"],
        metadata: data["metadata"] || %{}
      }
    end
  end
end
