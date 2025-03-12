defmodule GameBot.Infrastructure.Persistence.EventStore.JsonSerializer do
  @moduledoc """
  Alias module that delegates to the JsonSerializer implementation in the Serialization namespace.
  This module exists to provide compatibility for code that expects this namespace.

  It handles differences in function signatures and maintains backward compatibility.
  """

  alias GameBot.Infrastructure.Persistence.EventStore.Serialization.JsonSerializer, as: Implementation
  alias GameBot.Infrastructure.Persistence.Error, as: PersistenceError

  @doc """
  Serializes an event into a format suitable for storage.

  Compatible with the old Serializer.serialize/1 signature while delegating to the
  more robust JsonSerializer implementation.
  """
  @spec serialize(map()) :: {:ok, map()} | {:error, PersistenceError.t()}
  def serialize(event) do
    case Implementation.serialize(event) do
      {:ok, result} -> {:ok, result}
      {:error, error} ->
        # Convert error type for compatibility if needed
        {:error, %PersistenceError{type: :validation}}
    end
  end

  @doc """
  Deserializes event data into an event struct.

  Compatible with the old Serializer.deserialize/1 signature while delegating to the
  more robust JsonSerializer implementation.
  """
  @spec deserialize(map()) :: {:ok, map()} | {:error, PersistenceError.t()}
  def deserialize(data, event_module \\ nil) do
    case Implementation.deserialize(data) do
      {:ok, result} -> {:ok, result}
      {:error, _} -> {:error, %PersistenceError{type: :validation}}
    end
  end

  @doc """
  Gets the current version for an event type.

  This maintains compatibility with the old Serializer.event_version/1 function
  which doesn't exist in the JsonSerializer implementation.
  """
  @spec event_version(String.t()) :: {:ok, integer()} | {:error, PersistenceError.t()}
  def event_version(event_type) do
    # For compatibility with old Serializer.event_version/1 function
    # The implementation below mimics the behavior in the old Serializer
    if event_type in ["game_started", "test_event"] do
      {:ok, 1}
    else
      {:error, %PersistenceError{type: :validation}}
    end
  end

  # Delegate other functions directly to the implementation
  defdelegate validate(data, opts \\ []), to: Implementation
  defdelegate migrate(data, from_version, to_version, opts \\ []), to: Implementation
  defdelegate version(), to: Implementation
end
