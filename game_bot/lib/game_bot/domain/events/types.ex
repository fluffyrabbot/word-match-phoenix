defmodule GameBot.Domain.Events.Types do
  @moduledoc """
  Defines common types used across event modules.
  Provides type specifications for metadata, player info, team state, event results,
  and common enumerations used in events.
  """

  # ========== Core Types ==========

  @type event_id :: String.t()
  @type event_type :: String.t()
  @type event_version :: pos_integer()
  @type timestamp :: DateTime.t()
  @type game_mode :: :two_player | :knockout | :race

  # ========== Metadata Types ==========

  @type metadata :: %{
    optional(:guild_id) => String.t(),         # Guild where the event occurred (optional for DMs)
    required(:source_id) => String.t(),        # Source identifier (message/interaction ID)
    required(:correlation_id) => String.t(),   # For tracking related events
    optional(:causation_id) => String.t(),     # ID of event that caused this event
    optional(:actor_id) => String.t(),         # User who triggered the action
    optional(:client_version) => String.t(),   # Client version
    optional(:server_version) => String.t(),   # Server version
    optional(:user_agent) => String.t(),       # Client agent info
    optional(:ip_address) => String.t()        # IP address (for security)
  }

  @type validation_error :: {:error, String.t()}

  # ========== Entity Types ==========

  @type team_state :: %{
    required(:team_id) => String.t(),
    required(:player_ids) => [String.t()],
    required(:status) => atom(),
    optional(:guess_count) => non_neg_integer(),
    optional(:score) => non_neg_integer()
  }

  # ========== Result Types ==========

  @type event_result :: {:ok, struct()} | {:error, term()}

  # ========== Event Attribute Types ==========

  @type event_attrs :: %{
    required(:game_id) => String.t(),
    required(:guild_id) => String.t(),
    required(:mode) => game_mode(),
    required(:round_number) => pos_integer(),
    required(:timestamp) => timestamp(),
    required(:metadata) => metadata(),
    optional(:guess_duration) => non_neg_integer(),
    optional(:player1_duration) => non_neg_integer(),
    optional(:player2_duration) => non_neg_integer(),
    optional(atom()) => term()
  }

  # ========== Error Reason Types ==========

  @type guess_error_reason :: :invalid_word | :not_players_turn | :word_already_guessed |
                             :invalid_player | :invalid_team

  @type guess_pair_error_reason :: :invalid_word_pair | :not_teams_turn | :words_already_guessed |
                                  :invalid_team | :same_words

  @type game_error_reason :: :game_not_found | :game_already_exists |
                            :invalid_game_state | :invalid_operation

  @type round_check_error_reason :: :invalid_round_state | :round_already_ended |
                                   :round_not_started | atom()

  @type guess_abandoned_reason :: :timeout | :user_cancelled | :system_cancelled
end
