defmodule GameBot.Domain.Events.EventValidator do
  @moduledoc """
  Behaviour for validating events.
  Provides a standard interface for event validation with optional field validation.
  """

  @doc "Validates an event's structure and content"
  @callback validate(event :: struct()) :: :ok | {:error, term()}

  @doc "Validates specific fields of an event"
  @callback validate_fields(event :: struct()) :: :ok | {:error, term()}

  @optional_callbacks [validate_fields: 1]
end
