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

  # Explicitly declare that this module implements the GameEvents behaviour
  @behaviour GameBot.Domain.Events.GameEvents

  # Import only what's needed
  alias GameBot.Domain.Events.{Metadata, EventStructure, GameEvents}

  # Define comprehensive type specification
  @type t :: %__MODULE__{
    # Base fields (from BaseEvent)
    id: Ecto.UUID.t(),
    game_id: String.t(),
    guild_id: String.t(),
    mode: :two_player | :knockout | :race,
    round_number: pos_integer(),
    timestamp: DateTime.t(),
    metadata: Metadata.t(),
    type: String.t(),
    version: pos_integer(),

    # Custom fields
    player_id: String.t(),
    action: String.t(),
    data: map(),

    # Ecto timestamps
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  # Define constants for validation
  @valid_actions ~w(create update delete do_something)

  @doc """
  Returns the list of required fields for this event.
  """
  @spec required_fields() :: [atom()]
  def required_fields do
    super() ++ [:player_id, :action, :data]
  end

  @doc """
  Validates custom fields specific to this event.
  """
  @spec validate_custom_fields(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate_custom_fields(changeset) do
    # Always call super first to ensure base validation is performed
    super(changeset)
    |> validate_inclusion(:action, @valid_actions, message: "must be one of: #{Enum.join(@valid_actions, ", ")}")
    |> validate_required([:player_id, :action, :data])
  end

  @doc """
  Validates the event.

  Implements the GameEvents.validate/1 callback.
  """
  @impl GameEvents
  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{} = event) do
    # First validate the overall structure
    case EventStructure.validate(event) do
      :ok ->
        # Then validate custom fields
        with :ok <- validate_action(event.action),
             :ok <- validate_data(event.data) do
          :ok
        end
      error -> error
    end
  end

  @doc """
  Converts the event to a map for serialization.

  Implements the GameEvents.to_map/1 callback.
  """
  @impl GameEvents
  @spec to_map(t()) :: map()
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

  Implements the GameEvents.from_map/1 callback.
  """
  @impl GameEvents
  @spec from_map(map()) :: t()
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

  # Standard creation functions

  @doc """
  Creates a new ExampleEvent with the given attributes.

  ## Parameters
  - attrs: Map containing event attributes

  ## Returns
  - A new ExampleEvent struct
  """
  @spec new(map()) :: t()
  def new(attrs) do
    struct!(__MODULE__, Map.merge(default_attrs(), attrs))
  end

  @doc """
  Creates a new ExampleEvent with individual parameters.

  ## Parameters
  - game_id: Game identifier
  - guild_id: Discord guild identifier
  - player_id: Player identifier
  - action: Action being performed
  - data: Additional event data
  - metadata: Event metadata

  ## Returns
  - A new ExampleEvent struct
  """
  @spec new(String.t(), String.t(), String.t(), String.t(), map(), map()) :: t()
  def new(game_id, guild_id, player_id, action, data, metadata) when is_map(metadata) do
    attrs = %{
      game_id: game_id,
      guild_id: guild_id,
      mode: :two_player,  # Default mode
      round_number: 1,    # Default round
      player_id: player_id,
      action: action,
      data: data,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }
    new(attrs)
  end

  @doc """
  Creates a new ExampleEvent with metadata result tuple.

  ## Parameters
  - game_id: Game identifier
  - guild_id: Discord guild identifier
  - player_id: Player identifier
  - action: Action being performed
  - data: Additional event data
  - metadata_result: Tuple containing {:ok, metadata}

  ## Returns
  - A new ExampleEvent struct
  """
  @spec new(String.t(), String.t(), String.t(), String.t(), map(), {:ok, map()}) :: t()
  def new(game_id, guild_id, player_id, action, data, {:ok, metadata}) do
    new(game_id, guild_id, player_id, action, data, metadata)
  end

  @doc """
  Creates a new ExampleEvent from a parent event.

  ## Parameters
  - parent_event: The parent event
  - player_id: Player identifier
  - action: Action being performed
  - data: Additional event data

  ## Returns
  - A new ExampleEvent struct

  ## Raises
  - RuntimeError if metadata creation fails
  """
  @spec from_parent(struct(), String.t(), String.t(), map()) :: t()
  def from_parent(parent_event, player_id, action, data) do
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
  Applies the event to a state after validating it.

  ## Parameters
  - event: The event to apply
  - state: The current state

  ## Returns
  - {:ok, updated_state} on success
  - {:error, reason} on validation failure
  """
  @spec apply(t(), map()) :: {:ok, map()} | {:error, String.t()}
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

  @spec validate_action(String.t() | nil) :: :ok | {:error, String.t()}
  defp validate_action(nil), do: {:error, "action is required"}
  defp validate_action(action) when action in @valid_actions, do: :ok
  defp validate_action(_), do: {:error, "action must be one of: #{Enum.join(@valid_actions, ", ")}"}

  @spec validate_data(map() | nil) :: :ok | {:error, String.t()}
  defp validate_data(nil), do: {:error, "data is required"}
  defp validate_data(data) when is_map(data), do: :ok
  defp validate_data(_), do: {:error, "data must be a map"}

  @doc """
  Deserializes event data into an ExampleEvent struct.
  This function is required by EventRegistry.deserialize/1.

  ## Parameters
  - data: Map containing event data

  ## Returns
  - An ExampleEvent struct
  """
  @spec deserialize(map()) :: t()
  def deserialize(data) do
    from_map(data)
  end

  @spec default_attrs() :: map()
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
