defmodule GameBot.Domain.Projections.UserProjection do
  @moduledoc """
  Projection for building user-related read models from events.
  Ensures proper guild segregation for user data.
  """

  alias GameBot.Domain.Events.UserEvents.{
    UserRegistered,
    UserProfileUpdated,
    UserPreferencesChanged
  }

  defmodule UserView do
    @moduledoc "Read model for user data with guild context"
    @type t :: %__MODULE__{
      user_id: String.t(),
      username: String.t(),
      display_name: String.t() | nil,
      guild_id: String.t(),
      created_at: DateTime.t(),
      updated_at: DateTime.t(),
      last_active_at: DateTime.t() | nil
    }
    defstruct [:user_id, :username, :display_name, :guild_id, :created_at, :updated_at, :last_active_at]
  end

  defmodule UserPreferences do
    @moduledoc "User preferences scoped to a guild"
    @type t :: %__MODULE__{
      user_id: String.t(),
      guild_id: String.t(),
      notification_settings: map(),
      ui_preferences: map(),
      updated_at: DateTime.t()
    }
    defstruct [:user_id, :guild_id, :notification_settings, :ui_preferences, :updated_at]
  end

  def handle_event(%UserRegistered{} = event) do
    user = %UserView{
      user_id: event.user_id,
      username: event.username,
      display_name: event.display_name,
      guild_id: event.guild_id,
      created_at: event.created_at,
      updated_at: event.created_at,
      last_active_at: event.created_at
    }

    {:ok, {:user_registered, user}}
  end

  def handle_event(%UserProfileUpdated{} = event, %{user: user}) do
    updated_user = %UserView{user |
      display_name: event.display_name || user.display_name,
      updated_at: event.updated_at
    }

    {:ok, {:user_updated, updated_user}}
  end

  def handle_event(%UserPreferencesChanged{} = event) do
    preferences = %UserPreferences{
      user_id: event.user_id,
      guild_id: event.guild_id,
      notification_settings: event.notification_settings,
      ui_preferences: event.ui_preferences,
      updated_at: event.updated_at
    }

    {:ok, {:preferences_changed, preferences}}
  end

  def handle_event(_, state), do: {:ok, state}

  # Query functions - all filter by guild_id for data segregation

  def get_user(user_id, guild_id) do
    # Filter by both user_id and guild_id
    # This is a placeholder - actual implementation would depend on your storage
    {:error, :not_implemented}
  end

  def get_preferences(user_id, guild_id) do
    # Filter by both user_id and guild_id
    {:error, :not_implemented}
  end

  def list_active_users(guild_id, time_period \\ nil) do
    # Filter by guild_id and optionally by activity time period
    {:error, :not_implemented}
  end

  @doc """
  Special case for cross-guild user data where explicitly needed.
  This should be used very sparingly and only for legitimate cross-guild needs.
  """
  def get_user_cross_guild(user_id) do
    # No guild filtering - only use for legitimate cross-guild needs
    {:error, :not_implemented}
  end
end
