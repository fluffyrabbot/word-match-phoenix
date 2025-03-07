defmodule GameBot.Infrastructure.EventStoreTransaction do
  @moduledoc """
  Provides transaction support for event store operations.

  This module offers functions for safely executing multiple event store operations
  within a transaction boundary, ensuring all-or-nothing semantics for event
  persistence.

  Key features:
  - Atomic appending of multiple events
  - Optimistic concurrency control
  - Error handling and cleanup

  Example usage:

  ```elixir
  # Append multiple events in a transaction
  EventStoreTransaction.append_events_in_transaction(
    "game-123",
    expected_version,
    [event1, event2, event3]
  )
  ```
  """

  alias GameBot.Infrastructure.EventStore
  alias GameBot.Infrastructure.EventStoreAdapter
  alias GameBot.Infrastructure.EventStoreAdapter.Error

  @doc """
  Appends multiple events to a stream in a single transaction.

  Ensures that all events are successfully appended or none are.
  Respects expected_version for optimistic concurrency control.

  ## Parameters
  - stream_id: Unique identifier for the event stream
  - expected_version: Expected current version for optimistic concurrency
  - events: List of event structs to append
  - opts: Optional parameters (passed to EventStoreAdapter)

  ## Returns
  - {:ok, recorded_events} - All events successfully appended
  - {:error, reason} - Transaction failed, no events appended
  """
  @spec append_events_in_transaction(String.t(), non_neg_integer(), [struct()], keyword()) ::
        {:ok, [struct()]} | {:error, Error.t()}
  def append_events_in_transaction(stream_id, expected_version, events, opts \\ []) do
    # Validate inputs
    with :ok <- validate_stream_id(stream_id),
         :ok <- validate_events(events) do
      # Validate current stream version
      case validate_stream_version(stream_id, expected_version) do
        :ok ->
          # We use the standard adapter but ensure we're tracking the transaction
          # If any step fails, the entire operation should fail
          try_append_with_validation(stream_id, expected_version, events, opts)
        error ->
          error
      end
    end
  end

  @doc """
  Reads events from a stream and processes them within a single transaction.
  Then optionally appends new events based on the processing results.

  ## Parameters
  - stream_id: The stream to read from and potentially append to
  - processor: Function that processes events and returns new events to append
  - opts: Optional parameters

  ## Returns
  - {:ok, {processed_events, new_events}} - Transaction completed successfully
  - {:error, reason} - Transaction failed
  """
  @spec process_stream_in_transaction(
    String.t(),
    (events :: [struct()] -> {new_events :: [struct()], any()}),
    keyword()
  ) :: {:ok, {[struct()], [struct()]}} | {:error, Error.t()}
  def process_stream_in_transaction(stream_id, processor, opts \\ []) do
    with :ok <- validate_stream_id(stream_id),
         {:ok, current_version} <- EventStore.stream_version(stream_id),
         {:ok, events} <- EventStoreAdapter.read_stream_forward(stream_id),
         {new_events, _result} <- processor.(events),
         :ok <- validate_events(new_events) do

      # If no new events, just return success
      if Enum.empty?(new_events) do
        {:ok, {events, []}}
      else
        # Append new events with expected version
        case try_append_with_validation(stream_id, current_version, new_events, opts) do
          {:ok, appended_events} -> {:ok, {events, appended_events}}
          error -> error
        end
      end
    else
      error -> error
    end
  end

  # Private helpers

  defp validate_stream_id(stream_id) when is_binary(stream_id) and byte_size(stream_id) > 0, do: :ok
  defp validate_stream_id(_), do: {:error, validation_error("Invalid stream ID", "Stream ID must be a non-empty string")}

  defp validate_events(events) when is_list(events) and length(events) > 0, do: :ok
  defp validate_events([]), do: {:error, validation_error("Empty event list", "At least one event must be provided")}
  defp validate_events(_), do: {:error, validation_error("Invalid events", "Events must be a list")}

  defp validate_stream_version(stream_id, expected_version) do
    case EventStore.stream_version(stream_id) do
      {:ok, ^expected_version} -> :ok
      {:ok, actual} -> {:error, concurrency_error(stream_id, expected_version, actual)}
      error -> error
    end
  end

  defp try_append_with_validation(stream_id, expected_version, events, opts) do
    # First validate all events
    case EventStoreAdapter.validate_event_structures(events) do
      :ok ->
        # Then serialize all events
        case EventStoreAdapter.serialize_events(events) do
          {:ok, serialized} ->
            # Then try to append them all
            case EventStore.append_to_stream(stream_id, expected_version, serialized) do
              {:ok, recorded_events} ->
                {:ok, events} # Return the original events
              error ->
                error
            end
          error -> error
        end
      error -> error
    end
  end

  # Error helpers

  defp validation_error(message, details) do
    %Error{
      type: :validation,
      message: message,
      details: details
    }
  end

  defp concurrency_error(stream_id, expected, actual) do
    %Error{
      type: :concurrency,
      message: "Optimistic concurrency check failed",
      details: %{
        stream_id: stream_id,
        expected_version: expected,
        actual_version: actual
      }
    }
  end
end
