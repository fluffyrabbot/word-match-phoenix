defmodule GameBot.Replay.BaseReplay do
  @moduledoc """
  Defines the behavior for replay implementations.

  This module provides a consistent interface that all game mode replays must implement,
  ensuring that they can be handled uniformly by the system while still allowing
  for mode-specific functionality.
  """

  alias GameBot.Replay.Types

  @doc """
  Builds a replay reference from a game ID.

  This is the main entry point for creating a replay. It must:
  1. Fetch the game's events from the event store
  2. Validate the event sequence
  3. Calculate statistics
  4. Create a memorable display name
  5. Return a lightweight replay reference

  ## Parameters
    - game_id: The ID of the game to create a replay for
    - opts: Optional parameters for replay creation

  ## Returns
    - {:ok, replay_reference} - Successfully created replay reference
    - {:error, reason} - Failed to create replay
  """
  @callback build_replay(game_id :: String.t(), opts :: map()) ::
    {:ok, Types.replay_reference()} | {:error, Types.replay_error()}

  @doc """
  Formats a replay into a Discord embed for display.

  ## Parameters
    - replay: The replay reference to format
    - events: Optional list of events if already loaded

  ## Returns
    - {:ok, embed} - Successfully formatted embed
    - {:error, reason} - Failed to format embed
  """
  @callback format_embed(replay :: Types.replay_reference(), events :: list(map()) | nil) ::
    {:ok, map()} | {:error, term()}

  @doc """
  Creates a summary of the replay.

  ## Parameters
    - replay: The replay reference to summarize

  ## Returns
    - {:ok, summary} - Successfully created summary
    - {:error, reason} - Failed to create summary
  """
  @callback format_summary(replay :: Types.replay_reference()) ::
    {:ok, String.t()} | {:error, term()}

  @doc """
  Calculates mode-specific statistics from events.

  ## Parameters
    - events: List of events to analyze

  ## Returns
    - {:ok, stats} - Successfully calculated statistics
    - {:error, reason} - Failed to calculate statistics
  """
  @callback calculate_mode_stats(events :: list(map())) ::
    {:ok, map()} | {:error, term()}

  @optional_callbacks [calculate_mode_stats: 1]

  @doc """
  Calculates base statistics common to all game modes.

  This is a utility function provided by the behavior module
  that replay implementations can use.

  ## Parameters
    - events: List of events to analyze

  ## Returns
    - {:ok, stats} - Base statistics
    - {:error, reason} - Failed to calculate statistics
  """
  @spec calculate_base_stats(list(map())) :: {:ok, Types.base_stats()} | {:error, term()}
  def calculate_base_stats(events) do
    try do
      # Find game start and end events
      game_started = Enum.find(events, fn e -> e.event_type == "game_started" end)
      game_completed = Enum.find(events, fn e -> e.event_type == "game_completed" end)

      unless game_started do
        raise "Game start event not found"
      end

      # Calculate duration
      end_time = if game_completed do
        game_completed.timestamp
      else
        # If no completion event, use the latest event timestamp
        events
        |> Enum.sort_by(& &1.timestamp, DateTime)
        |> List.last()
        |> Map.get(:timestamp)
      end

      duration_seconds = DateTime.diff(end_time, game_started.timestamp)

      # Count guesses
      guess_events = Enum.filter(events, fn e ->
        e.event_type == "guess_processed"
      end)

      total_guesses = length(guess_events)

      # Extract player and team counts from game_started event
      player_count = length(game_started.player_ids)
      team_count = length(game_started.team_ids)

      # Find max round number
      rounds = events
        |> Enum.map(& &1.round_number)
        |> Enum.max(fn -> 1 end)

      stats = %{
        duration_seconds: duration_seconds,
        total_guesses: total_guesses,
        player_count: player_count,
        team_count: team_count,
        rounds: rounds
      }

      {:ok, stats}
    rescue
      e ->
        require Logger
        Logger.error("Error calculating base stats: #{inspect(e)}")
        {:error, :stats_calculation_error}
    end
  end
end
