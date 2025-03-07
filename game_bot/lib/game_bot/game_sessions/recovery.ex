defmodule GameBot.GameSessions.Recovery do
  @moduledoc """
  Handles recovery of game sessions from event streams.
  Provides functionality to rebuild game state from persisted events.

  ## Features
  - Complete state reconstruction from events
  - Event stream validation
  - State validation and verification
  - Error handling with detailed context
  - Automatic retry for transient failures
  - Timeout handling for operations

  ## Usage Examples

      # Recover a game session
      {:ok, state} = Recovery.recover_session("game-123")

      # Fetch and validate events
      {:ok, events} = Recovery.fetch_events("game-123")
      :ok = Recovery.validate_event_stream(events)

  ## Error Handling
  The module provides detailed error information for recovery failures:
  - `:no_events` - Stream is empty
  - `:invalid_stream_start` - Stream doesn't start with GameStarted
  - `:invalid_event_order` - Events are out of order
  - `:invalid_initial_event` - First event is malformed
  - `:event_application_failed` - Error applying events
  - `:missing_required_fields` - State is missing required data
  - `:timeout` - Operation timed out
  - `:too_many_events` - Event stream exceeds maximum size

  @since "1.0.0"
  """

  require Logger

  alias GameBot.Domain.Events.{GameEvents, TeamEvents}
  alias GameBot.Infrastructure.EventStore
  alias GameBot.Domain.GameState
  alias GameBot.Domain.Events.GameEvents.{
    GameStarted,
    RoundEnded,
    RoundStarted,
    GameCompleted
  }

  # Configuration
  @default_timeout :timer.seconds(30)
  @max_retries 3
  @max_events 10_000
  @retry_base_delay 50  # Base delay in ms for exponential backoff

  @type validation_error ::
    :no_events |
    :invalid_stream_start |
    :invalid_event_order |
    :invalid_initial_event |
    :too_many_events

  @type state_error ::
    :missing_game_id |
    :missing_mode |
    :missing_mode_state |
    :missing_teams |
    :missing_start_time |
    :invalid_status |
    :invalid_mode_state |
    :invalid_teams

  @type error_reason ::
    validation_error() |
    state_error() |
    :event_application_failed |
    :recovery_failed |
    :timeout

  @doc """
  Recovers a game session from its event stream.
  Rebuilds the complete game state by applying all events in sequence.

  ## Parameters
    * `game_id` - The ID of the game session to recover
    * `opts` - Recovery options:
      * `:timeout` - Operation timeout in milliseconds (default: 30000)
      * `:retry_count` - Number of retries for transient errors (default: 3)

  ## Returns
    * `{:ok, state}` - Successfully recovered state
    * `{:error, reason}` - Recovery failed

  ## Examples

      iex> Recovery.recover_session("game-123")
      {:ok, %{game_id: "game-123", mode: TwoPlayerMode, ...}}

      iex> Recovery.recover_session("nonexistent")
      {:error, :no_events}

      iex> Recovery.recover_session("game-123", timeout: 5000)
      {:error, :timeout}

  ## Error Conditions
    * `{:error, :no_events}` - No events found for game
    * `{:error, :invalid_stream_start}` - First event is not GameStarted
    * `{:error, :event_application_failed}` - Error applying events
    * `{:error, :missing_required_fields}` - Recovered state is invalid
    * `{:error, :timeout}` - Operation timed out
    * `{:error, :too_many_events}` - Event stream exceeds maximum size

  @since "1.0.0"
  """
  @spec recover_session(String.t(), keyword()) :: {:ok, map()} | {:error, error_reason()}
  def recover_session(game_id, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    retry_count = Keyword.get(opts, :retry_count, @max_retries)
    guild_id = Keyword.get(opts, :guild_id)

    task = Task.async(fn ->
      try do
        with {:ok, events} <- fetch_events_with_retry(game_id, retry_count, guild_id),
             :ok <- validate_event_stream(events),
             {:ok, initial_state} <- build_initial_state(events),
             {:ok, recovered_state} <- apply_events(initial_state, events),
             :ok <- validate_recovered_state(recovered_state) do
          if guild_id && recovered_state.guild_id != guild_id do
            {:error, :guild_mismatch}
          else
            {:ok, recovered_state}
          end
        end
      rescue
        e ->
          Logger.error("Failed to recover session",
            error: e,
            game_id: game_id,
            stacktrace: __STACKTRACE__
          )
          {:error, :recovery_failed}
      end
    end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, :timeout}
    end
  end

  @doc """
  Fetches all events for a given game ID from the event store.
  Events are returned in chronological order.

  ## Parameters
    * `game_id` - The ID of the game to fetch events for
    * `opts` - Fetch options:
      * `:timeout` - Operation timeout in milliseconds (default: 30000)
      * `:retry_count` - Number of retries for transient errors (default: 3)

  ## Returns
    * `{:ok, events}` - List of events in chronological order
    * `{:error, reason}` - Failed to fetch events

  ## Examples

      iex> Recovery.fetch_events("game-123")
      {:ok, [%GameStarted{}, %GuessProcessed{}]}

      iex> Recovery.fetch_events("nonexistent")
      {:error, :no_events}

  @since "1.0.0"
  """
  @spec fetch_events(String.t(), keyword()) :: {:ok, [Event.t()]} | {:error, error_reason()}
  def fetch_events(game_id, opts \\ []) do
    # Use the adapter's safe functions instead of direct EventStore access
    alias GameBot.Infrastructure.Persistence.EventStore.Adapter, as: EventStore
    case EventStore.read_stream_forward(game_id, 0, @max_events, opts) do
      {:ok, events} -> {:ok, events}
      {:error, reason} -> {:error, {:event_fetch_failed, reason}}
    end
  end

  @doc """
  Validates the event stream for consistency and completeness.
  Ensures events are properly ordered and start with a GameStarted event.

  ## Parameters
    * `events` - List of events to validate

  ## Returns
    * `:ok` - Event stream is valid
    * `{:error, reason}` - Validation failed

  ## Examples

      iex> Recovery.validate_event_stream([%GameStarted{}, %GuessProcessed{}])
      :ok

      iex> Recovery.validate_event_stream([%GuessProcessed{}])
      {:error, :invalid_stream_start}

      iex> Recovery.validate_event_stream([])
      {:error, :no_events}

  ## Error Conditions
    * `{:error, :no_events}` - Event stream is empty
    * `{:error, :invalid_stream_start}` - First event is not GameStarted
    * `{:error, :invalid_event_order}` - Events are not in chronological order

  @since "1.0.0"
  """
  @spec validate_event_stream([Event.t()]) :: :ok | {:error, validation_error()}
  def validate_event_stream([%GameStarted{} | _] = events), do: validate_event_order(events)
  def validate_event_stream([]), do: {:error, :no_events}
  def validate_event_stream(_), do: {:error, :invalid_stream_start}

  @doc """
  Builds the initial state from the GameStarted event.
  Extracts all necessary information to initialize the game session.

  ## Parameters
    * `events` - List of events, first event must be GameStarted

  ## Returns
    * `{:ok, state}` - Successfully built initial state
    * `{:error, reason}` - Failed to build initial state

  ## Examples

      iex> Recovery.build_initial_state([%GameStarted{game_id: "123", mode: TwoPlayerMode, ...}])
      {:ok, %{game_id: "123", mode: TwoPlayerMode, ...}}

      iex> Recovery.build_initial_state([%GuessProcessed{}])
      {:error, :invalid_initial_event}

  ## Error Conditions
    * `{:error, :invalid_initial_event}` - First event is not a valid GameStarted event
    * `{:error, :missing_required_fields}` - GameStarted event is missing required fields

  @since "1.0.0"
  """
  @spec build_initial_state([Event.t()]) :: {:ok, map()} | {:error, error_reason()}
  def build_initial_state([%GameStarted{
    game_id: game_id,
    mode: mode,
    teams: teams,
    team_ids: team_ids,
    config: _config,
    timestamp: timestamp,
    metadata: %{guild_id: guild_id}
  } | _]) do
    with :ok <- validate_teams(teams) do
      # Convert teams map to team states
      team_states = Map.new(teams, fn {team_id, player_ids} ->
        {team_id, %{
          player_ids: player_ids,
          current_words: [],
          guess_count: 1,  # Start at 1 for first attempt
          pending_guess: nil
        }}
      end)

      # Build forbidden words map from all player IDs
      forbidden_words = teams
      |> Enum.flat_map(fn {_team_id, player_ids} -> player_ids end)
      |> Map.new(fn player_id -> {player_id, []} end)

      {:ok, %{
        game_id: game_id,
        mode: mode,
        mode_state: %GameState{
          guild_id: guild_id,
          mode: mode,
          teams: team_states,
          team_ids: team_ids,
          forbidden_words: forbidden_words,
          round_number: 1,
          start_time: timestamp,
          last_activity: timestamp,
          matches: [],
          scores: %{},
          status: :waiting
        },
        teams: teams,
        started_at: timestamp,
        status: :active,
        guild_id: guild_id,
        round_timer_ref: nil,
        pending_events: []
      }}
    end
  end
  def build_initial_state(_), do: {:error, :invalid_initial_event}

  @doc """
  Applies a list of events to rebuild the game state.
  Events are applied in sequence, with each event updating the state.

  ## Parameters
    * `initial_state` - Base state to apply events to
    * `events` - List of events to apply

  ## Returns
    * `{:ok, state}` - Successfully applied all events
    * `{:error, reason}` - Failed to apply events

  ## Examples

      iex> Recovery.apply_events(initial_state, [%GuessProcessed{}, %RoundEnded{}])
      {:ok, %{...updated state...}}

      iex> Recovery.apply_events(invalid_state, events)
      {:error, :event_application_failed}

  ## Error Conditions
    * `{:error, :event_application_failed}` - Error occurred while applying events
    * `{:error, :invalid_event_type}` - Unknown event type encountered

  @since "1.0.0"
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
          state: initial_state,
          stacktrace: __STACKTRACE__
        )
        {:error, :event_application_failed}
    end
  end

  @doc """
  Validates the recovered state for consistency.
  Ensures all required fields are present and have valid values.

  ## Parameters
    * `state` - Recovered game state to validate

  ## Returns
    * `:ok` - State is valid
    * `{:error, reason}` - State validation failed

  ## Examples

      iex> Recovery.validate_recovered_state(valid_state)
      :ok

      iex> Recovery.validate_recovered_state(%{})
      {:error, :missing_game_id}

  ## Error Conditions
    * `{:error, :missing_game_id}` - Game ID is missing
    * `{:error, :missing_mode}` - Game mode is missing
    * `{:error, :missing_mode_state}` - Mode state is missing
    * `{:error, :missing_teams}` - Teams are missing
    * `{:error, :missing_start_time}` - Start time is missing
    * `{:error, :invalid_status}` - Status is invalid
    * `{:error, :invalid_mode_state}` - Mode state is invalid
    * `{:error, :invalid_teams}` - Teams structure is invalid

  @since "1.0.0"
  """
  @spec validate_recovered_state(map()) :: :ok | {:error, error_reason()}
  def validate_recovered_state(state) do
    with :ok <- validate_required_fields(state),
         :ok <- validate_mode_state(state.mode_state),
         :ok <- validate_teams(state.teams) do
      :ok
    end
  end

  # Private Functions

  defp fetch_events_with_retry(game_id, retries, guild_id \\ nil) do
    opts = if guild_id, do: [guild_id: guild_id], else: []

    case EventStore.read_stream_forward(game_id, 0, @max_events, opts) do
      {:ok, []} ->
        {:error, :no_events}
      {:ok, events} when length(events) > @max_events ->
        {:error, :too_many_events}
      {:ok, events} ->
        {:ok, events}
      {:error, %EventStore.Error{type: :connection}} = error when retries > 0 ->
        Process.sleep(exponential_backoff(retries))
        fetch_events_with_retry(game_id, retries - 1)
      error ->
        error
    end
  end

  defp exponential_backoff(retry) do
    # 50ms, 100ms, 200ms, etc.
    trunc(:math.pow(2, @max_retries - retry) * @retry_base_delay)
  end

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

  defp validate_teams(teams) do
    cond do
      is_nil(teams) ->
        {:error, :missing_teams}
      not is_map(teams) ->
        {:error, :invalid_teams}
      true ->
        :ok
    end
  end

  defp validate_required_fields(state) do
    cond do
      is_nil(state.game_id) -> {:error, :missing_game_id}
      is_nil(state.guild_id) -> {:error, :missing_guild_id}
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

  defp event_type(event), do: event.__struct__

  defp apply_event(%GameStarted{}, state), do: state  # Already handled in build_initial_state

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

  defp apply_event(%RoundEnded{} = event, state) do
    Map.update!(state, :mode_state, fn mode_state ->
      %{mode_state |
        round_number: mode_state.round_number + 1,
        round_winners: event.winners
      }
    end)
  end

  defp apply_event(%GameCompleted{} = event, state) do
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
    Logger.warning("Unhandled event type", event_type: event.__struct__)
    state
  end
end
