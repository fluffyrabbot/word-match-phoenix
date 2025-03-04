defmodule GameBot.Domain.Projections.TeamProjection do
  @moduledoc """
  Projection for building team read models from team events.
  """

  alias GameBot.Domain.Events.TeamEvents.{TeamCreated, TeamUpdated}

  defmodule TeamView do
    @moduledoc "Read model for team data"
    @type t :: %__MODULE__{
      team_id: String.t(),
      name: String.t(),
      player_ids: [String.t()],
      created_at: DateTime.t(),
      updated_at: DateTime.t()
    }
    defstruct [:team_id, :name, :player_ids, :created_at, :updated_at]
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

  def handle_event(%TeamCreated{} = event) do
    team = %TeamView{
      team_id: event.team_id,
      name: event.name,
      player_ids: event.player_ids,
      created_at: event.created_at,
      updated_at: event.created_at
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

    {:ok, {team, [history_entry]}}
  end

  def handle_event(%TeamUpdated{} = event, {%TeamView{} = team, history}) do
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

      {:ok, {updated_team, [history_entry | history]}}
    else
      {:ok, {team, history}}
    end
  end

  def handle_event(_, state), do: {:ok, state}

  # Query functions

  def get_team(team_id) do
    # To be implemented with actual storage
    {:error, :not_implemented}
  end

  def list_teams do
    # To be implemented with actual storage
    {:error, :not_implemented}
  end

  def find_team_by_player(player_id) do
    # To be implemented with actual storage
    {:error, :not_implemented}
  end

  def get_team_name_history(team_id) do
    # To be implemented with actual storage
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
