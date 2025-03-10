defmodule GameBot.Replay.EventStoreAccess do
  @moduledoc """
  Provides a standardized interface for accessing game events from the event store.

  This module handles:
  - Proper event retrieval using the adapter pattern
  - Pagination for large event streams
  - Consistent error handling
  - Event stream validation
  """

  alias GameBot.Infrastructure.Persistence.EventStore.Adapter
  require Logger

  @doc """
  Fetches all events for a given game.

  ## Parameters
    - game_id: The unique identifier of the game
    - opts: Additional options for event retrieval
      - :max_events - Maximum number of events to fetch (default: 1000)
      - :start_version - Version to start reading from (default: 0)
      - :batch_size - Size of each batch when paginating (default: 100)

  ## Returns
    - {:ok, events} - Successfully retrieved events
    - {:error, reason} - Failed to retrieve events
  """
  @spec fetch_game_events(String.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def fetch_game_events(game_id, opts \\ []) do
    max_events = Keyword.get(opts, :max_events, 1000)
    start_version = Keyword.get(opts, :start_version, 0)
    batch_size = Keyword.get(opts, :batch_size, 100)

    Logger.debug("Fetching events for game #{game_id} (max: #{max_events}, start: #{start_version})")

    try do
      do_fetch_events(game_id, start_version, max_events, batch_size, [])
    rescue
      e ->
        Logger.error("Error fetching events: #{inspect(e)}")
        {:error, :fetch_failed}
    catch
      _, e ->
        Logger.error("Caught error fetching events: #{inspect(e)}")
        {:error, :fetch_failed}
    end
  end

  @doc """
  Fetches the current version of a game's event stream.

  ## Parameters
    - game_id: The unique identifier of the game
    - opts: Additional options for event retrieval (default: [])

  ## Returns
    - {:ok, version} - Current version of the stream
    - {:error, reason} - Failed to retrieve version
  """
  @spec get_stream_version(String.t(), keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
  def get_stream_version(game_id, opts \\ []) do
    try do
      Adapter.stream_version(game_id, opts)
    rescue
      e ->
        Logger.error("Error getting stream version: #{inspect(e)}")
        {:error, :version_fetch_failed}
    catch
      _, e ->
        Logger.error("Caught error getting stream version: #{inspect(e)}")
        {:error, :version_fetch_failed}
    end
  end

  @doc """
  Validates that a game exists in the event store.

  ## Parameters
    - game_id: The unique identifier of the game

  ## Returns
    - {:ok, version} - Game exists with the given version
    - {:error, :stream_not_found} - Game does not exist
    - {:error, reason} - Failed to check existence
  """
  @spec game_exists?(String.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def game_exists?(game_id) do
    case get_stream_version(game_id) do
      {:ok, 0} -> {:error, :stream_not_found}
      {:ok, version} -> {:ok, version}
      error -> error
    end
  end

  # Private Functions

  # Recursively fetches events in batches
  defp do_fetch_events(_game_id, _start_version, max_events, _batch_size, events)
       when length(events) >= max_events do
    {:ok, Enum.take(events, max_events)}
  end

  defp do_fetch_events(game_id, start_version, max_events, batch_size, events) do
    case Adapter.read_stream_forward(game_id, start_version, batch_size) do
      {:ok, []} ->
        # No more events to read
        {:ok, events}

      {:ok, batch} ->
        # Got some events, check if we need more
        new_events = events ++ batch

        # Get the last event and calculate the next version
        last_event = List.last(batch)
        # Make sure we don't skip any events by using the correct next version
        # The version is the event's position in the stream, so we need to use this
        # as our next starting point
        next_version = last_event.version + 1

        Logger.debug("Fetched batch of #{length(batch)} events. Total: #{length(new_events)}. Next version: #{next_version}")

        # Recursively fetch more if needed
        do_fetch_events(game_id, next_version, max_events, batch_size, new_events)

      {:error, :stream_not_found} ->
        # Handle missing streams
        if Enum.empty?(events) do
          {:error, :stream_not_found}
        else
          # We already got some events, return those
          {:ok, events}
        end

      {:error, reason} ->
        # Propagate other errors
        {:error, reason}
    end
  end
end
