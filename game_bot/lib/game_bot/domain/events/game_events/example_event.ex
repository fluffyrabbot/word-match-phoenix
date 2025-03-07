defmodule GameBot.Domain.Events.GameEvents.ExampleEvent do
  @moduledoc """
  An example event that demonstrates the use of the BaseEvent behavior.
  This can be used as a template for converting existing events.
  """

  use GameBot.Domain.Events.BaseEvent, event_type: "example_event", version: 1

  alias GameBot.Domain.Events.{Metadata, EventStructure}

  @type t :: %__MODULE__{
    game_id: String.t(),
    guild_id: String.t(),
    player_id: String.t(),
    action: String.t(),
    data: map(),
    timestamp: DateTime.t(),
    metadata: map()
  }
  defstruct [:game_id, :guild_id, :player_id, :action, :data, :timestamp, :metadata]

  @doc """
  Creates a new ExampleEvent.
  """
  def new(game_id, guild_id, player_id, action, data, metadata) do
    %__MODULE__{
      game_id: game_id,
      guild_id: guild_id,
      player_id: player_id,
      action: action,
      data: data,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }
  end

  @doc """
  Creates a new ExampleEvent from a parent event.
  """
  def from_parent(parent_event, player_id, action, data) do
    metadata = Metadata.from_parent_event(parent_event, %{actor_id: player_id})

    %__MODULE__{
      game_id: parent_event.game_id,
      guild_id: parent_event.guild_id,
      player_id: player_id,
      action: action,
      data: data,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }
  end

  @impl true
  def validate(event) do
    with :ok <- EventStructure.validate(event) do
      cond do
        is_nil(event.player_id) -> {:error, "player_id is required"}
        is_nil(event.action) -> {:error, "action is required"}
        is_nil(event.data) -> {:error, "data is required"}
        true -> :ok
      end
    end
  end

  @impl true
  def serialize(event) do
    Map.from_struct(event)
    |> Map.put(:timestamp, DateTime.to_iso8601(event.timestamp))
  end

  @impl true
  def deserialize(data) do
    %__MODULE__{
      game_id: data.game_id,
      guild_id: data.guild_id,
      player_id: data.player_id,
      action: data.action,
      data: data.data,
      timestamp: EventStructure.parse_timestamp(data.timestamp),
      metadata: data.metadata
    }
  end

  @impl true
  def apply(event, state) do
    # Example implementation of how to apply the event to a state
    # This would typically update the state based on the event data
    updated_state = state
    |> Map.update(:actions, [event.action], fn actions -> [event.action | actions] end)
    |> Map.put(:last_player_id, event.player_id)
    |> Map.put(:last_action_time, event.timestamp)

    {:ok, updated_state}
  end
end
