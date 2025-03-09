defmodule GameBot.Replay.ReplayAccessLog do
  @moduledoc """
  Schema for the replay_access_logs table, which tracks replay access events.

  This table logs each time a user accesses or interacts with a replay,
  providing analytics and usage patterns data.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @access_types [
    :view,        # Viewed replay details
    :share,       # Shared replay with others
    :download,    # Downloaded replay data
    :embed        # Used replay in embed
  ]

  schema "replay_access_logs" do
    field :replay_id, :binary_id
    field :user_id, :string
    field :guild_id, :string
    field :access_type, Ecto.Enum, values: @access_types
    field :client_info, :map
    field :ip_address, :string
    field :accessed_at, :utc_datetime_usec

    timestamps()
  end

  @doc """
  Changeset for creating a new access log entry.
  """
  def changeset(log, attrs) do
    log
    |> cast(attrs, [
      :replay_id,
      :user_id,
      :guild_id,
      :access_type,
      :client_info,
      :ip_address,
      :accessed_at
    ])
    |> validate_required([
      :replay_id,
      :user_id,
      :guild_id,
      :access_type
    ])
    |> put_change_if_missing(:accessed_at, DateTime.utc_now())
    |> validate_user_id()
    |> validate_guild_id()
  end

  # Set a field value if it's not already present
  defp put_change_if_missing(changeset, field, value) do
    if get_field(changeset, field) do
      changeset
    else
      put_change(changeset, field, value)
    end
  end

  @doc """
  Creates a new access log entry with the current timestamp.

  ## Parameters
    - replay_id: ID of the accessed replay
    - user_id: ID of the user accessing the replay
    - guild_id: ID of the guild where the access occurred
    - access_type: Type of access (:view, :share, :download, :embed)
    - client_info: Optional client information
    - ip_address: Optional IP address

  ## Returns
    - A changeset ready for insertion
  """
  @spec log_access(binary(), String.t(), String.t(), atom(), map() | nil, String.t() | nil) ::
    Ecto.Changeset.t()
  def log_access(replay_id, user_id, guild_id, access_type, client_info \\ nil, ip_address \\ nil) do
    attrs = %{
      replay_id: replay_id,
      user_id: user_id,
      guild_id: guild_id,
      access_type: access_type,
      client_info: client_info,
      ip_address: ip_address,
      accessed_at: DateTime.utc_now()
    }

    changeset(%__MODULE__{}, attrs)
  end

  # Additional validations

  defp validate_user_id(changeset) do
    validate_format(changeset, :user_id, ~r/^\d+$/,
      message: "must be a valid Discord user ID")
  end

  defp validate_guild_id(changeset) do
    validate_format(changeset, :guild_id, ~r/^\d+$/,
      message: "must be a valid Discord guild ID")
  end
end
