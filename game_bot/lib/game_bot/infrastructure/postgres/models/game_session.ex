defmodule GameBot.Infrastructure.Postgres.Models.GameSession do
  @moduledoc """
  Ecto schema for game sessions.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "game_sessions" do
    field :channel_id, :string
    field :mode, :string
    field :status, :string, default: "waiting_for_players"
    field :max_rounds, :integer, default: 10
    field :rounds_completed, :integer, default: 0
    field :metadata, :map, default: %{}
    
    # Associations
    has_many :events, GameBot.Infrastructure.Postgres.Models.Event
    many_to_many :players, GameBot.Infrastructure.Postgres.Models.User, join_through: "game_participants"
    
    timestamps()
  end
  
  @doc """
  Changeset for creating and updating game sessions.
  """
  def changeset(game_session, attrs) do
    game_session
    |> cast(attrs, [:channel_id, :mode, :status, :max_rounds, :rounds_completed, :metadata])
    |> validate_required([:channel_id, :mode])
    |> validate_inclusion(:status, ["waiting_for_players", "in_progress", "completed"])
    |> validate_inclusion(:mode, ["two_player", "knockout", "race", "golf_race", "longform"])
  end
end 