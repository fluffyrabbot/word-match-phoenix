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

  # Declare that this module implements the GameEvents behaviour
  @behaviour GameBot.Domain.Events.GameEvents

  alias GameBot.Domain.Events.{Metadata, EventStructure, GameEvents}

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

  @valid_actions ~w(create update delete do_something)

  @doc """
  Creates a new ExampleEvent.
  """
  def new(game_id, guild_id, player_id, action, data, metadata) when is_map(metadata) do
    attrs = %{
      game_id: game_id,
      guild_id: guild_id,
      mode: :two_player,  # Default mode for example
      round_number: 1,    # Default round for example
      player_id: player_id,
      action: action,
      data: data,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }
    new(attrs)
  end

  def new(game_id, guild_id, player_id, action, data, {:ok, metadata}) do
    new(game_id, guild_id, player_id, action, data, metadata)
  end

  @doc """
  Creates a new ExampleEvent with the given attributes.
  """
  def new(attrs) do
    struct!(__MODULE__, Map.merge(default_attrs(), attrs))
  end

  @doc """
  Creates a new ExampleEvent from a parent event.
  """
  def from_parent(parent_event, player_id, action, data) do
    # Convert map to keyword list for from_parent_event
    case Metadata.from_parent_event(parent_event.metadata, [actor_id: player_id]) do
      {:ok, metadata} ->
        attrs = %{
          game_id: parent_event.game_id,
          guild_id: parent_event.guild_id,
          mode: parent_event.mode,
          round_number: parent_event.round_number,
          player_id: player_id,
          action: action,
          data: data,
          timestamp: DateTime.utc_now(),
          metadata: metadata
        }
        new(attrs)
      {:error, reason} ->
        raise "Failed to create metadata from parent: #{reason}"
    end
  end

  @doc """
  Returns the list of required fields for this event.
  """
  def required_fields do
    super() ++ [:player_id, :action, :data]
  end

  @doc """
  Validates custom fields specific to this event.
  """
  def validate_custom_fields(changeset) do
    changeset
    |> validate_inclusion(:action, @valid_actions, message: "must be one of: #{Enum.join(@valid_actions, ", ")}")
    |> validate_required([:player_id, :action, :data])
  end

  @doc """
  Validates the event.
  """
  @impl GameEvents
  def validate(%__MODULE__{} = event) do
    with :ok <- EventStructure.validate(event),
         :ok <- validate_required_fields(event),
         :ok <- validate_action(event.action),
         :ok <- validate_data(event.data) do
      :ok
    end
  end

  @doc """
  Serializes the event for storage.
  """
  def serialize(%__MODULE__{} = event) do
    case validate(event) do
      :ok -> to_map(event)
      {:error, reason} -> raise "Invalid event: #{reason}"
    end
  end

  @doc """
  Deserializes the event from storage format.
  """
  def deserialize(data) when is_map(data) do
    from_map(data)
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

  @doc """
  Converts the event to a map for serialization.
  """
  @impl GameEvents
  def to_map(%__MODULE__{} = event) do
    %{
      "game_id" => event.game_id,
      "guild_id" => event.guild_id,
      "mode" => Atom.to_string(event.mode),
      "round_number" => event.round_number,
      "player_id" => event.player_id,
      "action" => event.action,
      "data" => event.data,
      "timestamp" => DateTime.to_iso8601(event.timestamp),
      "metadata" => event.metadata || %{}
    }
  end

  @doc """
  Creates an event from a serialized map.
  """
  @impl GameEvents
  def from_map(data) do
    %__MODULE__{
      game_id: data["game_id"],
      guild_id: data["guild_id"],
      mode: String.to_existing_atom(data["mode"]),
      round_number: data["round_number"],
      player_id: data["player_id"],
      action: data["action"],
      data: data["data"],
      timestamp: GameEvents.parse_timestamp(data["timestamp"]),
      metadata: data["metadata"] || %{}
    }
  end

  # Private validation functions

  defp validate_required_fields(event) do
    required = required_fields()
    missing = Enum.filter(required, &(is_nil(Map.get(event, &1))))

    case missing do
      [] -> :ok
      [field | _] -> {:error, "#{field} is required"}
    end
  end

  defp validate_action(nil), do: {:error, "action is required"}
  defp validate_action(action) when action in @valid_actions, do: :ok
  defp validate_action(_), do: {:error, "action must be one of: #{Enum.join(@valid_actions, ", ")}"}

  defp validate_data(nil), do: {:error, "data is required"}
  defp validate_data(data) when is_map(data), do: :ok
  defp validate_data(_), do: {:error, "data must be a map"}

  defp default_attrs do
    %{
      id: Ecto.UUID.generate(),
      type: "example_event",
      version: 1,
      timestamp: DateTime.utc_now(),
      data: %{},
      metadata: %{}
    }
  end
end
