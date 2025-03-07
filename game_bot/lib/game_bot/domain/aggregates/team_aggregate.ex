defmodule GameBot.Domain.Aggregates.TeamAggregate do
  @moduledoc """
  Aggregate root for managing team state and handling team-related commands.
  Teams are automatically created or retrieved based on unique player pairs.
  Players can only be in one active team - joining a new team supersedes previous membership.
  """

  alias GameBot.Domain.Commands.TeamCommands.{
    CreateTeamInvitation,
    AcceptInvitation,
    RenameTeam
  }
  alias GameBot.Domain.Events.TeamEvents.{TeamInvitationCreated, TeamInvitationAccepted, TeamCreated, TeamUpdated}
  alias GameBot.Domain.Aggregates.Team.State

  defmodule State do
    @moduledoc "Internal state for team aggregate"
    defstruct [:team_id, :name, :player_ids, :created_at, :updated_at, :pending_invitation]
  end

  def execute(%State{} = state, %CreateTeamInvitation{} = cmd) do
    case CreateTeamInvitation.validate(cmd) do
      :ok ->
        invitation_id = generate_invitation_id(cmd.inviter_id, cmd.invitee_id)
        expires_at = DateTime.add(DateTime.utc_now(), 300) # 5 minutes

        %TeamInvitationCreated{
          invitation_id: invitation_id,
          inviter_id: cmd.inviter_id,
          invitee_id: cmd.invitee_id,
          proposed_name: cmd.name,
          created_at: DateTime.utc_now(),
          expires_at: expires_at
        }
      error -> error
    end
  end

  def execute(%State{} = state, %AcceptInvitation{} = cmd) do
    with :ok <- validate_invitation(state, cmd.invitee_id) do
      # Generate team_id from sorted player IDs
      [p1, p2] = Enum.sort([state.pending_invitation.inviter_id, cmd.invitee_id])
      team_id = "team-#{p1}-#{p2}"

      # Use proposed name or generate default
      name = state.pending_invitation.proposed_name || "Team #{p1}-#{p2}"

      [
        # First record the acceptance
        %TeamInvitationAccepted{
          invitation_id: state.pending_invitation.invitation_id,
          team_id: team_id,
          accepted_at: DateTime.utc_now()
        },
        # Then create the team
        %TeamCreated{
          team_id: team_id,
          name: name,
          player_ids: [p1, p2],
          created_at: DateTime.utc_now(),
          metadata: %{changed_by: cmd.invitee_id}
        }
      ]
    else
      error -> error
    end
  end

  def execute(%State{team_id: team_id} = state, %RenameTeam{team_id: team_id, requester_id: requester_id} = cmd) do
    with :ok <- validate_member(state, requester_id),
         :ok <- RenameTeam.validate(cmd) do
      if cmd.new_name != state.name do
        %TeamUpdated{
          team_id: team_id,
          name: cmd.new_name,
          updated_at: DateTime.utc_now(),
          metadata: %{changed_by: requester_id}
        }
      else
        :ok
      end
    else
      error -> error
    end
  end

  def execute(%State{}, %RenameTeam{}) do
    {:error, :team_not_found}
  end

  def apply(%State{} = state, %TeamInvitationCreated{} = event) do
    %State{state |
      pending_invitation: %{
        invitation_id: event.invitation_id,
        inviter_id: event.inviter_id,
        invitee_id: event.invitee_id,
        proposed_name: event.proposed_name,
        created_at: event.created_at,
        expires_at: event.expires_at
      }
    }
  end

  def apply(%State{} = state, %TeamInvitationAccepted{}) do
    # Clear the pending invitation
    %State{state | pending_invitation: nil}
  end

  def apply(%State{} = _state, %TeamCreated{} = event) do
    %State{
      team_id: event.team_id,
      name: event.name,
      player_ids: event.player_ids,
      created_at: event.created_at,
      updated_at: event.created_at,
      pending_invitation: nil
    }
  end

  def apply(%State{} = state, %TeamUpdated{} = event) do
    %State{state | name: event.name, updated_at: event.updated_at}
  end

  # Private helpers

  defp validate_member(%State{player_ids: player_ids}, player_id) do
    if player_id in player_ids do
      :ok
    else
      {:error, :not_team_member}
    end
  end

  defp validate_invitation(%State{pending_invitation: nil}, _invitee_id) do
    {:error, :no_pending_invitation}
  end

  defp validate_invitation(%State{pending_invitation: invitation}, invitee_id) do
    cond do
      invitation.invitee_id != invitee_id ->
        {:error, :wrong_invitee}

      DateTime.compare(DateTime.utc_now(), invitation.expires_at) == :gt ->
        {:error, :invitation_expired}

      true ->
        :ok
    end
  end

  defp generate_invitation_id(inviter_id, invitee_id) do
    [p1, p2] = Enum.sort([inviter_id, invitee_id])
    "inv-#{p1}-#{p2}-#{System.system_time(:second)}"
  end
end
