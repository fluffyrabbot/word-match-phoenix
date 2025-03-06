defmodule GameBot.Domain.Events.UserEvents do
  @moduledoc """
  User-related events for the game bot.
  These events relate to user registration, profile updates, and preference changes.
  """

  alias GameBot.Domain.Events.GameEvents

  @type metadata :: %{String.t() => any()}

  defmodule UserRegistered do
    @moduledoc "Emitted when a user registers with the bot"

    @type t :: %__MODULE__{
      user_id: String.t(),
      guild_id: String.t(),
      username: String.t(),
      display_name: String.t() | nil,
      created_at: DateTime.t(),
      metadata: %{String.t() => any()}
    }
    defstruct [:user_id, :guild_id, :username, :display_name, :created_at, :metadata]

    def event_type(), do: "user_registered"
    def event_version(), do: 1

    def validate(%__MODULE__{} = event) do
      cond do
        is_nil(event.user_id) -> {:error, "user_id is required"}
        is_nil(event.guild_id) -> {:error, "guild_id is required"}
        is_nil(event.username) -> {:error, "username is required"}
        is_nil(event.created_at) -> {:error, "created_at is required"}
        true -> :ok
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "user_id" => event.user_id,
        "guild_id" => event.guild_id,
        "username" => event.username,
        "display_name" => event.display_name,
        "created_at" => DateTime.to_iso8601(event.created_at),
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        user_id: data["user_id"],
        guild_id: data["guild_id"],
        username: data["username"],
        display_name: data["display_name"],
        created_at: GameEvents.parse_timestamp(data["created_at"]),
        metadata: data["metadata"] || %{}
      }
    end
  end

  defmodule UserProfileUpdated do
    @moduledoc "Emitted when a user updates their profile"

    @type t :: %__MODULE__{
      user_id: String.t(),
      guild_id: String.t(),
      display_name: String.t() | nil,
      updated_at: DateTime.t(),
      metadata: %{String.t() => any()}
    }
    defstruct [:user_id, :guild_id, :display_name, :updated_at, :metadata]

    def event_type(), do: "user_profile_updated"
    def event_version(), do: 1

    def validate(%__MODULE__{} = event) do
      cond do
        is_nil(event.user_id) -> {:error, "user_id is required"}
        is_nil(event.guild_id) -> {:error, "guild_id is required"}
        is_nil(event.updated_at) -> {:error, "updated_at is required"}
        true -> :ok
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "user_id" => event.user_id,
        "guild_id" => event.guild_id,
        "display_name" => event.display_name,
        "updated_at" => DateTime.to_iso8601(event.updated_at),
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        user_id: data["user_id"],
        guild_id: data["guild_id"],
        display_name: data["display_name"],
        updated_at: GameEvents.parse_timestamp(data["updated_at"]),
        metadata: data["metadata"] || %{}
      }
    end
  end

  defmodule UserPreferencesChanged do
    @moduledoc "Emitted when a user changes their preferences"

    @type t :: %__MODULE__{
      user_id: String.t(),
      guild_id: String.t(),
      notification_settings: map(),
      ui_preferences: map(),
      updated_at: DateTime.t(),
      metadata: %{String.t() => any()}
    }
    defstruct [:user_id, :guild_id, :notification_settings, :ui_preferences, :updated_at, :metadata]

    def event_type(), do: "user_preferences_changed"
    def event_version(), do: 1

    def validate(%__MODULE__{} = event) do
      cond do
        is_nil(event.user_id) -> {:error, "user_id is required"}
        is_nil(event.guild_id) -> {:error, "guild_id is required"}
        is_nil(event.updated_at) -> {:error, "updated_at is required"}
        true -> :ok
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "user_id" => event.user_id,
        "guild_id" => event.guild_id,
        "notification_settings" => event.notification_settings || %{},
        "ui_preferences" => event.ui_preferences || %{},
        "updated_at" => DateTime.to_iso8601(event.updated_at),
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        user_id: data["user_id"],
        guild_id: data["guild_id"],
        notification_settings: data["notification_settings"] || %{},
        ui_preferences: data["ui_preferences"] || %{},
        updated_at: GameEvents.parse_timestamp(data["updated_at"]),
        metadata: data["metadata"] || %{}
      }
    end
  end
end
