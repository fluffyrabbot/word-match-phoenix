defmodule GameBot.Infrastructure.Postgres.Models.Event do
  @moduledoc """
  Ecto schema for game events.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "events" do
    field :type, :string
    field :data, :map
    field :version, :integer, default: 1
    field :timestamp, :utc_datetime
    
    # Associations
    belongs_to :game_session, GameBot.Infrastructure.Postgres.Models.GameSession
    
    timestamps()
  end
  
  @doc """
  Changeset for creating events.
  """
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:type, :data, :version, :timestamp, :game_session_id])
    |> validate_required([:type, :data, :version, :timestamp, :game_session_id])
  end
end 