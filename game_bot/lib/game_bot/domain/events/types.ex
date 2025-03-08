defmodule GameBot.Domain.Events.Types do
  @moduledoc """
  Defines common types used across event modules.
  Provides type specifications for metadata, player info, team state, and event results.
  """

  @type metadata :: %{
    required(:guild_id) => String.t(),
    required(:correlation_id) => String.t(),
    optional(:causation_id) => String.t(),
    optional(:user_agent) => String.t(),
    optional(:ip_address) => String.t()
  }

  @type player_info :: %{
    required(:player_id) => String.t(),
    required(:team_id) => String.t(),
    optional(:role) => atom()
  }

  @type team_state :: %{
    required(:team_id) => String.t(),
    required(:player_ids) => [String.t()],
    required(:status) => atom(),
    optional(:guess_count) => non_neg_integer(),
    optional(:score) => non_neg_integer()
  }

  @type event_result :: {:ok, struct()} | {:error, term()}

  @type game_mode :: :two_player | :knockout | :race

  @type event_type :: String.t()

  @type event_version :: pos_integer()

  @type event_id :: String.t()

  @type timestamp :: DateTime.t()

  @type event_attrs :: %{
    required(:game_id) => String.t(),
    required(:guild_id) => String.t(),
    required(:mode) => game_mode(),
    required(:round_number) => pos_integer(),
    required(:timestamp) => timestamp(),
    required(:metadata) => metadata(),
    optional(atom()) => term()
  }
end
