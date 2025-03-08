defmodule GameBot.Domain.Events.EventBuilder do
  @moduledoc """
  Helper module for standardizing event creation and validation.

  This module provides utility functions and macros to ensure consistent patterns
  for event creation, validation, and error handling across the system.

  ## Features:

  - Standardized `new/2` function pattern for all events
  - Consistent validation flow with proper error handling
  - Type-specific validation helpers
  - Metadata validation and integration

  ## Usage in Event Modules:

  ```elixir
  defmodule MyEvent do
    use GameBot.Domain.Events.EventBuilder

    # Define your event struct
    defstruct [:game_id, :guild_id, :timestamp, :metadata, :my_field]

    # Define your event types
    @type t :: %__MODULE__{
      game_id: String.t(),
      guild_id: String.t(),
      timestamp: DateTime.t(),
      metadata: metadata(),
      my_field: String.t()
    }

    # Implement required callbacks
    def event_type, do: "my_event"

    def validate_attrs(attrs) do
      with :ok <- validate_required_field(attrs, :my_field),
           :ok <- validate_string_field(attrs, :my_field) do
        :ok
      end
    end
  end
  """

  alias GameBot.Domain.Events.Metadata

  @type validation_error :: {:error, {:validation, String.t()}}

  defmacro __using__(_opts) do
    quote do
      import GameBot.Domain.Events.EventBuilder

      @type metadata :: GameBot.Domain.Events.Metadata.t()
      @type validation_error :: GameBot.Domain.Events.EventBuilder.validation_error()

      @doc """
      Creates a new event with the specified attributes and metadata.

      ## Parameters
      - attrs: A map of event attributes
      - metadata: Event metadata (map)

      ## Returns
      - `{:ok, event}` if the event creation was successful
      - `{:error, reason}` if validation fails
      """
      @spec new(map(), map()) :: {:ok, struct()} | validation_error()
      def new(attrs, metadata) when is_map(attrs) and is_map(metadata) do
        with {:ok, validated_metadata} <- validate_metadata(metadata),
             {:ok, validated_attrs} <- validate_attrs(attrs) do
          event = struct(__MODULE__, Map.merge(validated_attrs, %{
            metadata: validated_metadata,
            timestamp: Map.get(attrs, :timestamp, DateTime.utc_now())
          }))

          {:ok, event}
        end
      end

      @doc """
      Creates a new event or raises an error if validation fails.

      ## Parameters
      - attrs: A map of event attributes
      - metadata: Event metadata (map)

      ## Returns
      - event struct if successful

      ## Raises
      - ArgumentError if validation fails
      """
      @spec new!(map(), map()) :: struct()
      def new!(attrs, metadata) when is_map(attrs) and is_map(metadata) do
        case new(attrs, metadata) do
          {:ok, event} -> event
          {:error, reason} -> raise ArgumentError, "Invalid event: #{inspect(reason)}"
        end
      end

      # Default implementations

      @doc """
      Validates the event attributes.
      Override this function to add custom validation logic.
      """
      @spec validate_attrs(map()) :: {:ok, map()} | validation_error()
      def validate_attrs(attrs) when is_map(attrs) do
        with :ok <- validate_required_field(attrs, :game_id),
             :ok <- validate_required_field(attrs, :guild_id),
             :ok <- validate_string_field(attrs, :game_id),
             :ok <- validate_string_field(attrs, :guild_id) do
          {:ok, attrs}
        end
      end

      @doc """
      Returns the current version of this event type.
      Default is 1. Override for versioned events.
      """
      @spec event_version() :: pos_integer()
      def event_version, do: 1

      @doc """
      Validates the event metadata.
      By default, uses Metadata.validate/1.
      """
      @spec validate_metadata(map()) :: {:ok, map()} | validation_error()
      def validate_metadata(metadata) when is_map(metadata) do
        case Metadata.validate(metadata) do
          :ok -> {:ok, metadata}
          {:error, reason} -> {:error, {:validation, "Invalid metadata: #{inspect(reason)}"}}
        end
      end

      defoverridable [validate_attrs: 1, event_version: 0, validate_metadata: 1]

      # Implement GameEvents protocol functions

      @doc """
      Validates the complete event structure.
      """
      @spec validate(struct()) :: :ok | validation_error()
      def validate(event) do
        # Implement full event validation here
        with :ok <- validate_base_fields(event),
             :ok <- validate_metadata_field(event) do
          :ok
        end
      end

      @doc """
      Converts the event to a map for serialization.
      """
      @spec to_map(struct()) :: map()
      def to_map(event) do
        map = Map.from_struct(event)

        # Convert timestamp to ISO8601 string
        map = if Map.has_key?(map, :timestamp) and not is_nil(map.timestamp) do
          Map.update!(map, :timestamp, &DateTime.to_iso8601/1)
        else
          map
        end

        # Convert atom keys to strings for consistency
        for {key, value} <- map, into: %{} do
          {to_string(key), serialize_value(value)}
        end
      end

      defp serialize_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
      defp serialize_value(value) when is_atom(value) and not is_nil(value), do: Atom.to_string(value)
      defp serialize_value(value) when is_map(value) do
        for {k, v} <- value, into: %{} do
          key = if is_atom(k), do: Atom.to_string(k), else: k
          {key, serialize_value(v)}
        end
      end
      defp serialize_value(value) when is_list(value), do: Enum.map(value, &serialize_value/1)
      defp serialize_value(value), do: value

      @doc """
      Creates an event from a serialized map.
      """
      @spec from_map(map()) :: struct()
      def from_map(data) do
        # Convert string keys to atoms and handle special cases
        attrs = for {key, val} <- data, into: %{} do
          cond do
            # Handle timestamp special case
            is_binary(key) && key == "timestamp" && is_binary(val) ->
              case DateTime.from_iso8601(val) do
                {:ok, datetime, _offset} -> {:timestamp, datetime}
                _ -> {:timestamp, nil}
              end

            # Handle reason/type fields that might be atoms
            is_binary(key) && key in ["reason", "type"] && is_binary(val) ->
              {String.to_existing_atom(key), String.to_existing_atom(val)}

            # Handle metadata which should stay as a map with string keys
            is_binary(key) && key == "metadata" && is_map(val) ->
              {:metadata, val}

            # Convert other string keys to atoms
            is_binary(key) ->
              {String.to_existing_atom(key), val}

            # Pass through existing atom keys
            true ->
              {key, val}
          end
        end

        struct(__MODULE__, attrs)
      end
    end
  end

  # Validation helper functions - these will be imported by using modules

  @doc """
  Validates that a required field is present in the attributes map.
  """
  @spec validate_required_field(map(), atom()) :: :ok | validation_error()
  def validate_required_field(attrs, field) when is_map(attrs) and is_atom(field) do
    if Map.has_key?(attrs, field) and not is_nil(Map.get(attrs, field)) do
      :ok
    else
      {:error, {:validation, "#{field} is required"}}
    end
  end

  @doc """
  Validates that a field is a string if present.
  """
  @spec validate_string_field(map(), atom()) :: :ok | validation_error()
  def validate_string_field(attrs, field) when is_map(attrs) and is_atom(field) do
    case Map.get(attrs, field) do
      nil -> :ok  # Field is not present, which is fine for this check
      val when is_binary(val) -> :ok
      _ -> {:error, {:validation, "#{field} must be a string"}}
    end
  end

  @doc """
  Validates that a field is an integer if present.
  """
  @spec validate_integer_field(map(), atom()) :: :ok | validation_error()
  def validate_integer_field(attrs, field) when is_map(attrs) and is_atom(field) do
    case Map.get(attrs, field) do
      nil -> :ok
      val when is_integer(val) -> :ok
      _ -> {:error, {:validation, "#{field} must be an integer"}}
    end
  end

  @doc """
  Validates that a field is a positive integer if present.
  """
  @spec validate_positive_integer_field(map(), atom()) :: :ok | validation_error()
  def validate_positive_integer_field(attrs, field) when is_map(attrs) and is_atom(field) do
    case Map.get(attrs, field) do
      nil -> :ok
      val when is_integer(val) and val > 0 -> :ok
      _ -> {:error, {:validation, "#{field} must be a positive integer"}}
    end
  end

  @doc """
  Validates that a field is a non-negative integer if present.
  """
  @spec validate_non_negative_integer_field(map(), atom()) :: :ok | validation_error()
  def validate_non_negative_integer_field(attrs, field) when is_map(attrs) and is_atom(field) do
    case Map.get(attrs, field) do
      nil -> :ok
      val when is_integer(val) and val >= 0 -> :ok
      _ -> {:error, {:validation, "#{field} must be a non-negative integer"}}
    end
  end

  @doc """
  Validates that a field is a boolean if present.
  """
  @spec validate_boolean_field(map(), atom()) :: :ok | validation_error()
  def validate_boolean_field(attrs, field) when is_map(attrs) and is_atom(field) do
    case Map.get(attrs, field) do
      nil -> :ok
      val when is_boolean(val) -> :ok
      _ -> {:error, {:validation, "#{field} must be a boolean"}}
    end
  end

  @doc """
  Validates that a field is a map if present.
  """
  @spec validate_map_field(map(), atom()) :: :ok | validation_error()
  def validate_map_field(attrs, field) when is_map(attrs) and is_atom(field) do
    case Map.get(attrs, field) do
      nil -> :ok
      val when is_map(val) -> :ok
      _ -> {:error, {:validation, "#{field} must be a map"}}
    end
  end

  @doc """
  Validates that a field is a list if present.
  """
  @spec validate_list_field(map(), atom()) :: :ok | validation_error()
  def validate_list_field(attrs, field) when is_map(attrs) and is_atom(field) do
    case Map.get(attrs, field) do
      nil -> :ok
      val when is_list(val) -> :ok
      _ -> {:error, {:validation, "#{field} must be a list"}}
    end
  end

  @doc """
  Validates that a field is a DateTime if present.
  """
  @spec validate_datetime_field(map(), atom()) :: :ok | validation_error()
  def validate_datetime_field(attrs, field) when is_map(attrs) and is_atom(field) do
    case Map.get(attrs, field) do
      nil -> :ok
      %DateTime{} -> :ok
      _ -> {:error, {:validation, "#{field} must be a DateTime"}}
    end
  end

  # Helper functions for event validation

  @doc """
  Validates that an event has all the required base fields.
  """
  @spec validate_base_fields(struct()) :: :ok | validation_error()
  def validate_base_fields(event) do
    # Check that all required fields are present
    with :ok <- validate_field_presence(event, :game_id),
         :ok <- validate_field_presence(event, :guild_id),
         :ok <- validate_field_presence(event, :timestamp),
         :ok <- validate_field_presence(event, :metadata) do
      :ok
    end
  end

  @doc """
  Validates that an event's metadata field is valid.
  """
  @spec validate_metadata_field(struct()) :: :ok | validation_error()
  def validate_metadata_field(%{metadata: metadata}) do
    case Metadata.validate(metadata) do
      :ok -> :ok
      {:error, reason} -> {:error, {:validation, "Invalid metadata: #{inspect(reason)}"}}
    end
  end

  defp validate_field_presence(struct, field) do
    if Map.has_key?(struct, field) and not is_nil(Map.get(struct, field)) do
      :ok
    else
      {:error, {:validation, "#{field} is required"}}
    end
  end
end
