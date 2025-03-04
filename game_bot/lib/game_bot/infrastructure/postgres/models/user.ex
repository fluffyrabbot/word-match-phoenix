defmodule GameBot.Infrastructure.Postgres.Models.User do
  @moduledoc """
  Ecto schema for users.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :discord_id, :string
    field :username, :string
    field :games_played, :integer, default: 0
    field :wins, :integer, default: 0
    field :losses, :integer, default: 0
    field :total_score, :integer, default: 0
    
    # Associations
    many_to_many :game_sessions, GameBot.Infrastructure.Postgres.Models.GameSession, join_through: "game_participants"
    
    timestamps()
  end
  
  @doc """
  Changeset for creating and updating users.
  """
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:discord_id, :username, :games_played, :wins, :losses, :total_score])
    |> validate_required([:discord_id, :username])
    |> unique_constraint(:discord_id)
  end
end 