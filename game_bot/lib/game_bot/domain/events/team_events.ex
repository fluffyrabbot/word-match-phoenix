defmodule GameBot.Domain.Events.TeamEvents do
  @moduledoc """
  Defines team-related events in the domain.
  """

  alias GameBot.Domain.Events.{Metadata, EventStructure, GameEvents, ValidationHelpers}

  defmodule TeamCreated do
    @moduledoc """
    Emitted when a new team is created.

    Base fields:
    - game_id: Unique identifier for the game (optional for team events)
    - guild_id: Discord guild ID where the team is being created
    - timestamp: When the team was created
    - metadata: Additional context about the event

    Event-specific fields:
    - team_id: Unique identifier for the team
    - name: Name of the team
    - player_ids: List of player IDs in the team
    - created_at: When the team was created (same as timestamp)
    """
    use GameBot.Domain.Events.BaseEvent,
      event_type: "team_created",
      version: 1,
      fields: [
        field(:team_id, :string),
        field(:name, :string),
        field(:player_ids, {:array, :string}),
        field(:created_at, :utc_datetime_usec)
      ]

    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      # Base fields (from BaseEvent)
      id: Ecto.UUID.t(),
      game_id: String.t() | nil,
      guild_id: String.t(),
      mode: atom() | nil,
      round_number: integer() | nil,
      timestamp: DateTime.t(),
      metadata: Metadata.t(),
      type: String.t(),
      version: pos_integer(),

      # Custom fields
      team_id: String.t(),
      name: String.t(),
      player_ids: [String.t()],
      created_at: DateTime.t(),

      # Ecto timestamps
      inserted_at: DateTime.t() | nil,
      updated_at: DateTime.t() | nil
    }

    @doc """
    Returns the list of required fields for this event.
    """
    @impl true
    @spec required_fields() :: [atom()]
    def required_fields do
      [:guild_id, :team_id, :name, :player_ids, :created_at, :metadata]
    end

    @doc """
    Validates custom fields specific to this event.
    """
    @spec validate_custom_fields(Ecto.Changeset.t()) :: Ecto.Changeset.t()
    def validate_custom_fields(changeset) do
      super(changeset)
      |> validate_required([:team_id, :name, :player_ids, :created_at])
      |> validate_length(:player_ids, is: 2, message: "team must have exactly 2 players")
      |> ValidationHelpers.validate_not_future(:created_at)
    end

    @doc """
    Validates the event.

    Implements the GameEvents.validate/1 callback.
    """
    @impl GameEvents
    @spec validate(t()) :: :ok | {:error, String.t()}
    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event),
           :ok <- validate_team_id(event.team_id),
           :ok <- validate_name(event.name),
           :ok <- validate_player_ids(event.player_ids),
           :ok <- validate_created_at(event.created_at) do
        :ok
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
        "team_id" => event.team_id,
        "name" => event.name,
        "player_ids" => event.player_ids,
        "created_at" => DateTime.to_iso8601(event.created_at),
        "metadata" => event.metadata || %{},
        "guild_id" => event.guild_id,
        "game_id" => event.game_id
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
        team_id: data["team_id"],
        name: data["name"],
        player_ids: data["player_ids"],
        created_at: GameEvents.parse_timestamp(data["created_at"]),
        metadata: data["metadata"] || %{},
        guild_id: data["guild_id"],
        game_id: data["game_id"],
        timestamp: GameEvents.parse_timestamp(data["created_at"]),
        type: "team_created",
        version: 1
      }
    end

    @doc """
    Creates a new TeamCreated event with the specified parameters.

    ## Parameters
      * `team_id` - Unique identifier for the team
      * `name` - Name of the team
      * `player_ids` - List of player IDs in the team
      * `guild_id` - Discord guild ID where the team is being created
      * `metadata` - Additional metadata for the event (optional)

    ## Returns
      * `{:ok, %TeamCreated{}}` - A new TeamCreated event struct
      * `{:error, reason}` - If validation fails
    """
    @spec new(String.t(), String.t(), [String.t()], String.t(), map()) :: {:ok, t()} | {:error, String.t()}
    def new(team_id, name, player_ids, guild_id, metadata \\ %{}) do
      now = DateTime.utc_now()

      # Ensure metadata has required fields
      enhanced_metadata = ValidationHelpers.ensure_metadata_fields(metadata, guild_id)

      attrs = %{
        team_id: team_id,
        name: name,
        player_ids: player_ids,
        guild_id: guild_id,
        mode: nil,  # Explicitly set mode to nil
        created_at: now,
        timestamp: now,
        metadata: enhanced_metadata
      }

      # Create and validate the event
      event = struct!(__MODULE__, attrs)

      case validate(event) do
        :ok -> {:ok, event}
        error -> error
      end
    end

    # Private validation functions

    @spec validate_team_id(String.t() | nil) :: :ok | {:error, String.t()}
    defp validate_team_id(nil), do: {:error, "team_id is required"}
    defp validate_team_id(id) when is_binary(id) and byte_size(id) > 0, do: :ok
    defp validate_team_id(_), do: {:error, "team_id must be a non-empty string"}

    @spec validate_name(String.t() | nil) :: :ok | {:error, String.t()}
    defp validate_name(nil), do: {:error, "name is required"}
    defp validate_name(name) when is_binary(name) and byte_size(name) > 0, do: :ok
    defp validate_name(_), do: {:error, "name must be a non-empty string"}

    @spec validate_player_ids([String.t()] | nil) :: :ok | {:error, String.t()}
    defp validate_player_ids(nil), do: {:error, "player_ids is required"}
    defp validate_player_ids(ids) when is_list(ids) and length(ids) == 2, do: :ok
    defp validate_player_ids(ids) when is_list(ids), do: {:error, "team must have exactly 2 players"}
    defp validate_player_ids(_), do: {:error, "player_ids must be a list"}

    @spec validate_created_at(DateTime.t() | nil) :: :ok | {:error, String.t()}
    defp validate_created_at(nil), do: {:error, "created_at is required"}
    defp validate_created_at(%DateTime{} = dt) do
      ValidationHelpers.validate_datetime_not_future(dt)
    end
    defp validate_created_at(_), do: {:error, "created_at must be a DateTime"}
  end

  defmodule TeamUpdated do
    @moduledoc """
    Emitted when a team is updated.

    Base fields:
    - game_id: Unique identifier for the game (optional for team events)
    - guild_id: Discord guild ID where the team exists
    - timestamp: When the team was updated
    - metadata: Additional context about the event

    Event-specific fields:
    - team_id: Unique identifier for the team
    - name: Updated name of the team
    - team_updated_at: When the team was updated (same as timestamp)
    """
    use GameBot.Domain.Events.BaseEvent,
      event_type: "team_updated",
      version: 1,
      fields: [
        field(:team_id, :string),
        field(:name, :string),
        field(:team_updated_at, :utc_datetime_usec)
      ]

    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      # Base fields (from BaseEvent)
      id: Ecto.UUID.t(),
      game_id: String.t() | nil,
      guild_id: String.t(),
      mode: atom() | nil,
      round_number: integer() | nil,
      timestamp: DateTime.t(),
      metadata: Metadata.t(),
      type: String.t(),
      version: pos_integer(),

      # Custom fields
      team_id: String.t(),
      name: String.t(),
      team_updated_at: DateTime.t(),

      # Ecto timestamps
      inserted_at: DateTime.t() | nil,
      updated_at: DateTime.t() | nil
    }

    @doc """
    Returns the list of required fields for this event.
    """
    @impl true
    @spec required_fields() :: [atom()]
    def required_fields do
      [:guild_id, :team_id, :name, :team_updated_at, :metadata]
    end

    @doc """
    Validates custom fields specific to this event.
    """
    @impl true
    @spec validate_custom_fields(Ecto.Changeset.t()) :: Ecto.Changeset.t()
    def validate_custom_fields(changeset) do
      super(changeset)
      |> validate_required([:team_id, :name, :team_updated_at])
      |> ValidationHelpers.validate_not_future(:team_updated_at)
    end

    @doc """
    Validates the event.

    Implements the GameEvents.validate/1 callback.
    """
    @impl GameEvents
    @spec validate(t()) :: :ok | {:error, String.t()}
    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event),
           :ok <- ValidationHelpers.validate_string_value(event.team_id),
           :ok <- ValidationHelpers.validate_string_value(event.name),
           :ok <- ValidationHelpers.validate_datetime_not_future(event.team_updated_at) do
        :ok
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
        "team_id" => event.team_id,
        "name" => event.name,
        "updated_at" => DateTime.to_iso8601(event.team_updated_at),
        "metadata" => event.metadata || %{},
        "guild_id" => event.guild_id,
        "game_id" => event.game_id
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
        team_id: data["team_id"],
        name: data["name"],
        team_updated_at: GameEvents.parse_timestamp(data["updated_at"]),
        metadata: data["metadata"] || %{},
        guild_id: data["guild_id"],
        game_id: data["game_id"],
        timestamp: GameEvents.parse_timestamp(data["updated_at"]),
        type: "team_updated",
        version: 1
      }
    end

    @doc """
    Creates a new TeamUpdated event.

    ## Parameters
      * `team_id` - Unique identifier for the team
      * `name` - Updated name of the team
      * `guild_id` - Discord guild ID where the team exists
      * `metadata` - Additional metadata for the event (optional)

    ## Returns
      * `{:ok, %TeamUpdated{}}` - A new TeamUpdated event struct
      * `{:error, reason}` - If validation fails
    """
    @spec new(String.t(), String.t(), String.t(), map()) :: {:ok, t()} | {:error, String.t()}
    def new(team_id, name, guild_id, metadata \\ %{}) do
      now = DateTime.utc_now()

      # Ensure metadata has required fields
      enhanced_metadata = ValidationHelpers.ensure_metadata_fields(metadata, guild_id)

      attrs = %{
        team_id: team_id,
        name: name,
        guild_id: guild_id,
        mode: nil,  # Explicitly set mode to nil
        team_updated_at: now,
        timestamp: now,
        metadata: enhanced_metadata
      }

      # Create and validate the event
      event = struct!(__MODULE__, attrs)

      case validate(event) do
        :ok -> {:ok, event}
        error -> error
      end
    end
  end

  defmodule TeamMemberAdded do
    @moduledoc """
    Emitted when a member is added to a team.

    Base fields:
    - game_id: Unique identifier for the game (optional for team events)
    - guild_id: Discord guild ID where the team exists
    - timestamp: When the member was added
    - metadata: Additional context about the event

    Event-specific fields:
    - team_id: Unique identifier for the team
    - player_id: ID of the player being added
    - added_by: ID of the user who added the player
    - added_at: When the player was added (same as timestamp)
    """
    use GameBot.Domain.Events.BaseEvent,
      event_type: "team_member_added",
      version: 1,
      fields: [
        field(:team_id, :string),
        field(:player_id, :string),
        field(:added_by, :string),
        field(:added_at, :utc_datetime_usec)
      ]

    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      # Base fields (from BaseEvent)
      id: Ecto.UUID.t(),
      game_id: String.t() | nil,
      guild_id: String.t(),
      mode: atom() | nil,
      round_number: integer() | nil,
      timestamp: DateTime.t(),
      metadata: Metadata.t(),
      type: String.t(),
      version: pos_integer(),

      # Custom fields
      team_id: String.t(),
      player_id: String.t(),
      added_by: String.t(),
      added_at: DateTime.t(),

      # Ecto timestamps
      inserted_at: DateTime.t() | nil,
      updated_at: DateTime.t() | nil
    }

    @doc """
    Returns the list of required fields for this event.
    """
    @impl true
    @spec required_fields() :: [atom()]
    def required_fields do
      [:guild_id, :team_id, :player_id, :added_by, :added_at, :metadata]
    end

    @doc """
    Validates custom fields specific to this event.
    """
    @impl true
    @spec validate_custom_fields(Ecto.Changeset.t()) :: Ecto.Changeset.t()
    def validate_custom_fields(changeset) do
      super(changeset)
      |> validate_required([:team_id, :player_id, :added_by, :added_at])
      |> ValidationHelpers.validate_not_future(:added_at)
    end

    @doc """
    Validates the event.

    Implements the GameEvents.validate/1 callback.
    """
    @impl GameEvents
    @spec validate(t()) :: :ok | {:error, String.t()}
    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event),
           :ok <- ValidationHelpers.validate_string_value(event.team_id),
           :ok <- ValidationHelpers.validate_string_value(event.player_id),
           :ok <- ValidationHelpers.validate_string_value(event.added_by),
           :ok <- ValidationHelpers.validate_datetime_not_future(event.added_at) do
        :ok
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
        "team_id" => event.team_id,
        "player_id" => event.player_id,
        "added_by" => event.added_by,
        "added_at" => DateTime.to_iso8601(event.added_at),
        "metadata" => event.metadata || %{},
        "guild_id" => event.guild_id,
        "game_id" => event.game_id
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
        team_id: data["team_id"],
        player_id: data["player_id"],
        added_by: data["added_by"],
        added_at: GameEvents.parse_timestamp(data["added_at"]),
        metadata: data["metadata"] || %{},
        guild_id: data["guild_id"],
        game_id: data["game_id"],
        timestamp: GameEvents.parse_timestamp(data["added_at"]),
        type: "team_member_added",
        version: 1
      }
    end

    @doc """
    Creates a new TeamMemberAdded event.

    ## Parameters
      * `team_id` - Unique identifier for the team
      * `player_id` - ID of the player being added
      * `added_by` - ID of the user who added the player
      * `guild_id` - Discord guild ID where the team exists
      * `metadata` - Additional metadata for the event (optional)

    ## Returns
      * `{:ok, %TeamMemberAdded{}}` - A new TeamMemberAdded event struct
      * `{:error, reason}` - If validation fails
    """
    @spec new(String.t(), String.t(), String.t(), String.t(), map()) :: {:ok, t()} | {:error, String.t()}
    def new(team_id, player_id, added_by, guild_id, metadata \\ %{}) do
      now = DateTime.utc_now()

      # Ensure metadata has required fields
      enhanced_metadata = ValidationHelpers.ensure_metadata_fields(metadata, guild_id)

      attrs = %{
        team_id: team_id,
        player_id: player_id,
        added_by: added_by,
        guild_id: guild_id,
        mode: nil,  # Explicitly set mode to nil
        added_at: now,
        timestamp: now,
        metadata: enhanced_metadata
      }

      # Create and validate the event
      event = struct!(__MODULE__, attrs)

      case validate(event) do
        :ok -> {:ok, event}
        error -> error
      end
    end
  end

  defmodule TeamMemberRemoved do
    @moduledoc """
    Emitted when a member is removed from a team.

    Base fields:
    - game_id: Unique identifier for the game (optional for team events)
    - guild_id: Discord guild ID where the team exists
    - timestamp: When the member was removed
    - metadata: Additional context about the event

    Event-specific fields:
    - team_id: Unique identifier for the team
    - player_id: ID of the player being removed
    - removed_by: ID of the user who removed the player
    - reason: Optional reason for removal
    - removed_at: When the player was removed (same as timestamp)
    """
    use GameBot.Domain.Events.BaseEvent,
      event_type: "team_member_removed",
      version: 1,
      fields: [
        field(:team_id, :string),
        field(:player_id, :string),
        field(:removed_by, :string),
        field(:reason, :string),
        field(:removed_at, :utc_datetime_usec)
      ]

    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      # Base fields (from BaseEvent)
      id: Ecto.UUID.t(),
      game_id: String.t() | nil,
      guild_id: String.t(),
      mode: atom() | nil,
      round_number: integer() | nil,
      timestamp: DateTime.t(),
      metadata: Metadata.t(),
      type: String.t(),
      version: pos_integer(),

      # Custom fields
      team_id: String.t(),
      player_id: String.t(),
      removed_by: String.t(),
      reason: String.t() | nil,
      removed_at: DateTime.t(),

      # Ecto timestamps
      inserted_at: DateTime.t() | nil,
      updated_at: DateTime.t() | nil
    }

    @doc """
    Returns the list of required fields for this event.
    """
    @impl true
    @spec required_fields() :: [atom()]
    def required_fields do
      [:guild_id, :team_id, :player_id, :removed_by, :removed_at, :metadata]
    end

    @doc """
    Validates custom fields specific to this event.
    """
    @impl true
    @spec validate_custom_fields(Ecto.Changeset.t()) :: Ecto.Changeset.t()
    def validate_custom_fields(changeset) do
      super(changeset)
      |> validate_required([:team_id, :player_id, :removed_by, :removed_at])
      |> ValidationHelpers.validate_not_future(:removed_at)
    end

    @doc """
    Validates the event.

    Implements the GameEvents.validate/1 callback.
    """
    @impl GameEvents
    @spec validate(t()) :: :ok | {:error, String.t()}
    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event),
           :ok <- ValidationHelpers.validate_string_value(event.team_id),
           :ok <- ValidationHelpers.validate_string_value(event.player_id),
           :ok <- ValidationHelpers.validate_string_value(event.removed_by),
           :ok <- ValidationHelpers.validate_datetime_not_future(event.removed_at) do
        :ok
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
        "team_id" => event.team_id,
        "player_id" => event.player_id,
        "removed_by" => event.removed_by,
        "reason" => event.reason,
        "removed_at" => DateTime.to_iso8601(event.removed_at),
        "metadata" => event.metadata || %{},
        "guild_id" => event.guild_id,
        "game_id" => event.game_id
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
        team_id: data["team_id"],
        player_id: data["player_id"],
        removed_by: data["removed_by"],
        reason: data["reason"],
        removed_at: GameEvents.parse_timestamp(data["removed_at"]),
        metadata: data["metadata"] || %{},
        guild_id: data["guild_id"],
        game_id: data["game_id"],
        timestamp: GameEvents.parse_timestamp(data["removed_at"]),
        type: "team_member_removed",
        version: 1
      }
    end

    @doc """
    Creates a new TeamMemberRemoved event.

    ## Parameters
      * `team_id` - Unique identifier for the team
      * `player_id` - ID of the player being removed
      * `removed_by` - ID of the user who removed the player
      * `reason` - Optional reason for removal
      * `guild_id` - Discord guild ID where the team exists
      * `metadata` - Additional metadata for the event (optional)

    ## Returns
      * `{:ok, %TeamMemberRemoved{}}` - A new TeamMemberRemoved event struct
      * `{:error, reason}` - If validation fails
    """
    @spec new(String.t(), String.t(), String.t(), String.t() | nil, String.t(), map()) :: {:ok, t()} | {:error, String.t()}
    def new(team_id, player_id, removed_by, reason \\ nil, guild_id, metadata \\ %{}) do
      now = DateTime.utc_now()

      # Ensure metadata has required fields
      enhanced_metadata = ValidationHelpers.ensure_metadata_fields(metadata, guild_id)

      attrs = %{
        team_id: team_id,
        player_id: player_id,
        removed_by: removed_by,
        reason: reason,
        guild_id: guild_id,
        mode: nil,  # Explicitly set mode to nil
        removed_at: now,
        timestamp: now,
        metadata: enhanced_metadata
      }

      # Create and validate the event
      event = struct!(__MODULE__, attrs)

      case validate(event) do
        :ok -> {:ok, event}
        error -> error
      end
    end
  end
end
