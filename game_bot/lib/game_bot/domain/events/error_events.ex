defmodule GameBot.Domain.Events.ErrorEvents do
  @moduledoc """
  Defines error-related events in the domain.
  """

  alias GameBot.Domain.Events.{Metadata, EventStructure, GameEvents, ValidationHelpers}

  defmodule CommandError do
    @moduledoc """
    Emitted when a command fails to execute.

    Base fields:
    - game_id: Unique identifier for the game (optional)
    - guild_id: Discord guild ID where the error occurred
    - timestamp: When the error occurred
    - metadata: Additional context about the event

    Event-specific fields:
    - command_name: Name of the command that failed
    - error_code: Error code for the failure
    - error_message: Human-readable error message
    - user_id: ID of the user who issued the command
    - channel_id: ID of the channel where the command was issued
    """
    use GameBot.Domain.Events.BaseEvent,
      event_type: "command_error",
      version: 1,
      fields: [
        field(:command_name, :string),
        field(:error_code, :string),
        field(:error_message, :string),
        field(:user_id, :string),
        field(:channel_id, :string)
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
      command_name: String.t(),
      error_code: String.t(),
      error_message: String.t(),
      user_id: String.t(),
      channel_id: String.t(),

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
      [:guild_id, :command_name, :error_code, :error_message, :user_id, :channel_id, :metadata]
    end

    @doc """
    Validates custom fields specific to this event.
    """
    @impl true
    @spec validate_custom_fields(Ecto.Changeset.t()) :: Ecto.Changeset.t()
    def validate_custom_fields(changeset) do
      super(changeset)
      |> validate_required([:command_name, :error_code, :error_message, :user_id, :channel_id])
    end

    @doc """
    Validates the event.

    Implements the GameEvents.validate/1 callback.
    """
    @impl GameEvents
    @spec validate(t()) :: :ok | {:error, String.t()}
    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event),
           :ok <- ValidationHelpers.validate_string_value(event.command_name),
           :ok <- ValidationHelpers.validate_string_value(event.error_code),
           :ok <- ValidationHelpers.validate_string_value(event.error_message),
           :ok <- ValidationHelpers.validate_string_value(event.user_id),
           :ok <- ValidationHelpers.validate_string_value(event.channel_id) do
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
        "command_name" => event.command_name,
        "error_code" => event.error_code,
        "error_message" => event.error_message,
        "user_id" => event.user_id,
        "channel_id" => event.channel_id,
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
        command_name: data["command_name"],
        error_code: data["error_code"],
        error_message: data["error_message"],
        user_id: data["user_id"],
        channel_id: data["channel_id"],
        metadata: data["metadata"] || %{},
        guild_id: data["guild_id"],
        game_id: data["game_id"],
        timestamp: GameEvents.parse_timestamp(data["timestamp"]),
        type: "command_error",
        version: 1
      }
    end

    @doc """
    Creates a new CommandError event.

    ## Parameters
      * `command_name` - Name of the command that failed
      * `error_code` - Error code for the failure
      * `error_message` - Human-readable error message
      * `user_id` - ID of the user who issued the command
      * `channel_id` - ID of the channel where the command was issued
      * `guild_id` - Discord guild ID where the error occurred
      * `game_id` - Unique identifier for the game (optional)
      * `metadata` - Additional metadata for the event (optional)

    ## Returns
      * `{:ok, %CommandError{}}` - A new CommandError event struct
      * `{:error, reason}` - If validation fails
    """
    @spec new(
      String.t(),
      String.t(),
      String.t(),
      String.t(),
      String.t(),
      String.t(),
      String.t() | nil,
      map()
    ) :: {:ok, t()} | {:error, String.t()}
    def new(
      command_name,
      error_code,
      error_message,
      user_id,
      channel_id,
      guild_id,
      game_id \\ nil,
      metadata \\ %{}
    ) do
      now = DateTime.utc_now()

      # Ensure metadata has required fields
      enhanced_metadata = ValidationHelpers.ensure_metadata_fields(metadata, guild_id)

      attrs = %{
        command_name: command_name,
        error_code: error_code,
        error_message: error_message,
        user_id: user_id,
        channel_id: channel_id,
        guild_id: guild_id,
        game_id: game_id,
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

  defmodule SystemError do
    @moduledoc """
    Emitted when a system error occurs.

    Base fields:
    - game_id: Unique identifier for the game (optional)
    - guild_id: Discord guild ID where the error occurred (optional)
    - timestamp: When the error occurred
    - metadata: Additional context about the event

    Event-specific fields:
    - error_type: Type of error that occurred
    - error_message: Human-readable error message
    - stacktrace: Error stacktrace (optional)
    - context: Additional context about the error
    """
    use GameBot.Domain.Events.BaseEvent,
      event_type: "system_error",
      version: 1,
      fields: [
        field(:error_type, :string),
        field(:error_message, :string),
        field(:stacktrace, :string),
        field(:context, :map)
      ]

    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      # Base fields (from BaseEvent)
      id: Ecto.UUID.t(),
      game_id: String.t() | nil,
      guild_id: String.t() | nil,
      mode: atom() | nil,
      round_number: integer() | nil,
      timestamp: DateTime.t(),
      metadata: Metadata.t(),
      type: String.t(),
      version: pos_integer(),

      # Custom fields
      error_type: String.t(),
      error_message: String.t(),
      stacktrace: String.t() | nil,
      context: map(),

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
      [:error_type, :error_message, :context, :metadata]
    end

    @doc """
    Validates custom fields specific to this event.
    """
    @impl true
    @spec validate_custom_fields(Ecto.Changeset.t()) :: Ecto.Changeset.t()
    def validate_custom_fields(changeset) do
      super(changeset)
      |> validate_required([:error_type, :error_message, :context])
    end

    @doc """
    Validates the event.

    Implements the GameEvents.validate/1 callback.
    """
    @impl GameEvents
    @spec validate(t()) :: :ok | {:error, String.t()}
    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event),
           :ok <- ValidationHelpers.validate_string_value(event.error_type),
           :ok <- ValidationHelpers.validate_string_value(event.error_message),
           :ok <- validate_context(event.context) do
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
        "error_type" => event.error_type,
        "error_message" => event.error_message,
        "stacktrace" => event.stacktrace,
        "context" => event.context,
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
        error_type: data["error_type"],
        error_message: data["error_message"],
        stacktrace: data["stacktrace"],
        context: data["context"] || %{},
        metadata: data["metadata"] || %{},
        guild_id: data["guild_id"],
        game_id: data["game_id"],
        timestamp: GameEvents.parse_timestamp(data["timestamp"]),
        type: "system_error",
        version: 1
      }
    end

    @doc """
    Creates a new SystemError event.

    ## Parameters
      * `error_type` - Type of error that occurred
      * `error_message` - Human-readable error message
      * `context` - Additional context about the error
      * `stacktrace` - Error stacktrace (optional)
      * `guild_id` - Discord guild ID where the error occurred (optional)
      * `game_id` - Unique identifier for the game (optional)
      * `metadata` - Additional metadata for the event (optional)

    ## Returns
      * `{:ok, %SystemError{}}` - A new SystemError event struct
      * `{:error, reason}` - If validation fails
    """
    @spec new(
      String.t(),
      String.t(),
      map(),
      String.t() | nil,
      String.t() | nil,
      String.t() | nil,
      map()
    ) :: {:ok, t()} | {:error, String.t()}
    def new(
      error_type,
      error_message,
      context,
      stacktrace \\ nil,
      guild_id \\ nil,
      game_id \\ nil,
      metadata \\ %{}
    ) do
      now = DateTime.utc_now()

      # Ensure metadata has required fields
      enhanced_metadata = if guild_id do
        ValidationHelpers.ensure_metadata_fields(metadata, guild_id)
      else
        metadata
        |> Map.put_new(:source_id, UUID.uuid4())
        |> Map.put_new(:correlation_id, UUID.uuid4())
      end

      attrs = %{
        error_type: error_type,
        error_message: error_message,
        context: context,
        stacktrace: stacktrace,
        guild_id: guild_id,
        game_id: game_id,
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

    @spec validate_context(map() | nil) :: :ok | {:error, String.t()}
    defp validate_context(nil), do: {:error, "context is required"}
    defp validate_context(context) when is_map(context), do: :ok
    defp validate_context(_), do: {:error, "context must be a map"}
  end
end
