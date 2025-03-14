defmodule GameBot.Domain.Events.ValidationHelpers do
  @moduledoc """
  Provides common validation functions for event modules.
  This module helps reduce code duplication across event types.
  """

  import Ecto.Changeset

  @doc """
  Validates that a string field is not empty.
  """
  @spec validate_non_empty_string(Ecto.Changeset.t(), atom()) :: Ecto.Changeset.t()
  def validate_non_empty_string(changeset, field) do
    validate_change(changeset, field, fn _, value ->
      case validate_string_value(value) do
        :ok -> []
        {:error, reason} -> [{field, reason}]
      end
    end)
  end

  @doc """
  Validates that a string value is not empty.
  """
  @spec validate_string_value(String.t() | nil) :: :ok | {:error, String.t()}
  def validate_string_value(nil), do: {:error, "value is required"}
  def validate_string_value(value) when is_binary(value) and byte_size(value) > 0, do: :ok
  def validate_string_value(value) when is_binary(value), do: {:error, "value must be a non-empty string"}
  def validate_string_value(_), do: {:error, "value must be a string"}

  @doc """
  Validates that a string value is not empty, with a custom field name.
  """
  @spec validate_string_value(String.t() | nil, String.t()) :: :ok | {:error, String.t()}
  def validate_string_value(nil, field_name), do: {:error, "#{field_name} is required"}
  def validate_string_value(value, field_name) when is_binary(value) and byte_size(value) > 0, do: :ok
  def validate_string_value(value, field_name) when is_binary(value), do: {:error, "#{field_name} must be a non-empty string"}
  def validate_string_value(_, field_name), do: {:error, "#{field_name} must be a string"}

  @doc """
  Validates that a DateTime is not in the future.
  """
  @spec validate_not_future(Ecto.Changeset.t(), atom()) :: Ecto.Changeset.t()
  def validate_not_future(changeset, field) do
    # Get the current value of the field from the changeset
    timestamp = Ecto.Changeset.get_field(changeset, field)

    # Only validate if we have a timestamp to check
    if timestamp do
      now = DateTime.utc_now()

      # Explicitly check if the timestamp is in the future
      if DateTime.compare(timestamp, now) == :gt do
        Ecto.Changeset.add_error(changeset, field, "cannot be in the future")
      else
        changeset
      end
    else
      changeset
    end
  end

  @doc """
  Validates that a DateTime value is not in the future.
  """
  @spec validate_datetime_not_future(DateTime.t() | nil) :: :ok | {:error, String.t()}
  def validate_datetime_not_future(nil), do: {:error, "timestamp is required"}
  def validate_datetime_not_future(%DateTime{} = dt) do
    case DateTime.compare(dt, DateTime.utc_now()) do
      :gt -> {:error, "timestamp cannot be in the future"}
      _ -> :ok
    end
  end
  def validate_datetime_not_future(_), do: {:error, "timestamp must be a DateTime"}

  @doc """
  Ensures metadata has required fields.
  """
  @spec ensure_metadata_fields(map(), String.t()) :: map()
  def ensure_metadata_fields(metadata, guild_id) do
    # Don't overwrite existing fields
    metadata = if get_from_map(metadata, :guild_id) do
      metadata
    else
      Map.put_new(metadata, :guild_id, guild_id)
    end

    # Ensure source_id is present but don't overwrite
    metadata =
      if get_from_map(metadata, :source_id) do
        # If we have a string key but not an atom key, add the atom key too
        if Map.has_key?(metadata, "source_id") and not Map.has_key?(metadata, :source_id) do
          Map.put(metadata, :source_id, metadata["source_id"])
        else
          metadata
        end
      else
        Map.put(metadata, :source_id, UUID.uuid4())
      end

    # Ensure correlation_id is present but don't overwrite
    metadata =
      if get_from_map(metadata, :correlation_id) do
        # If we have a string key but not an atom key, add the atom key too
        if Map.has_key?(metadata, "correlation_id") and not Map.has_key?(metadata, :correlation_id) do
          Map.put(metadata, :correlation_id, metadata["correlation_id"])
        else
          metadata
        end
      else
        Map.put(metadata, :correlation_id, UUID.uuid4())
      end

    metadata
  end

  # Helper to get a value from a map checking both atom and string keys
  defp get_from_map(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, to_string(key))
  end
  defp get_from_map(_, _), do: nil

  @doc """
  Validates that a list has exactly the specified length.
  """
  @spec validate_list_length(Ecto.Changeset.t(), atom(), pos_integer(), String.t()) :: Ecto.Changeset.t()
  def validate_list_length(changeset, field, length, message) do
    validate_change(changeset, field, fn _, value ->
      if is_list(value) && length(value) == length do
        []
      else
        [{field, message}]
      end
    end)
  end

  @doc """
  Validates that a numeric value is non-negative (>= 0).
  """
  @spec validate_non_negative(integer() | float() | nil, String.t()) :: :ok | {:error, String.t()}
  def validate_non_negative(nil, _field_name), do: :ok
  def validate_non_negative(value, field_name) when is_number(value) and value >= 0, do: :ok
  def validate_non_negative(_value, field_name), do: {:error, "#{field_name} must be a non-negative number"}
end
