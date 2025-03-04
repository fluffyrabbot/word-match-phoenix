defmodule GameBot.Domain.Aggregates.TeamAggregate do
  @moduledoc """
  Aggregate root for managing team state and handling team-related commands.
  """

  alias GameBot.Domain.Commands.TeamCommands.{CreateTeam, UpdateTeam}
  alias GameBot.Domain.Events.TeamEvents.{TeamCreated, TeamUpdated}

  defmodule State do
    @moduledoc "Internal state for team aggregate"
    defstruct [:team_id, :name, :player_ids, :created_at, :updated_at]
  end

  def execute(%State{team_id: nil}, %CreateTeam{} = cmd) do
    case CreateTeam.validate(cmd) do
      :ok ->
        %TeamCreated{
          team_id: cmd.team_id,
          name: cmd.name,
          player_ids: cmd.player_ids,
          created_at: DateTime.utc_now(),
          metadata: %{}
        }
      error -> error
    end
  end

  def execute(%State{team_id: team_id}, %CreateTeam{}) when not is_nil(team_id) do
    {:error, "team already exists"}
  end

  def execute(%State{team_id: team_id} = state, %UpdateTeam{team_id: team_id} = cmd) do
    case UpdateTeam.validate(cmd) do
      :ok ->
        if cmd.name != state.name do
          %TeamUpdated{
            team_id: team_id,
            name: cmd.name,
            updated_at: DateTime.utc_now(),
            metadata: %{}
          }
        else
          :ok
        end
      error -> error
    end
  end

  def execute(%State{}, %UpdateTeam{}) do
    {:error, "team does not exist"}
  end

  def apply(%State{} = state, %TeamCreated{} = event) do
    %State{
      team_id: event.team_id,
      name: event.name,
      player_ids: event.player_ids,
      created_at: event.created_at,
      updated_at: event.created_at
    }
  end

  def apply(%State{} = state, %TeamUpdated{} = event) do
    %State{state | name: event.name, updated_at: event.updated_at}
  end
end
