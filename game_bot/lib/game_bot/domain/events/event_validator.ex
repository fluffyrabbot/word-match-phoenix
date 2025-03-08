defprotocol GameBot.Domain.Events.EventValidator do
  @moduledoc """
  Protocol for validating events in the GameBot system.

  This protocol provides a standard interface for event validation, ensuring that:
  1. All events have required base fields (game_id, guild_id, mode, timestamp, metadata)
  2. Event-specific fields are present and valid
  3. Field types match their specifications
  4. Nested structures are valid
  5. Numeric constraints are enforced

  ## Implementation Requirements

  Implementing modules must provide:
  - validate/1: Main validation function that checks the entire event
  - validate_fields/1 (optional): Specific field validation logic

  ## Example Implementation

  ```elixir
  defimpl EventValidator, for: MyEvent do
    def validate(event) do
      with :ok <- validate_base_fields(event),
           :ok <- validate_fields(event) do
        :ok
      end
    end

    def validate_fields(event) do
      with :ok <- validate_required_fields(event),
           :ok <- validate_numeric_constraints(event) do
        :ok
      end
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

  @doc """
  Optional callback for validating specific fields of an event.

  This callback can be implemented to provide more granular field validation
  beyond the base validation provided by validate/1.

  ## Parameters
  - event: The event struct containing the fields to validate

  ## Returns
  - :ok if all fields are valid
  - {:error, reason} if validation fails, where reason is a descriptive string

  ## Example
  ```elixir
  def validate_fields(event) do
    cond do
      event.count < 0 -> {:error, "count must be non-negative"}
      event.score < 0 -> {:error, "score must be non-negative"}
      true -> :ok
    end
  end
  ```
  """
  @callback validate_fields(event :: struct()) :: :ok | validation_error

  @optional_callbacks [validate_fields: 1]
end
