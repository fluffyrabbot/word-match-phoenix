defmodule GameBot.Domain.Events.BaseEvent do
  @moduledoc """
  Base behaviour that all events must implement.
  Provides standard interface for validation, serialization, and application.

  When creating a new event type, use this module as the foundation:

  ```elixir
  defmodule MyEvent do
    use GameBot.Domain.Events.BaseEvent, type: "my_event", version: 1

    @required_fields [:game_id, :guild_id, :mode, :timestamp, :metadata]
    defstruct @required_fields ++ [:optional_field]

    # Override validation if needed
    @impl true
    def validate(event) do
      with :ok <- EventStructure.validate_fields(event, @required_fields),
           :ok <- super(event) do
        :ok
      end
    end

    # Event constructor
    def new(game_id, guild_id, mode, metadata, opts \\ []) do
      %__MODULE__{
        game_id: game_id,
        guild_id: guild_id,
        mode: mode,
        optional_field: Keyword.get(opts, :optional_field),
        metadata: metadata,
        timestamp: EventStructure.create_timestamp()
      }
    end
  end
  """

  alias GameBot.Domain.Events.EventStructure
  alias GameBot.Domain.Events.Metadata

  # Define a generic event type for use in callbacks
  @typedoc """
  Generic event type that can be specialized by implementing modules.
  This is used as a placeholder in callback definitions.
  """
  @type t :: %{
    optional(atom()) => any(),
    required(:metadata) => map()
  }

  # Define callbacks that implementing modules must provide
  @callback validate(t()) :: :ok | {:error, term()}
  @callback serialize(t()) :: map()
  @callback deserialize(map()) :: t()

  # Optional callback for applying event to state
  @callback apply(state :: term(), t()) ::
    {:ok, new_state :: term()} |
    {:ok, new_state :: term(), [term()]} |
    {:error, term()}

  @optional_callbacks [apply: 2]

  defmacro __using__(opts) do
    event_type = Keyword.get(opts, :type, "unknown")
    version = Keyword.get(opts, :version, 1)

    quote do
      @behaviour GameBot.Domain.Events.BaseEvent
      import GameBot.Domain.Events.EventStructure

      @event_type unquote(event_type)
      @event_version unquote(version)

      def type, do: @event_type
      def version, do: @event_version

      # Default implementations
      @impl GameBot.Domain.Events.BaseEvent
      def validate(event) do
        EventStructure.validate(event)
      end

      @impl GameBot.Domain.Events.BaseEvent
      def serialize(event) do
        # Convert struct to plain map
        map = Map.from_struct(event)
        # Remove keys with nil values
        map = Enum.filter(map, fn {_k, v} -> v != nil end) |> Map.new()
        # Add event type and version
        Map.merge(map, %{
          event_type: @event_type,
          event_version: @event_version
        })
      end

      @impl GameBot.Domain.Events.BaseEvent
      def deserialize(data) do
        # Allow for both string and atom keys
        data =
          data
          |> Map.new(fn {k, v} when is_binary(k) -> {String.to_atom(k), v}
                        {k, v} -> {k, v}
                     end)
          # Filter out event_type and event_version
          |> Map.drop([:event_type, :event_version, "event_type", "event_version"])

        # Convert to struct
        struct(__MODULE__, data)
      end

      # Override these in specific event implementations
      defoverridable validate: 1, serialize: 1, deserialize: 1
    end
  end

  @doc """
  Creates a base event with standard fields.
  """
  def create_base(fields) do
    fields
    |> Map.put_new(:timestamp, EventStructure.create_timestamp())
  end

  @doc """
  Adds metadata to an event.
  """
  def with_metadata(event, metadata) do
    Map.put(event, :metadata, metadata)
  end

  @doc """
  Extracts the event ID from an event.
  """
  def event_id(%{metadata: %{source_id: id}}), do: id
  def event_id(%{metadata: %{"source_id" => id}}), do: id
  def event_id(_), do: nil

  @doc """
  Extracts the correlation ID from an event.
  """
  def correlation_id(%{metadata: %{correlation_id: id}}), do: id
  def correlation_id(%{metadata: %{"correlation_id" => id}}), do: id
  def correlation_id(_), do: nil

  @doc """
  Extracts the causation ID from an event.
  """
  def causation_id(%{metadata: %{causation_id: id}}), do: id
  def causation_id(%{metadata: %{"causation_id" => id}}), do: id
  def causation_id(_), do: nil
end
