defmodule GameBot.Domain.Projections.TeamProjection do
  @moduledoc """
  Projection for building team read models from team events.
  """

  alias GameBot.Domain.Events.TeamEvents.{
    TeamCreated,
    TeamMemberAdded,
    TeamMemberRemoved,
    TeamInvitationCreated,
    TeamInvitationAccepted,
    TeamInvitationDeclined,
    TeamUpdated
  }

  defmodule TeamView do
    @moduledoc "Read model for team data"
    @type t :: %__MODULE__{
      team_id: String.t(),
      name: String.t(),
      player_ids: [String.t()],
      created_at: DateTime.t(),
      updated_at: DateTime.t(),
      guild_id: String.t()
    }
    defstruct [:team_id, :name, :player_ids, :created_at, :updated_at, :guild_id]
  end

  defmodule PendingInvitationView do
    @moduledoc """
    Tracks active team invitations with expiration.
    """
    @type t :: %__MODULE__{
      invitation_id: String.t(),
      inviter_id: String.t(),
      invitee_id: String.t(),
      proposed_name: String.t() | nil,
      created_at: DateTime.t(),
      expires_at: DateTime.t(),
      guild_id: String.t()
    }
    defstruct [:invitation_id, :inviter_id, :invitee_id, :proposed_name, :created_at, :expires_at, :guild_id]
  end

  defmodule TeamNameHistory do
    @moduledoc """
    Historical record of team name changes.
    Optimized for storage efficiency by storing only the changes and maintaining order.
    """
    @type t :: %__MODULE__{
      team_id: String.t(),
      previous_name: String.t() | nil,  # nil for creation event
      new_name: String.t(),
      changed_at: DateTime.t(),
      changed_by: String.t() | nil,
      sequence_no: integer(),           # For maintaining order without timestamp comparisons
      event_type: String.t()           # "created" or "updated"
    }
    defstruct [:team_id, :previous_name, :new_name, :changed_at, :changed_by, :sequence_no, :event_type]
  end

  def handle_event(%TeamInvitationCreated{} = event) do
    invitation = %PendingInvitationView{
      invitation_id: event.invitation_id,
      inviter_id: event.inviter_id,
      invitee_id: event.invitee_id,
      proposed_name: event.proposed_name,
      created_at: event.created_at,
      expires_at: event.expires_at,
      guild_id: event.guild_id
    }
    {:ok, {:invitation_created, invitation}}
  end

  def handle_event(%TeamInvitationAccepted{} = event) do
    {:ok, {:invitation_accepted, event.invitation_id}}
  end

  def handle_event(%TeamCreated{} = event) do
    team = %TeamView{
      team_id: event.team_id,
      name: event.name,
      player_ids: event.player_ids,
      created_at: event.created_at,
      updated_at: event.created_at,
      guild_id: event.guild_id
    }

    history_entry = %TeamNameHistory{
      team_id: event.team_id,
      previous_name: nil,
      new_name: event.name,
      changed_at: event.created_at,
      changed_by: event.metadata["changed_by"],
      sequence_no: 0,
      event_type: "created"
    }

    {:ok, {:team_created, team, history_entry}}
  end

  def handle_event(%TeamUpdated{} = event, %{team: team, history: history}) do
    # Only create history entry if name actually changed
    if event.name != team.name do
      updated_team = %TeamView{team |
        name: event.name,
        updated_at: event.updated_at
      }

      history_entry = %TeamNameHistory{
        team_id: event.team_id,
        previous_name: team.name,
        new_name: event.name,
        changed_at: event.updated_at,
        changed_by: event.metadata["changed_by"],
        sequence_no: length(history),
        event_type: "updated"
      }

      {:ok, {:team_updated, updated_team, history_entry}}
    else
      {:ok, :no_change}
    end
  end

  def handle_event(_, state), do: {:ok, state}

  # Query functions

  def get_pending_invitation(invitee_id, guild_id) do
    # Filter by both invitee_id and guild_id
    # This is a placeholder - actual implementation would depend on your storage
    {:error, :not_implemented}
  end

  @doc """
  Creates a new team in the projection.
  Used for direct team creation operations.

  ## Parameters
    * `params` - Map containing team details:
      - `:team_id` - Unique identifier for the team
      - `:name` - Team name
      - `:player_ids` - List of player IDs
      - `:guild_id` - Discord guild ID

  ## Returns
    * `{:ok, team}` - Successfully created team
    * `{:error, reason}` - Failed to create team
  """
  def create_team(params) do
    # Create a team directly from parameters
    # This avoids having to create and process events when all we need is to update the projection
    team = %TeamView{
      team_id: params.team_id,
      name: params.name,
      player_ids: params.player_ids,
      created_at: params.created_at || DateTime.utc_now(),
      updated_at: params.updated_at || DateTime.utc_now(),
      guild_id: params.guild_id
    }

    history_entry = %TeamNameHistory{
      team_id: params.team_id,
      previous_name: nil,
      new_name: params.name,
      changed_at: params.created_at || DateTime.utc_now(),
      changed_by: params.changed_by,
      sequence_no: 0,
      event_type: "created"
    }

    # Return the team and history entry to be persisted by the caller
    {:ok, {:team_created, team, history_entry}}
  end

  @doc """
  Updates an existing team in the projection.
  Used for direct team update operations.

  ## Parameters
    * `params` - Map containing update details:
      - `:team_id` - Team ID to update
      - `:name` - New team name (optional)
      - `:player_ids` - Updated player IDs (optional)
      - `:guild_id` - Discord guild ID

  ## Returns
    * `{:ok, team}` - Successfully updated team
    * `{:error, reason}` - Failed to update team
  """
  def update_team(params) do
    # Note: In a real implementation, we would look up the existing team first
    # This is a placeholder that assumes the team exists and can be updated

    # For testing/placeholder, create a fake existing team
    existing_team = %TeamView{
      team_id: params.team_id,
      name: params[:existing_name] || "Existing Team",
      player_ids: params[:existing_player_ids] || [],
      created_at: params[:created_at] || ~U[2023-01-01 00:00:00Z],
      updated_at: params[:updated_at] || ~U[2023-01-01 00:00:00Z],
      guild_id: params.guild_id
    }

    # Apply updates to the team
    updated_team = %TeamView{existing_team |
      name: params[:name] || existing_team.name,
      player_ids: params[:player_ids] || existing_team.player_ids,
      updated_at: params[:updated_at] || DateTime.utc_now()
    }

    # Only create history entry if name changed
    if params[:name] && params[:name] != existing_team.name do
      history_entry = %TeamNameHistory{
        team_id: params.team_id,
        previous_name: existing_team.name,
        new_name: params[:name],
        changed_at: params[:updated_at] || DateTime.utc_now(),
        changed_by: params[:changed_by],
        sequence_no: 1, # This should be determined by actual history length
        event_type: "updated"
      }

      {:ok, {:team_updated, updated_team, history_entry}}
    else
      # No name change, so no history entry needed
      {:ok, {:team_updated, updated_team}}
    end
  end

  def get_team(team_id, guild_id) do
    # Filter by both team_id and guild_id
    {:error, :not_implemented}
  end

  def list_teams do
    # To be implemented with actual storage
    {:error, :not_implemented}
  end

  def find_team_by_player(player_id, guild_id) do
    # Filter by both player_id and guild_id
    {:error, :not_implemented}
  end

  def get_team_name_history(team_id, opts \\ []) do
    # To be implemented with actual storage
    # opts can include:
    # - from: DateTime.t() - start of time range
    # - to: DateTime.t() - end of time range
    # - limit: integer() - max number of entries
    # - order: :asc | :desc - chronological order
    {:error, :not_implemented}
  end

  @doc """
  Reconstructs the full name history timeline from the stored change records.
  This is more efficient than storing full state at each point.
  """
  def reconstruct_name_timeline(history) when is_list(history) do
    history
    |> Enum.sort_by(& &1.sequence_no)
    |> Enum.map(fn entry ->
      %{
        name: entry.new_name,
        from: entry.changed_at,
        changed_by: entry.changed_by,
        previous_name: entry.previous_name
      }
    end)
  end
end
