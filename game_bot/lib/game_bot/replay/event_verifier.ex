defmodule GameBot.Replay.EventVerifier do
  @moduledoc """
  Provides verification functions for event streams.

  This module handles:
  - Validating event sequence chronology
  - Confirming game completion status
  - Checking for required events in a stream
  - Identifying missing or corrupt events
  """

  require Logger

  @doc """
  Verifies that the event sequence is chronologically valid.

  ## Parameters
    - events: List of events to verify

  ## Returns
    - :ok - Event sequence is valid
    - {:error, reason} - Issues found in event sequence
  """
  @spec verify_event_sequence(list(map())) :: :ok | {:error, term()}
  def verify_event_sequence([]), do: {:error, :empty_sequence}
  def verify_event_sequence(events) when length(events) == 1, do: :ok
  def verify_event_sequence(events) do
    # Sort events by version to ensure chronological order
    sorted_events = Enum.sort_by(events, & &1.version)

    # Check for version gaps
    {result, _} = Enum.reduce_while(sorted_events, {:ok, 0}, fn
      event, {:ok, prev_version} ->
        cond do
          prev_version == 0 ->
            # First event, just record version
            {:cont, {:ok, event.version}}

          event.version == prev_version + 1 ->
            # Sequential, as expected
            {:cont, {:ok, event.version}}

          event.version > prev_version + 1 ->
            # Gap detected
            error = {:error, {:version_gap, prev_version, event.version}}
            {:halt, {error, event.version}}

          true ->
            # Duplicate or out of order
            error = {:error, {:version_order_issue, prev_version, event.version}}
            {:halt, {error, event.version}}
        end
    end)

    result
  end

  @doc """
  Validates that a game has been properly completed.

  ## Parameters
    - events: List of events to check

  ## Returns
    - {:ok, completion_event} - Game is properly completed
    - {:error, reason} - Game is not completed or has issues
  """
  @spec validate_game_completion(list(map())) :: {:ok, map()} | {:error, term()}
  def validate_game_completion(events) do
    completion_event = Enum.find(events, fn e ->
      e.event_type == "game_completed"
    end)

    if completion_event do
      {:ok, completion_event}
    else
      {:error, :game_not_completed}
    end
  end

  @doc """
  Checks for the presence of required events in a game stream.

  ## Parameters
    - events: List of events to check
    - required_types: List of event types that must be present

  ## Returns
    - :ok - All required events are present
    - {:error, {:missing_events, list()}} - Some required events are missing
  """
  @spec check_required_events(list(map()), list(String.t())) :: :ok | {:error, {:missing_events, list()}}
  def check_required_events(events, required_types) do
    # Extract event types from the stream
    event_types = MapSet.new(Enum.map(events, & &1.event_type))

    # Check which required types are missing
    missing = Enum.filter(required_types, fn type ->
      not MapSet.member?(event_types, type)
    end)

    if Enum.empty?(missing) do
      :ok
    else
      {:error, {:missing_events, missing}}
    end
  end

  @doc """
  Verifies a game's event stream for use in a replay.
  Performs all necessary validations.

  ## Parameters
    - events: List of events to verify
    - opts: Additional options for verification
      - :required_events - List of event types that must be present
      - :check_completion - Whether to require game completion (default: true)

  ## Returns
    - :ok - Event stream is valid for replay
    - {:error, reason} - Event stream has issues
  """
  @spec verify_game_stream(list(map()), keyword()) :: :ok | {:error, term()}
  def verify_game_stream(events, opts \\ []) do
    required_events = Keyword.get(opts, :required_events, ["game_started"])
    check_completion = Keyword.get(opts, :check_completion, true)

    with :ok <- verify_event_sequence(events),
         :ok <- check_required_events(events, required_events),
         completion_result <- (if check_completion, do: validate_game_completion(events), else: :ok) do
      case completion_result do
        {:ok, _} -> :ok
        :ok -> :ok
        error -> error
      end
    end
  end
end
