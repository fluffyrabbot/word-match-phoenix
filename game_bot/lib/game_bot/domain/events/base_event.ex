defmodule GameBot.Domain.Events.BaseEvent do
  @moduledoc """
  Base module for all events in the system.
  Provides common functionality and ensures consistent event structure.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias GameBot.Domain.Events.{EventSerializer, EventValidator, Metadata}

  # Define base fields as a module attribute for reuse
  @base_fields [
    :game_id,
    :guild_id,
    :mode,
    :round_number,
    :timestamp,
    :metadata
  ]

  @base_required_fields [
    :game_id,
    :guild_id,
    :mode,
    :round_number,
    :timestamp
  ]

  @base_optional_fields [:metadata]

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :game_id, :string
    field :guild_id, :string
    field :mode, Ecto.Enum, values: [:two_player, :knockout, :race]
    field :round_number, :integer
    field :timestamp, :utc_datetime_usec
    field :metadata, :map
  end

  @type t :: %__MODULE__{
    id: Ecto.UUID.t(),
    game_id: String.t(),
    guild_id: String.t(),
    mode: :two_player | :knockout | :race,
    round_number: pos_integer(),
    timestamp: DateTime.t(),
    metadata: map()
  }

  # Public API for accessing base fields
  def base_fields, do: @base_fields
  def base_required_fields, do: @base_required_fields
  def base_optional_fields, do: @base_optional_fields

  @doc """
  Macro for setting up event modules with common functionality.
  """
  defmacro __using__(opts) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset

      @event_type unquote(opts[:event_type])
      @event_version unquote(opts[:version] || 1)
      @before_compile GameBot.Domain.Events.BaseEvent

      @primary_key {:id, :binary_id, autogenerate: true}
      schema "events" do
        # Base fields that all events must have
        field :game_id, :string
        field :guild_id, :string
        field :mode, Ecto.Enum, values: [:two_player, :knockout, :race]
        field :round_number, :integer
        field :timestamp, :utc_datetime_usec
        field :metadata, :map
        field :type, :string, default: @event_type
        field :version, :integer, default: @event_version

        # Allow child modules to add their own fields
        unquote(opts[:fields] || [])

        timestamps()
      end

      @doc """
      Returns the event type.
      """
      def event_type, do: @event_type

      @doc """
      Returns the event version.
      """
      def event_version, do: @event_version

      @doc """
      Creates a changeset for validating event data.
      """
      def changeset(event, attrs) do
        event
        |> cast(attrs, required_fields() ++ optional_fields())
        |> validate_required(required_fields())
        |> validate_metadata()
        |> validate_custom_fields()
      end

      @doc """
      Returns the list of required fields for this event.
      Override this function to add custom required fields.
      """
      def required_fields do
        GameBot.Domain.Events.BaseEvent.base_required_fields()
      end

      @doc """
      Returns the list of optional fields for this event.
      Override this function to add custom optional fields.
      """
      def optional_fields do
        GameBot.Domain.Events.BaseEvent.base_optional_fields()
      end

      @doc """
      Validates custom fields specific to this event type.
      Override this function to add custom validation.
      """
      def validate_custom_fields(changeset), do: changeset

      # Implement EventSerializer protocol
      defimpl GameBot.Domain.Events.EventSerializer do
        def to_map(event) do
          Map.from_struct(event)
          |> Map.update!(:timestamp, &DateTime.to_iso8601/1)
        end

        def from_map(data) do
          data = if is_map(data) and map_size(data) > 0 and is_binary(hd(Map.keys(data))),
            do: data,
            else: Map.new(data, fn {k, v} -> {to_string(k), v} end)

          struct = struct(__MODULE__)

          Map.merge(struct, Map.new(data, fn
            {"timestamp", v} -> {:timestamp, DateTime.from_iso8601!(v)}
            {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
            {k, v} -> {k, v}
          end))
        end
      end

      defoverridable [required_fields: 0, optional_fields: 0, validate_custom_fields: 1]
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @doc """
      Validates the metadata structure of an event.
      """
      def validate_metadata(changeset) do
        validate_change(changeset, :metadata, fn :metadata, metadata ->
          case validate_metadata_structure(metadata) do
            :ok -> []
            {:error, reason} -> [metadata: reason]
          end
        end)
      end

      defp validate_metadata_structure(metadata) when is_map(metadata) do
        if Map.has_key?(metadata, "guild_id") or Map.has_key?(metadata, :guild_id) or
           Map.has_key?(metadata, "source_id") or Map.has_key?(metadata, :source_id) do
          :ok
        else
          {:error, "guild_id or source_id is required in metadata"}
        end
      end
      defp validate_metadata_structure(_), do: {:error, "metadata must be a map"}
    end
  end

  @doc """
  Creates a base event with standard fields.
  """
  def create_base(fields) do
    fields
    |> Map.put_new(:timestamp, DateTime.utc_now())
    |> Map.put_new(:metadata, %{})
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
