defmodule GameBot.GameSessions.Recovery do
  @moduledoc """
  Handles recovery of game sessions from event streams.
  Provides functionality to rebuild game state from persisted events.
  """

  require Logger

  alias GameBot.Domain.Events.{GameEvents, TeamEvents}
  alias GameBot.Infrastructure.EventStore
  alias GameBot.Domain.GameState

  @type error_reason ::
    :no_events
    | :invalid_stream_start
    | :invalid_event_order
    | :invalid_initial_event
    | :event_application_failed
    | :missing_game_id
    | :missing_mode
    | :missing_mode_state
    | :missing_teams
    | :missing_start_time
    | :invalid_status
    | :persist_failed

  @doc """
  Recovers a game session from its event stream.
  Rebuilds the complete game state by applying all events in sequence.

  Returns `{:ok, state}` with the recovered state or `{:error, reason}` if recovery fails.
  """
  @spec recover_session(String.t()) :: {:ok, map()} | {:error, error_reason()}
  def recover_session(game_id) do
    with {:ok, events} <- fetch_events(game_id),
         :ok <- validate_event_stream(events),
         {:ok, initial_state} <- build_initial_state(events),
         {:ok, recovered_state} <- apply_events(initial_state, events),
         :ok <- validate_recovered_state(recovered_state) do
      {:ok, recovered_state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to recover session #{game_id}",
          error: reason,
          game_id: game_id,
          stacktrace: __STACKTRACE__
        )
        error
    end
  end

  @doc """
  Fetches all events for a given game ID from the event store.
  Events are returned in chronological order.
  """
  @spec fetch_events(String.t()) :: {:ok, [Event.t()]} | {:error, error_reason()}
  def fetch_events(game_id) do
    EventStore.read_stream_forward(game_id)
  end

  @doc """
  Validates the event stream for consistency and completeness.
  Ensures events are properly ordered and start with a GameStarted event.
  """
  @spec validate_event_stream([Event.t()]) :: :ok | {:error, error_reason()}
  def validate_event_stream([%GameEvents.GameStarted{} | _] = events), do: validate_event_order(events)
  def validate_event_stream([]), do: {:error, :no_events}
  def validate_event_stream(_), do: {:error, :invalid_stream_start}

  @doc """
  Builds the initial state from the GameStarted event.
  Extracts all necessary information to initialize the game session.
  """
  @spec build_initial_state([Event.t()]) :: {:ok, map()} | {:error, error_reason()}
  def build_initial_state([%GameEvents.GameStarted{
    game_id: game_id,
    mode: mode,
    round_number: round_number,
    teams: teams,
    team_ids: team_ids,
    player_ids: player_ids,
    roles: roles,
    config: config,
    timestamp: timestamp,
    metadata: %{guild_id: guild_id}
  } | _]) do
    initial_state = %{
      game_id: game_id,
      mode: mode,
      mode_state: %GameState{
        round_number: round_number,
        teams: teams,
        team_ids: team_ids,
        player_ids: player_ids,
        roles: roles,
        config: config
      },
      teams: teams,
      started_at: timestamp,
      status: :active,
      guild_id: guild_id,
      round_timer_ref: nil,
      pending_events: []
    }
    {:ok, initial_state}
  end
  def build_initial_state(_), do: {:error, :invalid_initial_event}

  @doc """
  Applies a list of events to rebuild the game state.
  Events are applied in sequence, with each event updating the state.
  """
  @spec apply_events(map(), [Event.t()]) :: {:ok, map()} | {:error, error_reason()}
  def apply_events(initial_state, events) do
    try do
      final_state = events
      |> Enum.group_by(&event_type/1)
      |> Map.to_list()
      |> Enum.reduce(initial_state, fn {_type, type_events}, state ->
        Enum.reduce(type_events, state, &apply_event/2)
      end)
      {:ok, final_state}
    rescue
      e ->
        Logger.error("Error applying events",
          error: e,
          stacktrace: __STACKTRACE__,
          state: initial_state
        )
        {:error, :event_application_failed}
    end
  end

  # Event application functions for each event type
  defp apply_event(%GameEvents.GameStarted{}, state), do: state  # Already handled in build_initial_state

  defp apply_event(%GameEvents.GuessProcessed{} = event, state) do
    Map.update!(state, :mode_state, fn mode_state ->
      %{mode_state |
        guess_count: event.guess_count,
        last_guess: %{
          team_id: event.team_id,
          player1_info: event.player1_info,
          player2_info: event.player2_info,
          player1_word: event.player1_word,
          player2_word: event.player2_word,
          successful: event.guess_successful,
          match_score: event.match_score
        }
      }
    end)
  end

  defp apply_event(%GameEvents.RoundEnded{} = event, state) do
    Map.update!(state, :mode_state, fn mode_state ->
      %{mode_state |
        round_number: mode_state.round_number + 1,
        round_winners: event.winners
      }
    end)
  end

  defp apply_event(%GameEvents.GameCompleted{} = event, state) do
    state
    |> Map.update!(:mode_state, fn mode_state ->
      %{mode_state |
        winners: event.winners,
        status: :completed
      }
    end)
    |> Map.put(:status, :completed)
  end

  defp apply_event(event, state) do
    Logger.warn("Unhandled event type",
      event_type: event.__struct__,
      game_id: state.game_id
    )
    state
  end

  @doc """
  Validates the recovered state for consistency.
  Ensures all required fields are present and have valid values.
  """
  @spec validate_recovered_state(map()) :: :ok | {:error, error_reason()}
  def validate_recovered_state(state) do
    with :ok <- validate_required_fields(state),
         :ok <- validate_mode_state(state.mode_state),
         :ok <- validate_teams(state.teams) do
      :ok
    end
  end

  # Private Helpers

  defp validate_event_order(events) do
    events
    |> Stream.chunk_every(2, 1, :discard)
    |> Stream.take_while(fn [e1, e2] ->
      DateTime.compare(e1.timestamp, e2.timestamp) in [:lt, :eq]
    end)
    |> Stream.run()
    |> case do
      :ok -> :ok
      _ -> {:error, :invalid_event_order}
    end
  end

  defp validate_required_fields(state) do
    cond do
      is_nil(state.game_id) -> {:error, :missing_game_id}
      is_nil(state.mode) -> {:error, :missing_mode}
      is_nil(state.mode_state) -> {:error, :missing_mode_state}
      is_nil(state.teams) -> {:error, :missing_teams}
      is_nil(state.started_at) -> {:error, :missing_start_time}
      not is_atom(state.status) -> {:error, :invalid_status}
      true -> :ok
    end
  end

  defp validate_mode_state(%GameState{} = state), do: :ok
  defp validate_mode_state(_), do: {:error, :invalid_mode_state}

  defp validate_teams(teams) when is_map(teams), do: :ok
  defp validate_teams(_), do: {:error, :invalid_teams}

  defp event_type(event), do: event.__struct__
end
