defmodule GameBot.Replay.GameReplay do
  @moduledoc """
  Schema for the game_replays table, which stores replay references.

  This table stores lightweight references to game event streams,
  rather than duplicating the full event data.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias GameBot.Replay.Types

  @primary_key {:replay_id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "game_replays" do
    field :game_id, :string
    field :display_name, :string
    field :mode, Ecto.Enum, values: [:two_player, :knockout, :race, :golf_race, :longform]
    field :start_time, :utc_datetime_usec
    field :end_time, :utc_datetime_usec
    field :event_count, :integer
    field :base_stats, :map
    field :mode_stats, :map
    field :version_map, :map
    field :created_at, :utc_datetime_usec

    timestamps()
  end

  @doc """
  Changeset for creating a new game replay record.
  """
  def changeset(replay, attrs) do
    replay
    |> cast(attrs, [
      :game_id,
      :display_name,
      :mode,
      :start_time,
      :end_time,
      :event_count,
      :base_stats,
      :mode_stats,
      :version_map,
      :created_at
    ])
    |> validate_required([
      :game_id,
      :display_name,
      :mode,
      :start_time,
      :end_time,
      :event_count,
      :base_stats,
      :mode_stats,
      :version_map
    ])
    |> put_change_if_missing(:created_at, DateTime.utc_now())
    |> unique_constraint(:display_name)
    |> validate_format(:display_name, ~r/^[a-z]+-\d{3}$/, message: "must be in format word-123")
    |> validate_number(:event_count, greater_than: 0)
    |> validate_game_id()
    |> validate_timestamps()
  end

  # Set a field value if it's not already present
  defp put_change_if_missing(changeset, field, value) do
    if get_field(changeset, field) do
      changeset
    else
      put_change(changeset, field, value)
    end
  end

  # Additional validations

  defp validate_game_id(changeset) do
    validate_format(changeset, :game_id, ~r/^[a-zA-Z0-9_-]+$/,
      message: "must contain only letters, numbers, underscores, and hyphens")
  end

  defp validate_timestamps(changeset) do
    case {get_field(changeset, :start_time), get_field(changeset, :end_time)} do
      {nil, _} -> changeset
      {_, nil} -> changeset
      {start_time, end_time} ->
        if DateTime.compare(start_time, end_time) == :gt do
          add_error(changeset, :end_time, "must be after start_time")
        else
          changeset
        end
    end
  end

  @doc """
  Converts a replay reference to a schema struct for insertion.
  """
  @spec from_reference(Types.replay_reference()) :: %__MODULE__{}
  def from_reference(reference) do
    %__MODULE__{
      game_id: reference.game_id,
      display_name: reference.display_name,
      mode: reference.mode,
      start_time: reference.start_time,
      end_time: reference.end_time,
      event_count: reference.event_count,
      base_stats: reference.base_stats,
      mode_stats: reference.mode_stats,
      version_map: reference.version_map,
      created_at: reference.created_at || DateTime.utc_now()
    }
  end

  @doc """
  Converts a schema struct to a replay reference.
  """
  @spec to_reference(%__MODULE__{}) :: Types.replay_reference()
  def to_reference(replay) do
    %{
      replay_id: replay.replay_id,
      game_id: replay.game_id,
      display_name: replay.display_name,
      mode: replay.mode,
      start_time: replay.start_time,
      end_time: replay.end_time,
      event_count: replay.event_count,
      base_stats: replay.base_stats,
      mode_stats: replay.mode_stats,
      version_map: replay.version_map,
      created_at: replay.created_at
    }
  end
end
