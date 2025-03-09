defmodule GameBot.Replay.Types do
  @moduledoc """
  Type definitions for the replay system.
  """

  @type replay_id :: String.t()
  @type game_id :: String.t()
  @type display_name :: String.t()
  @type event_count :: non_neg_integer()

  @typedoc """
  Type definition for a replay reference.
  Contains metadata about a replay but not the actual events.
  """
  @type replay_reference :: %{
    replay_id: replay_id(),
    game_id: game_id(),
    display_name: display_name(),
    created_at: DateTime.t(),
    mode: game_mode(),
    start_time: DateTime.t(),
    end_time: DateTime.t(),
    event_count: event_count(),
    base_stats: base_stats(),
    mode_stats: mode_stats(),
    version_map: %{String.t() => pos_integer()}
  }

  @typedoc """
  Type definition for base statistics common to all game modes.
  """
  @type base_stats :: %{
    duration_seconds: non_neg_integer(),
    total_guesses: non_neg_integer(),
    player_count: non_neg_integer(),
    team_count: non_neg_integer(),
    rounds: non_neg_integer()
  }

  @typedoc """
  Type definition for mode-specific statistics.
  Different game modes will have different statistics.
  """
  @type mode_stats :: two_player_stats() | knockout_stats() | race_stats() | golf_race_stats()

  @typedoc """
  Type definition for two-player game mode statistics.
  """
  @type two_player_stats :: %{
    successful_guesses: non_neg_integer(),
    failed_guesses: non_neg_integer(),
    team_scores: %{String.t() => non_neg_integer()},
    winning_team: String.t() | nil,
    average_guess_time: float() | nil
  }

  @typedoc """
  Type definition for knockout game mode statistics.
  """
  @type knockout_stats :: %{
    rounds: non_neg_integer(),
    eliminations: %{non_neg_integer() => [String.t()]},
    team_stats: %{String.t() => %{
      eliminated_in_round: non_neg_integer() | nil,
      total_guesses: non_neg_integer(),
      successful_guesses: non_neg_integer()
    }},
    winning_team: String.t() | nil
  }

  @typedoc """
  Type definition for race game mode statistics.
  """
  @type race_stats :: %{
    team_progress: %{String.t() => non_neg_integer()},
    team_speeds: %{String.t() => float()},
    winning_team: String.t() | nil,
    match_completion_time: non_neg_integer() | nil
  }

  @typedoc """
  Type definition for golf race game mode statistics.
  """
  @type golf_race_stats :: %{
    team_scores: %{String.t() => non_neg_integer()},
    team_efficiency: %{String.t() => float()},
    winning_team: String.t() | nil,
    best_round: non_neg_integer()
  }

  @typedoc """
  Game modes supported by the system.
  """
  @type game_mode :: :two_player | :knockout | :race | :golf_race

  @typedoc """
  Type definition for an error that may occur during replay handling.
  """
  @type replay_error ::
    :invalid_game_id |
    :game_not_found |
    :game_not_completed |
    :invalid_event_sequence |
    :missing_required_events |
    :unsupported_event_version |
    :invalid_event_format |
    {:version_gap, non_neg_integer(), non_neg_integer()} |
    {:missing_events, [String.t()]} |
    {:unsupported_version, String.t(), pos_integer(), [pos_integer()]} |
    {:fetch_failed, term()}

  @typedoc """
  Type definition for replay creation options.
  """
  @type replay_creation_opts :: %{
    check_completion: boolean(),
    required_events: [String.t()],
    max_events: pos_integer(),
    custom_display_name: String.t() | nil
  }

  @typedoc """
  Type definition for a replay query filter.
  """
  @type replay_filter :: %{
    game_id: String.t() | nil,
    mode: game_mode() | nil,
    display_name: String.t() | nil,
    created_after: DateTime.t() | nil,
    created_before: DateTime.t() | nil,
    limit: pos_integer() | nil,
    offset: non_neg_integer() | nil
  }
end
