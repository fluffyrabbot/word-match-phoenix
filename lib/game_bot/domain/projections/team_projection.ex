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

  def handle_event(%TeamCreated{} = event) do
    team = %TeamView{
      team_id: event.team_id,
      name: event.name,
      player_ids: event.player_ids,
      created_at: event.created_at,
      updated_at: event.created_at
    }
    {:ok, team}
  end

  def handle_event(%TeamUpdated{} = event, %TeamView{} = team) do
    updated_team = %TeamView{team |
      name: event.name,
      updated_at: event.updated_at
    }
    {:ok, updated_team}
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
end
