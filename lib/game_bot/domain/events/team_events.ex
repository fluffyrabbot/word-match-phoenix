defmodule GameBot.Domain.Events.TeamEvents do
  @moduledoc """
  Defines events related to team management.
  """

  alias GameBot.Domain.Events.GameEvents

  defmodule TeamCreated do
    @moduledoc "Emitted when a new team is created"
    @behaviour GameEvents

    @type t :: %__MODULE__{
      team_id: String.t(),
      name: String.t(),
      player_ids: [String.t()],
      created_at: DateTime.t(),
      metadata: GameEvents.metadata()
    }
    defstruct [:team_id, :name, :player_ids, :created_at, :metadata]

    def event_type(), do: "team_created"
    def event_version(), do: 1

    def validate(%__MODULE__{} = event) do
      cond do
        is_nil(event.team_id) -> {:error, "team_id is required"}
        is_nil(event.name) -> {:error, "name is required"}
        is_nil(event.player_ids) -> {:error, "player_ids is required"}
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
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        team_id: data["team_id"],
        name: data["name"],
        player_ids: data["player_ids"],
        created_at: GameEvents.parse_timestamp(data["created_at"]),
        metadata: data["metadata"] || %{}
      }
    end
  end

  defmodule TeamUpdated do
    @moduledoc "Emitted when a team's details are updated"
    @behaviour GameEvents

    @type t :: %__MODULE__{
      team_id: String.t(),
      name: String.t(),
      updated_at: DateTime.t(),
      metadata: GameEvents.metadata()
    }
    defstruct [:team_id, :name, :updated_at, :metadata]

    def event_type(), do: "team_updated"
    def event_version(), do: 1

    def validate(%__MODULE__{} = event) do
      cond do
        is_nil(event.team_id) -> {:error, "team_id is required"}
        is_nil(event.name) -> {:error, "name is required"}
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
end
