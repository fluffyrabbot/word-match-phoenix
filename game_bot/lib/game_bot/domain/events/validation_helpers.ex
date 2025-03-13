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
  def validate_string_value(nil), do: {:error, "is required"}
  def validate_string_value(value) when is_binary(value) and byte_size(value) > 0, do: :ok
  def validate_string_value(_), do: {:error, "must be a non-empty string"}

  @doc """
  Validates that a DateTime is not in the future.
  """
  @spec validate_not_future(Ecto.Changeset.t(), atom()) :: Ecto.Changeset.t()
  def validate_not_future(changeset, field) do
    validate_change(changeset, field, fn _, value ->
      case validate_datetime_not_future(value) do
        :ok -> []
        {:error, reason} -> [{field, reason}]
      end
    end)
  end

  @doc """
  Validates that a DateTime value is not in the future.
  """
  @spec validate_datetime_not_future(DateTime.t() | nil) :: :ok | {:error, String.t()}
  def validate_datetime_not_future(nil), do: {:error, "is required"}
  def validate_datetime_not_future(%DateTime{} = dt) do
    case DateTime.compare(dt, DateTime.utc_now()) do
      :gt -> {:error, "cannot be in the future"}
      _ -> :ok
    end
  end
  def validate_datetime_not_future(_), do: {:error, "must be a DateTime"}

  @doc """
  Ensures metadata has required fields.
  """
  @spec ensure_metadata_fields(map(), String.t()) :: map()
  def ensure_metadata_fields(metadata, guild_id) do
    metadata
    |> Map.put_new(:guild_id, guild_id)
    |> Map.put_new(:source_id, Map.get(metadata, :source_id) || UUID.uuid4())
    |> Map.put_new(:correlation_id, Map.get(metadata, :correlation_id) || UUID.uuid4())
  end

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
