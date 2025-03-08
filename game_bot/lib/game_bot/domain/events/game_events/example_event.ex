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

  alias GameBot.Domain.Events.Metadata

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
  def new(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Ecto.Changeset.apply_changes()
  end

  @doc """
  Creates a new ExampleEvent from a parent event.
  """
  def from_parent(parent_event, player_id, action, data) do
    new(%{
      game_id: parent_event.game_id,
      guild_id: parent_event.guild_id,
      mode: parent_event.mode,
      round_number: parent_event.round_number,
      player_id: player_id,
      action: action,
      data: data,
      metadata: Metadata.from_parent_event(parent_event, %{actor_id: player_id})
    })
  end

  @impl true
  def required_fields do
    super() ++ [:player_id, :action, :data]
  end

  @impl true
  def validate_custom_fields(changeset) do
    super(changeset)
    |> validate_inclusion(:action, @valid_actions, message: "must be one of: #{Enum.join(@valid_actions, ", ")}")
  end
end
