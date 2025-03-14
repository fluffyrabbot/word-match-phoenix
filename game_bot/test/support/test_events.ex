defmodule GameBot.Domain.Events.TestEvents.ValidatorTestEvent do
  @moduledoc """
  Test event struct for validation tests
  """
  defstruct [:game_id, :guild_id, :mode, :timestamp, :metadata, :count, :score]

  @doc "Returns the event type for serialization"
  def event_type, do: "validator_test_event"

  @doc "Returns the event version for serialization"
  def event_version, do: 1
end

defmodule GameBot.Domain.Events.TestEvents.ValidatorOptionalFieldsEvent do
  @moduledoc """
  Test event with optional fields
  """
  defstruct [:game_id, :guild_id, :mode, :timestamp, :metadata, :optional_field]

  @doc "Returns the event type for serialization"
  def event_type, do: "validator_optional_fields_event"

  @doc "Returns the event version for serialization"
  def event_version, do: 1
end

# This module provides direct validation functions for test events without relying on protocols
defmodule GameBot.Domain.Events.TestEvents.Validator do
  alias GameBot.Domain.Events.{EventStructure, TestEvents}

  @doc """
  Validates a TestEvent directly, bypassing the protocol system.
  This allows for more reliable testing without protocol consolidation issues.

  Returns:
  - :ok if the event is valid
  - {:error, reason} if validation fails
  """
  def validate(%TestEvents.ValidatorTestEvent{} = event) do
    with :ok <- validate_base_fields(event),
         :ok <- validate_test_event_fields(event) do
      :ok
    end
  end

  def validate(%TestEvents.ValidatorOptionalFieldsEvent{} = event) do
    with :ok <- validate_base_fields(event),
         :ok <- validate_optional_fields_event(event) do
      :ok
    end
  end

  # Validates fields specific to ValidatorTestEvent
  defp validate_test_event_fields(event) do
    # Safely access fields
    count = Map.get(event, :count)
    score = Map.get(event, :score)

    with :ok <- validate_count(count),
         :ok <- validate_score(score) do
      :ok
    end
  end

  # Validates fields specific to ValidatorOptionalFieldsEvent
  defp validate_optional_fields_event(event) do
    optional_field = Map.get(event, :optional_field)

    case optional_field do
      nil -> :ok
      value when is_binary(value) -> :ok
      _ -> {:error, "optional_field must be a string or nil"}
    end
  end

  # Common base field validation
  defp validate_base_fields(event) do
    # First manually check required fields
    cond do
      is_nil(Map.get(event, :game_id)) -> {:error, "game_id is required"}
      is_nil(Map.get(event, :guild_id)) -> {:error, "guild_id is required"}
      is_nil(Map.get(event, :mode)) -> {:error, "mode is required"}
      is_nil(Map.get(event, :timestamp)) -> {:error, "timestamp is required"}
      is_nil(Map.get(event, :metadata)) -> {:error, "metadata is required"}
      true -> validate_field_values(event)
    end
  end

  # Validate field values
  defp validate_field_values(event) do
    with :ok <- validate_id_fields(event),
         :ok <- validate_timestamp(event.timestamp),
         :ok <- validate_mode(event.mode),
         :ok <- validate_metadata(event.metadata) do
      :ok
    end
  end

  defp validate_id_fields(event) do
    with true <- is_binary(event.game_id) and byte_size(event.game_id) > 0,
         true <- is_binary(event.guild_id) and byte_size(event.guild_id) > 0 do
      :ok
    else
      false -> {:error, "game_id and guild_id must be non-empty strings"}
    end
  end

  defp validate_timestamp(%DateTime{} = timestamp) do
    case DateTime.compare(timestamp, DateTime.utc_now()) do
      :gt -> {:error, "timestamp cannot be in the future"}
      _ -> :ok
    end
  end
  defp validate_timestamp(_), do: {:error, "timestamp must be a DateTime"}

  defp validate_mode(mode) when is_atom(mode), do: :ok
  defp validate_mode(_), do: {:error, "mode must be an atom"}

  defp validate_metadata(metadata) when is_map(metadata) do
    if has_source_id?(metadata) and has_correlation_id?(metadata) do
      :ok
    else
      cond do
        not has_source_id?(metadata) -> {:error, "source_id is required in metadata"}
        not has_correlation_id?(metadata) -> {:error, "correlation_id is required in metadata"}
        true -> {:error, "metadata validation failed"}
      end
    end
  end
  defp validate_metadata(_), do: {:error, "metadata must be a map"}

  defp has_source_id?(metadata) do
    Map.has_key?(metadata, :source_id) or Map.has_key?(metadata, "source_id")
  end

  defp has_correlation_id?(metadata) do
    Map.has_key?(metadata, :correlation_id) or Map.has_key?(metadata, "correlation_id")
  end

  defp validate_count(nil), do: {:error, "count is required"}
  defp validate_count(count) when is_integer(count) and count > 0, do: :ok
  defp validate_count(_), do: {:error, "count must be a positive integer"}

  defp validate_score(nil), do: {:error, "score is required"}
  defp validate_score(score) when is_integer(score), do: :ok
  defp validate_score(_), do: {:error, "score must be an integer"}
end

# Keep the protocol implementations for compatibility,
# but our tests will use the direct module above
defimpl GameBot.Domain.Events.EventValidator, for: GameBot.Domain.Events.TestEvents.ValidatorTestEvent do
  alias GameBot.Domain.Events.EventStructure

  def validate(event) do
    with :ok <- validate_base_fields(event),
         :ok <- validate_fields(event) do
      :ok
    end
  end

  def validate_fields(event) do
    # Safely access fields
    count = Map.get(event, :count)
    score = Map.get(event, :score)

    with :ok <- validate_count(count),
         :ok <- validate_score(score) do
      :ok
    end
  end

  defp validate_base_fields(event) do
    EventStructure.validate_base_fields(event)
  end

  defp validate_count(nil), do: {:error, "count is required"}
  defp validate_count(count) when is_integer(count) and count > 0, do: :ok
  defp validate_count(_), do: {:error, "count must be a positive integer"}

  defp validate_score(nil), do: {:error, "score is required"}
  defp validate_score(score) when is_integer(score), do: :ok
  defp validate_score(_), do: {:error, "score must be an integer"}
end

defimpl GameBot.Domain.Events.EventValidator, for: GameBot.Domain.Events.TestEvents.ValidatorOptionalFieldsEvent do
  alias GameBot.Domain.Events.EventStructure

  def validate(event) do
    with :ok <- validate_base_fields(event),
         :ok <- validate_fields(event) do
      :ok
    end
  end

  def validate_fields(event) do
    # Safely access the optional field
    optional_field = Map.get(event, :optional_field)

    case optional_field do
      nil -> :ok
      value when is_binary(value) -> :ok
      _ -> {:error, "optional_field must be a string or nil"}
    end
  end

  defp validate_base_fields(event) do
    EventStructure.validate_base_fields(event)
  end
end
