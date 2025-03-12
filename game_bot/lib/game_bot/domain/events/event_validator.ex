defprotocol GameBot.Domain.Events.EventValidator do
  @moduledoc """
  Protocol for validating events in the GameBot system.

  This protocol provides a standard interface for event validation, ensuring that:
  1. All events have required base fields (game_id, guild_id, mode, timestamp, metadata)
  2. Event-specific fields are present and valid
  3. Field types match their specifications
  4. Nested structures are valid
  5. Numeric constraints are enforced

  ## Implementation Guidelines

  When implementing this protocol for an event type:

  * First validate the base fields using `EventValidatorHelpers.validate_base_fields/1`
  * Then validate event-specific fields with custom logic
  * For nested structures, consider using nested validation
  * Use the helper functions in `EventValidatorHelpers` for common validations
  * Return descriptive error messages that help identify the issue

  ## Implementation Example

  ```elixir
  defimpl EventValidator, for: GameBot.Domain.Events.GameEvents.GameStarted do
    alias GameBot.Domain.Events.EventValidatorHelpers, as: Helpers

    def validate(event) do
      with :ok <- Helpers.validate_base_fields(event),
           :ok <- validate_fields(event) do
        :ok
      end
    end

    def validate_fields(event) do
      with :ok <- Helpers.validate_required(event, [:round_number, :teams, :team_ids, :player_ids]),
           :ok <- validate_round_number(event.round_number),
           :ok <- validate_teams(event.teams, event.team_ids, event.player_ids) do
        :ok
      end
    end

    defp validate_round_number(num) when is_integer(num) and num > 0, do: :ok
    defp validate_round_number(_), do: {:error, "round_number must be a positive integer"}

    defp validate_teams(teams, team_ids, player_ids) do
      # Custom validation logic for teams structure
      # ...
    end
  end
  ```
  """

  @typedoc """
  Type for validation errors.
  The error term should be a string describing the validation failure.
  """
  @type validation_error :: {:error, String.t()}

  @doc """
  Validates an event's structure and content.

  This function should:
  1. Check that all required base fields are present
  2. Validate that field types match their specifications
  3. Ensure numeric fields meet their constraints
  4. Validate any nested structures
  5. Check event-specific business rules

  ## Parameters
  - event: The event struct to validate

  ## Returns
  - :ok if the event is valid
  - {:error, reason} if validation fails, where reason is a descriptive string

  ## Example
  ```elixir
  case EventValidator.validate(event) do
    :ok -> process_event(event)
    {:error, reason} -> handle_error(reason)
  end
  ```
  """
  @spec validate(t) :: :ok | validation_error
  def validate(event)
end

defmodule GameBot.Domain.Events.EventValidatorHelpers do
  @moduledoc """
  Helper functions for validating event fields.

  This module provides common validation functions that can be used across
  different event validator implementations, including:
  - Base field validation
  - Type checking
  - Required field verification
  - Numeric constraint validation
  - Collection validation

  These helpers make it easier to implement the EventValidator protocol
  with consistent validation behavior.
  """

  alias GameBot.Domain.Events.Metadata

  @base_fields [:game_id, :guild_id, :mode, :timestamp, :metadata]

  @doc """
  Validates that an event has all required base fields with proper types.

  ## Parameters
  - event: The event struct to validate

  ## Returns
  - :ok if all base fields are valid
  - {:error, reason} if validation fails
  """
  @spec validate_base_fields(struct()) :: :ok | {:error, String.t()}
  def validate_base_fields(event) do
    with :ok <- validate_required(event, @base_fields),
         :ok <- validate_id(event.game_id, "game_id"),
         :ok <- validate_id(event.guild_id, "guild_id"),
         :ok <- validate_atom(event.mode, "mode"),
         :ok <- validate_timestamp(event.timestamp),
         :ok <- validate_metadata(event.metadata) do
      :ok
    end
  end

  @doc """
  Validates that required fields are present and non-nil in an event.

  ## Parameters
  - event: The event struct to validate
  - fields: List of field atoms that should be present and non-nil

  ## Returns
  - :ok if all required fields are present
  - {:error, reason} if any field is missing
  """
  @spec validate_required(struct(), [atom()]) :: :ok | {:error, String.t()}
  def validate_required(event, fields) do
    missing = Enum.filter(fields, fn field ->
      not Map.has_key?(event, field) or is_nil(Map.get(event, field))
    end)

    if Enum.empty?(missing) do
      :ok
    else
      field_names = Enum.map_join(missing, ", ", &Atom.to_string/1)
      {:error, "Missing required fields: #{field_names}"}
    end
  end

  @doc """
  Validates a string ID field.

  ## Parameters
  - id: The ID value to validate
  - field_name: Name of the field for error messages

  ## Returns
  - :ok if the ID is valid
  - {:error, reason} if invalid
  """
  @spec validate_id(String.t(), String.t()) :: :ok | {:error, String.t()}
  def validate_id(id, field_name) when is_binary(id) and byte_size(id) > 0, do: :ok
  def validate_id(_, field_name), do: {:error, "#{field_name} must be a non-empty string"}

  @doc """
  Validates an atom field.

  ## Parameters
  - value: The value to validate
  - field_name: Name of the field for error messages

  ## Returns
  - :ok if the value is an atom
  - {:error, reason} if invalid
  """
  @spec validate_atom(atom(), String.t()) :: :ok | {:error, String.t()}
  def validate_atom(value, field_name) when is_atom(value), do: :ok
  def validate_atom(_, field_name), do: {:error, "#{field_name} must be an atom"}

  @doc """
  Validates a DateTime timestamp.

  ## Parameters
  - timestamp: The timestamp to validate

  ## Returns
  - :ok if the timestamp is valid
  - {:error, reason} if invalid
  """
  @spec validate_timestamp(DateTime.t()) :: :ok | {:error, String.t()}
  def validate_timestamp(%DateTime{}), do: :ok
  def validate_timestamp(_), do: {:error, "timestamp must be a DateTime struct"}

  @doc """
  Validates event metadata.

  ## Parameters
  - metadata: The metadata to validate

  ## Returns
  - :ok if the metadata is valid
  - {:error, reason} if invalid
  """
  @spec validate_metadata(map()) :: :ok | {:error, String.t()}
  def validate_metadata(metadata) when is_map(metadata) do
    Metadata.validate(metadata)
  end
  def validate_metadata(_), do: {:error, "metadata must be a map"}

  @doc """
  Validates a positive integer.

  ## Parameters
  - value: The value to validate
  - field_name: Name of the field for error messages

  ## Returns
  - :ok if the value is a positive integer
  - {:error, reason} if invalid
  """
  @spec validate_positive_integer(integer(), String.t()) :: :ok | {:error, String.t()}
  def validate_positive_integer(value, field_name) when is_integer(value) and value > 0, do: :ok
  def validate_positive_integer(_, field_name), do: {:error, "#{field_name} must be a positive integer"}

  @doc """
  Validates a non-negative integer.

  ## Parameters
  - value: The value to validate
  - field_name: Name of the field for error messages

  ## Returns
  - :ok if the value is a non-negative integer
  - {:error, reason} if invalid
  """
  @spec validate_non_negative_integer(integer(), String.t()) :: :ok | {:error, String.t()}
  def validate_non_negative_integer(value, field_name) when is_integer(value) and value >= 0, do: :ok
  def validate_non_negative_integer(_, field_name), do: {:error, "#{field_name} must be a non-negative integer"}

  @doc """
  Validates a float value.

  ## Parameters
  - value: The value to validate
  - field_name: Name of the field for error messages

  ## Returns
  - :ok if the value is a float
  - {:error, reason} if invalid
  """
  @spec validate_float(float(), String.t()) :: :ok | {:error, String.t()}
  def validate_float(value, field_name) when is_float(value), do: :ok
  def validate_float(_, field_name), do: {:error, "#{field_name} must be a float"}

  @doc """
  Validates that a list contains elements of a specific type.

  ## Parameters
  - list: The list to validate
  - type_validator: Function that validates each element
  - field_name: Name of the field for error messages

  ## Returns
  - :ok if all elements are valid
  - {:error, reason} if any element is invalid
  """
  @spec validate_list_elements(list(), (any() -> boolean()), String.t()) :: :ok | {:error, String.t()}
  def validate_list_elements(list, type_validator, field_name) when is_list(list) do
    if Enum.all?(list, type_validator) do
      :ok
    else
      {:error, "#{field_name} contains invalid elements"}
    end
  end
  def validate_list_elements(_, _, field_name), do: {:error, "#{field_name} must be a list"}

  @doc """
  Validates that a map has keys of a specific type.

  ## Parameters
  - map: The map to validate
  - key_validator: Function that validates each key
  - field_name: Name of the field for error messages

  ## Returns
  - :ok if all keys are valid
  - {:error, reason} if any key is invalid
  """
  @spec validate_map_keys(map(), (any() -> boolean()), String.t()) :: :ok | {:error, String.t()}
  def validate_map_keys(map, key_validator, field_name) when is_map(map) do
    if Enum.all?(Map.keys(map), key_validator) do
      :ok
    else
      {:error, "#{field_name} contains invalid keys"}
    end
  end
  def validate_map_keys(_, _, field_name), do: {:error, "#{field_name} must be a map"}

  @doc """
  Validates that a map has values of a specific type.

  ## Parameters
  - map: The map to validate
  - value_validator: Function that validates each value
  - field_name: Name of the field for error messages

  ## Returns
  - :ok if all values are valid
  - {:error, reason} if any value is invalid
  """
  @spec validate_map_values(map(), (any() -> boolean()), String.t()) :: :ok | {:error, String.t()}
  def validate_map_values(map, value_validator, field_name) when is_map(map) do
    if Enum.all?(Map.values(map), value_validator) do
      :ok
    else
      {:error, "#{field_name} contains invalid values"}
    end
  end
  def validate_map_values(_, _, field_name), do: {:error, "#{field_name} must be a map"}
end
