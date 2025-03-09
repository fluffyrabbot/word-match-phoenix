defmodule GameBot.Replay.Utils.StatsCalculator do
  @moduledoc """
  Calculates statistics from game events for replay summaries.

  This module provides functions to:
  - Calculate base statistics for all game modes
  - Generate mode-specific statistics
  - Process event streams efficiently
  """

  alias GameBot.Replay.Types
  require Logger

  @doc """
  Calculates base statistics common to all game modes.

  ## Parameters
    - events: List of game events to analyze

  ## Returns
    - {:ok, stats} - Successfully calculated statistics
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
        Logger.error("Error calculating base stats: #{inspect(e)}")
        {:error, :stats_calculation_error}
    end
  end

  @doc """
  Calculates statistics for two-player mode games.

  ## Parameters
    - events: List of game events to analyze

  ## Returns
    - {:ok, stats} - Successfully calculated statistics
    - {:error, reason} - Failed to calculate statistics
  """
  @spec calculate_two_player_stats(list(map())) :: {:ok, Types.two_player_stats()} | {:error, term()}
  def calculate_two_player_stats(events) do
    try do
      # Count successful and failed guesses
      guess_events = Enum.filter(events, fn e -> e.event_type == "guess_processed" end)

      successful_guesses = Enum.count(guess_events, & &1.guess_successful)
      failed_guesses = length(guess_events) - successful_guesses

      # Calculate team scores
      team_scores = guess_events
        |> Enum.filter(& &1.guess_successful)
        |> Enum.group_by(& &1.team_id)
        |> Enum.map(fn {team_id, guesses} -> {team_id, length(guesses)} end)
        |> Enum.into(%{})

      # Find winning team (highest score)
      winning_team = if Enum.empty?(team_scores) do
        nil
      else
        team_scores
        |> Enum.max_by(fn {_, score} -> score end)
        |> elem(0)
      end

      # Calculate average guess time
      average_guess_time = if length(guess_events) > 0 do
        total_time = guess_events
          |> Enum.filter(& &1.guess_duration)  # Ensure duration exists
          |> Enum.map(& &1.guess_duration)
          |> Enum.sum()

        total_time / length(guess_events)
      else
        nil
      end

      stats = %{
        successful_guesses: successful_guesses,
        failed_guesses: failed_guesses,
        team_scores: team_scores,
        winning_team: winning_team,
        average_guess_time: average_guess_time
      }

      {:ok, stats}
    rescue
      e ->
        Logger.error("Error calculating two-player stats: #{inspect(e)}")
        {:error, :stats_calculation_error}
    end
  end

  @doc """
  Calculates statistics for knockout mode games.

  ## Parameters
    - events: List of game events to analyze

  ## Returns
    - {:ok, stats} - Successfully calculated statistics
    - {:error, reason} - Failed to calculate statistics
  """
  @spec calculate_knockout_stats(list(map())) :: {:ok, Types.knockout_stats()} | {:error, term()}
  def calculate_knockout_stats(events) do
    try do
      # Get round info
      round_events = Enum.filter(events, fn e -> e.event_type == "knockout_round_completed" end)
      rounds = length(round_events) + 1  # Add initial round

      # Track eliminations by round
      elimination_events = Enum.filter(events, fn e -> e.event_type == "team_eliminated" end)

      eliminations = elimination_events
        |> Enum.group_by(& &1.round_number)
        |> Enum.map(fn {round, events} -> {round, Enum.map(events, & &1.team_id)} end)
        |> Enum.into(%{})

      # Get team stats
      guess_events = Enum.filter(events, fn e -> e.event_type == "guess_processed" end)

      team_stats = events
        |> Enum.filter(fn e -> e.event_type == "game_started" end)
        |> List.first()
        |> Map.get(:team_ids, [])
        |> Enum.map(fn team_id ->
          # Find when/if team was eliminated
          eliminated_in_round = elimination_events
            |> Enum.find(fn e -> e.team_id == team_id end)
            |> case do
              nil -> nil
              event -> event.round_number
            end

          # Count guesses
          team_guesses = Enum.filter(guess_events, fn e -> e.team_id == team_id end)
          successful_guesses = Enum.count(team_guesses, & &1.guess_successful)

          {team_id, %{
            eliminated_in_round: eliminated_in_round,
            total_guesses: length(team_guesses),
            successful_guesses: successful_guesses
          }}
        end)
        |> Enum.into(%{})

      # Find winning team (last team standing)
      winning_team = events
        |> Enum.filter(fn e -> e.event_type == "game_completed" end)
        |> List.first()
        |> case do
          nil -> nil
          event -> Map.get(event, :winning_team) || Map.get(event, :winners)
        end

      # Normalize winning team - it might be a list or a single value
      winning_team = case winning_team do
        [team | _] -> team
        team when is_binary(team) -> team
        _ -> nil
      end

      stats = %{
        rounds: rounds,
        eliminations: eliminations,
        team_stats: team_stats,
        winning_team: winning_team
      }

      {:ok, stats}
    rescue
      e ->
        Logger.error("Error calculating knockout stats: #{inspect(e)}")
        {:error, :stats_calculation_error}
    end
  end

  @doc """
  Calculates statistics for race mode games.

  ## Parameters
    - events: List of game events to analyze

  ## Returns
    - {:ok, stats} - Successfully calculated statistics
    - {:error, reason} - Failed to calculate statistics
  """
  @spec calculate_race_stats(list(map())) :: {:ok, Types.race_stats()} | {:error, term()}
  def calculate_race_stats(events) do
    try do
      # Get game settings for race target
      game_started = Enum.find(events, fn e -> e.event_type == "game_started" end)
      race_target = get_in(game_started, [:config, :race_target]) || 10

      # Track team progress
      guess_events = Enum.filter(events, fn e -> e.event_type == "guess_processed" end)

      team_progress = guess_events
        |> Enum.filter(& &1.guess_successful)
        |> Enum.group_by(& &1.team_id)
        |> Enum.map(fn {team_id, guesses} -> {team_id, length(guesses)} end)
        |> Enum.into(%{})

      # Calculate team speeds (matches per minute)
      game_duration_minutes = case calculate_base_stats(events) do
        {:ok, stats} -> max(stats.duration_seconds / 60, 1)
        _ -> 1  # Default to 1 to avoid division by zero
      end

      team_speeds = team_progress
        |> Enum.map(fn {team_id, matches} ->
          {team_id, matches / game_duration_minutes}
        end)
        |> Enum.into(%{})

      # Find winning team and completion time
      completed_event = Enum.find(events, fn e -> e.event_type == "game_completed" end)

      winning_team = if completed_event do
        Map.get(completed_event, :winning_team) || Map.get(completed_event, :winners)
      else
        team_progress
        |> Enum.filter(fn {_, progress} -> progress >= race_target end)
        |> Enum.max_by(fn {_, progress} -> progress end, fn -> {nil, 0} end)
        |> elem(0)
      end

      # Normalize winning team - it might be a list or a single value
      winning_team = case winning_team do
        [team | _] -> team
        team when is_binary(team) -> team
        _ -> nil
      end

      # Calculate match completion time
      match_completion_time = if completed_event do
        DateTime.diff(completed_event.timestamp, game_started.timestamp)
      else
        nil
      end

      stats = %{
        team_progress: team_progress,
        team_speeds: team_speeds,
        winning_team: winning_team,
        match_completion_time: match_completion_time
      }

      {:ok, stats}
    rescue
      e ->
        Logger.error("Error calculating race stats: #{inspect(e)}")
        {:error, :stats_calculation_error}
    end
  end

  @doc """
  Calculates mode-specific statistics based on game mode.

  ## Parameters
    - events: List of game events to analyze
    - mode: Game mode

  ## Returns
    - {:ok, stats} - Successfully calculated statistics
    - {:error, reason} - Failed to calculate statistics
  """
  @spec calculate_mode_stats(list(map()), atom()) :: {:ok, map()} | {:error, term()}
  def calculate_mode_stats(events, mode) do
    case mode do
      :two_player -> calculate_two_player_stats(events)
      :knockout -> calculate_knockout_stats(events)
      :race -> calculate_race_stats(events)
      :golf_race -> calculate_race_stats(events)  # Temporary - implement dedicated function
      _ -> {:error, :unsupported_mode}
    end
  end
end
