defmodule GameBot.Domain.Projections.GameProjection do
  @moduledoc """
  Projection for building game-related read models from events.
  Ensures proper guild segregation for game data.
  """

  alias GameBot.Domain.Events.GameEvents.{
    GameCreated,
    GameStarted,
    GameFinished,
    RoundStarted,
    RoundFinished
  }

  defmodule GameSummaryView do
    @moduledoc "Read model for game summary data with guild context"
    @type t :: %__MODULE__{
      game_id: String.t(),
      mode: String.t(),
      guild_id: String.t(),
      team_ids: [String.t()],
      status: :created | :active | :completed,
      created_at: DateTime.t(),
      started_at: DateTime.t() | nil,
      finished_at: DateTime.t() | nil,
      winner_team_id: String.t() | nil,
      final_score: map() | nil,
      total_rounds: integer() | nil
    }
    defstruct [
      :game_id, :mode, :guild_id, :team_ids, :status, :created_at,
      :started_at, :finished_at, :winner_team_id, :final_score, :total_rounds
    ]
  end

  defmodule RoundView do
    @moduledoc "Read model for game round data"
    @type t :: %__MODULE__{
      game_id: String.t(),
      round_number: integer(),
      guild_id: String.t(),
      started_at: DateTime.t(),
      finished_at: DateTime.t() | nil,
      winner_team_id: String.t() | nil,
      round_score: map() | nil,
      round_stats: map() | nil
    }
    defstruct [
      :game_id, :round_number, :guild_id, :started_at,
      :finished_at, :winner_team_id, :round_score, :round_stats
    ]
  end

  def handle_event(%GameCreated{} = event) do
    game = %GameSummaryView{
      game_id: event.game_id,
      mode: event.mode,
      guild_id: event.guild_id,
      team_ids: event.team_ids,
      status: :created,
      created_at: event.created_at,
      started_at: nil,
      finished_at: nil,
      winner_team_id: nil,
      final_score: nil,
      total_rounds: event.config[:rounds] || 1
    }

    {:ok, {:game_created, game}}
  end

  def handle_event(%GameStarted{} = event, %{game: game}) do
    updated_game = %GameSummaryView{game |
      status: :active,
      started_at: event.started_at
    }

    {:ok, {:game_started, updated_game}}
  end

  def handle_event(%GameFinished{} = event, %{game: game}) do
    updated_game = %GameSummaryView{game |
      status: :completed,
      finished_at: event.finished_at,
      winner_team_id: event.winner_team_id,
      final_score: event.final_score
    }

    {:ok, {:game_finished, updated_game}}
  end

  def handle_event(%RoundStarted{} = event) do
    round = %RoundView{
      game_id: event.game_id,
      round_number: event.round_number,
      guild_id: event.guild_id,
      started_at: event.started_at,
      finished_at: nil,
      winner_team_id: nil,
      round_score: nil,
      round_stats: nil
    }

    {:ok, {:round_started, round}}
  end

  def handle_event(%RoundFinished{} = event, %{round: round}) do
    updated_round = %RoundView{round |
      finished_at: event.finished_at,
      winner_team_id: event.winner_team_id,
      round_score: event.round_score,
      round_stats: event.round_stats
    }

    {:ok, {:round_finished, updated_round}}
  end

  def handle_event(_, state), do: {:ok, state}

  # Query functions - all filter by guild_id for data segregation

  def get_game(_game_id, _guild_id) do
    # Filter by both game_id and guild_id
    # This is a placeholder - actual implementation would depend on your storage
    {:error, :not_implemented}
  end

  def list_active_games(_guild_id) do
    # Filter by guild_id and status: active
    {:error, :not_implemented}
  end

  def list_recent_games(_guild_id, _limit \\ 10) do
    # Filter by guild_id and sort by created_at
    {:error, :not_implemented}
  end

  def get_user_games(_user_id, _guild_id, _limit \\ 10) do
    # Filter by guild_id and games where user participated
    {:error, :not_implemented}
  end

  def get_game_rounds(_game_id, _guild_id) do
    # Filter by game_id and guild_id
    {:error, :not_implemented}
  end

  def get_game_statistics(_guild_id, _time_range \\ nil) do
    # Aggregate statistics filtered by guild_id
    {:error, :not_implemented}
  end
end
