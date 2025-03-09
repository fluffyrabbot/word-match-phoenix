defmodule GameBot.Domain.Events.GameEvents.GameCompletedValidator do
  @moduledoc """
  Validation functions for GameCompleted event
  """

  def validate_integer(field, value) when is_integer(value), do: :ok
  def validate_integer(field, _value), do: {:error, "#{field} must be an integer"}

  def validate_positive_integer(field, value) when is_integer(value) and value > 0, do: :ok
  def validate_positive_integer(field, _value), do: {:error, "#{field} must be a positive integer"}

  def validate_non_negative_integer(field, value) when is_integer(value) and value >= 0, do: :ok
  def validate_non_negative_integer(field, _value), do: {:error, "#{field} must be a non-negative integer"}

  def validate_float(field, value) when is_float(value), do: :ok
  def validate_float(field, _value), do: {:error, "#{field} must be a float"}
end
