defmodule GameBot.Replay.VersionCompatibility do
  @moduledoc """
  Handles version compatibility for events in the replay system.

  This module provides:
  - Version checking for event types
  - Compatibility mapping between event versions
  - Support for version differences in replays
  - Version-aware event processing
  """

  require Logger

  # Map of event types to their supported versions
  # For each event type, specify a list of supported versions and the latest version
  @supported_versions %{
    "game_started" => %{versions: [1], latest: 1},
    "round_started" => %{versions: [1], latest: 1},
    "guess_processed" => %{versions: [1], latest: 1},
    "guess_abandoned" => %{versions: [1], latest: 1},
    "team_eliminated" => %{versions: [1], latest: 1},
    "game_completed" => %{versions: [1], latest: 1},
    "knockout_round_completed" => %{versions: [1], latest: 1},
    "race_mode_time_expired" => %{versions: [1], latest: 1}
  }

  @doc """
  Checks if an event version is supported.

  ## Parameters
    - event_type: The type of the event
    - version: The version to check

  ## Returns
    - :ok - Version is supported
    - {:error, reason} - Version is not supported
  """
  @spec check_version(String.t(), pos_integer()) :: :ok | {:error, term()}
  def check_version(event_type, version) do
    case Map.get(@supported_versions, event_type) do
      nil ->
        {:error, {:unsupported_event_type, event_type}}

      %{versions: supported_versions} ->
        if version in supported_versions do
          :ok
        else
          {:error, {:unsupported_version, event_type, version, supported_versions}}
        end
    end
  end

  @doc """
  Gets the latest supported version for an event type.

  ## Parameters
    - event_type: The type of the event

  ## Returns
    - {:ok, version} - Latest supported version
    - {:error, reason} - Event type not supported
  """
  @spec latest_version(String.t()) :: {:ok, pos_integer()} | {:error, term()}
  def latest_version(event_type) do
    case Map.get(@supported_versions, event_type) do
      nil ->
        {:error, {:unsupported_event_type, event_type}}

      %{latest: latest} ->
        {:ok, latest}
    end
  end

  @doc """
  Builds a version map for a list of events.
  The map tracks which version is used for each event type in the stream.

  ## Parameters
    - events: List of events to analyze

  ## Returns
    - version_map: Map of event types to their versions
  """
  @spec build_version_map(list(map())) :: %{String.t() => pos_integer()}
  def build_version_map(events) do
    events
    |> Enum.group_by(& &1.event_type)
    |> Map.new(fn {event_type, events} ->
      # Find the most common version for this event type
      version = events
        |> Enum.frequencies_by(& &1.event_version)
        |> Enum.max_by(fn {_v, count} -> count end, fn -> {1, 0} end)
        |> elem(0)

      {event_type, version}
    end)
  end

  @doc """
  Validates an event against the supported versions.

  ## Parameters
    - event: The event to validate

  ## Returns
    - :ok - Event is valid
    - {:error, reason} - Event has version issues
  """
  @spec validate_event(map()) :: :ok | {:error, term()}
  def validate_event(%{event_type: event_type, event_version: version}) do
    check_version(event_type, version)
  end

  def validate_event(%{"event_type" => event_type, "event_version" => version}) do
    check_version(event_type, version)
  end

  def validate_event(event) do
    Logger.warning("Invalid event format for version validation: #{inspect(event)}")
    {:error, :invalid_event_format}
  end

  @doc """
  Processes an event with version awareness.
  Handles version compatibility when necessary.

  ## Parameters
    - event: The event to process
    - handlers: Map of functions to handle different versions
    - default_handler: Function to use for unspecified versions

  ## Returns
    - {:ok, result} - Successfully processed event
    - {:error, reason} - Failed to process event
  """
  @spec process_versioned_event(map(), %{pos_integer() => (map() -> term())}, (map() -> term())) ::
        {:ok, term()} | {:error, term()}
  def process_versioned_event(event, handlers, default_handler \\ nil) do
    version = Map.get(event, :event_version) || 1

    handler = Map.get(handlers, version, default_handler)

    if handler do
      try do
        result = handler.(event)
        {:ok, result}
      rescue
        e ->
          Logger.error("Error processing event with version #{version}: #{inspect(e)}")
          {:error, :processing_error}
      end
    else
      {:error, {:unsupported_version, event.event_type, version}}
    end
  end

  @doc """
  Validates a set of events for replay compatibility.

  ## Parameters
    - events: List of events to validate

  ## Returns
    - {:ok, version_map} - All events are compatible, with version map
    - {:error, issues} - Some events have compatibility issues
  """
  @spec validate_replay_compatibility(list(map())) :: {:ok, map()} | {:error, list()}
  def validate_replay_compatibility(events) do
    # Check each event against supported versions
    issues = Enum.reduce(events, [], fn event, issues ->
      case validate_event(event) do
        :ok -> issues
        {:error, reason} -> [{event, reason} | issues]
      end
    end)

    if Enum.empty?(issues) do
      {:ok, build_version_map(events)}
    else
      {:error, Enum.reverse(issues)}
    end
  end
end
