defmodule GameBot.Domain.Events.GameEvents.ExampleEvent do
  @moduledoc """
  An example event that demonstrates the use of the BaseEvent behavior.
  This can be used as a template for creating new events.
  """

  use GameBot.Domain.Events.BaseEvent,
    event_type: "example_event",
    version: 1,
    fields: [
      field(:player_id, :string),
      field(:action, :string),
      field(:data, :map)
    ]

  alias GameBot.Domain.Events.{Metadata, EventStructure, GameEvents}
  import EventStructure, only: [validate_base_fields: 1]

  @type t :: %__MODULE__{
    id: Ecto.UUID.t(),
    game_id: String.t(),
    guild_id: String.t(),
    mode: :two_player | :knockout | :race,
    round_number: pos_integer(),
    player_id: String.t(),
    action: String.t(),
    data: map(),
    timestamp: DateTime.t(),
    metadata: map(),
    type: String.t(),
    version: pos_integer(),
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  @valid_actions ~w(create update delete)

  @doc """
  Creates a new ExampleEvent.
  """
  def new(game_id, guild_id, player_id, action, data, metadata) do
    new(%{
      game_id: game_id,
      guild_id: guild_id,
      mode: :two_player,  # Default mode for example
      round_number: 1,    # Default round for example
      player_id: player_id,
      action: action,
      data: data,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    })
  end

  @doc """
  Creates a new ExampleEvent with the given attributes.
  """
  def new(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Ecto.Changeset.apply_changes()
  end

  @doc """
  Creates a new ExampleEvent from a parent event.
  """
  def from_parent(parent_event, player_id, action, data) do
    metadata = Metadata.from_parent_event(parent_event.metadata, %{actor_id: player_id})

    new(%{
      game_id: parent_event.game_id,
      guild_id: parent_event.guild_id,
      mode: parent_event.mode,
      round_number: parent_event.round_number,
      player_id: player_id,
      action: action,
      data: data,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    })
  end

  @doc """
  Validates the event.
  """
  def validate(%__MODULE__{} = event) do
    with :ok <- validate_base_fields(event),
         :ok <- validate_player_id(event.player_id),
         :ok <- validate_action(event.action),
         :ok <- validate_data(event.data),
         :ok <- validate_metadata(event.metadata) do
      :ok
    end
  end

  @doc """
  Serializes the event for storage.
  """
  def serialize(%__MODULE__{} = event) do
    GameEvents.serialize(event)
  end

  @doc """
  Applies the event to a state after validating it.
  """
  def apply(%__MODULE__{} = event, state) do
    case validate(event) do
      :ok ->
        updated_state = state
          |> Map.put(:actions, [event.action | Map.get(state, :actions, [])])
          |> Map.put(:last_player_id, event.player_id)
          |> Map.put(:last_action_time, event.timestamp)
        {:ok, updated_state}
      error -> error
    end
  end

  # Private validation functions

  defp validate_player_id(nil), do: {:error, "player_id is required"}
  defp validate_player_id(player_id) when is_binary(player_id), do: :ok
  defp validate_player_id(_), do: {:error, "player_id must be a string"}

  defp validate_action(nil), do: {:error, "action is required"}
  defp validate_action(action) when action in @valid_actions, do: :ok
  defp validate_action(_), do: {:error, "action must be one of: #{Enum.join(@valid_actions, ", ")}"}

  defp validate_data(nil), do: {:error, "data is required"}
  defp validate_data(data) when is_map(data), do: :ok
  defp validate_data(_), do: {:error, "data must be a map"}

  defp validate_metadata(nil), do: {:error, "metadata is required"}
  defp validate_metadata(metadata) when is_map(metadata) do
    case Metadata.validate(metadata) do
      :ok -> :ok
      {:error, reason} -> {:error, "invalid metadata: #{reason}"}
    end
  end
  defp validate_metadata(_), do: {:error, "metadata must be a map"}
end
