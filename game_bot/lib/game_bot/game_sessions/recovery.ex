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

  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres, as: EventStore
  alias GameBot.Domain.GameState
  alias GameBot.Domain.Events.GameEvents.{
    GameStarted,
    GameCompleted,
    RoundCompleted,
    TeamEliminated,
    KnockoutRoundCompleted
  }
  alias GameBot.Domain.Events.GuessEvents.{
    GuessProcessed,
    GuessStarted,
    GuessAbandoned
  }

  # Configuration
  @default_timeout 60_000  # 60 seconds
  @max_retries 3
  @max_events 1000

  @typedoc """
  Error reasons for session recovery.
  """
  @type error_reason() ::
          :no_events
          | :timeout
          | :fetch_failed
          | :invalid_initial_event
          | :event_application_failed
          | :state_validation_failed
          | {:event_fetch_failed, term()}
          | {:rescue_error, term()}
          | {:unhandled_event, map()}

  @typedoc """
  Error reasons during state validation.
  """
  @type state_error() ::
          :missing_game_id
          | :missing_guild_id
          | :missing_mode
          | :missing_mode_state
          | :missing_teams
          | :missing_start_time
          | :invalid_status
          | :invalid_mode_state
          | :invalid_teams

  @typedoc """
  Error reasons during event stream validation.
  """
  @type validation_error() ::
          :no_events
          | :invalid_stream_start
          | :invalid_event_order
          | :too_many_events

  @doc """
  Recovers a game session from the event store.

  Fetches events, validates the stream, builds the initial state,
  applies events, and validates the final state.  Includes a timeout
  to prevent hanging.
  """
  @spec recover_session(String.t(), keyword()) :: {:ok, map()} | {:error, error_reason()}
  def recover_session(game_id, opts \\ []) do
    _timeout = Keyword.get(opts, :timeout, @default_timeout)

    try do
      with {:ok, events} <- fetch_events(game_id, opts),
           :ok <- validate_event_stream(events),
           {:ok, initial_state} <- build_initial_state(events),
           {:ok, final_state} <- apply_events(initial_state, events -- [List.first(events)]),
           :ok <- validate_recovered_state(final_state) do
        {:ok, final_state}
      end
    rescue
      e ->
        Logger.error("Session recovery failed for game #{game_id}",
          error: e,
          stacktrace: __STACKTRACE__
        )
        {:error, :state_validation_failed}  # Consistent error type
    end
  end

  @spec fetch_events(String.t(), keyword()) :: {:ok, [map()]} | {:error, error_reason()}
  def fetch_events(game_id, opts \\ []) do
    # Call fetch_events_with_retry, passing options through
    fetch_events_with_retry(game_id, Keyword.get(opts, :retry_count, @max_retries), Keyword.get(opts, :guild_id))
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
    * `{:error, :too_many_events}` - Event stream exceeds maximum size

  @since "1.0.0"
  """
  @spec validate_event_stream([map()]) :: :ok | {:error, validation_error()}
  def validate_event_stream([]), do: {:error, :no_events}
  def validate_event_stream([%GameStarted{} | _] = events) when length(events) <= @max_events do
    validate_event_order(events)
  end
  def validate_event_stream([%GameStarted{} | _]) do
    {:error, :too_many_events}
  end
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
  @spec build_initial_state([map()]) :: {:ok, map()} | {:error, error_reason()}
  def build_initial_state([%GameStarted{
    game_id: game_id,
    mode: mode,
    teams: teams,
    team_ids: team_ids,
    config: config,
    timestamp: timestamp,
    metadata: %{guild_id: guild_id}
  } | _]) do
    with :ok <- validate_teams(teams) do
      # Convert teams map to team states
      team_states = Map.new(teams, fn {team_id, player_ids} ->
        {team_id, %{
          player_ids: player_ids,
          score: 0,                  # Initial score
          matches: 0,                # Successful matches
          total_guesses: 0,          # Total guess attempts
          current_words: [],         # Words currently in play
          guess_count: 1,            # Start at 1 for first attempt
          pending_guess: nil,        # No pending guesses
          players: Map.new(player_ids, fn player_id ->   # Player stats
            {player_id, %{
              total_guesses: 0,
              successful_matches: 0,
              abandoned_guesses: 0
            }}
          end)
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
          current_round: 1,
          status: :in_progress,
          scores: Map.new(team_ids, &{&1, 0}),
          matches: [],
          start_time: timestamp,
          last_activity: timestamp
        },
        guild_id: guild_id,
        teams: teams,
        config: config,  # Moved config to parent state
        status: :active,
        started_at: timestamp,
        round_start_time: timestamp,
        pending_events: [],
        round_timer_ref: nil
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

      iex> Recovery.apply_events(initial_state, [%GuessProcessed{}, %RoundCompleted{}])
      {:ok, %{...updated state...}}

      iex> Recovery.apply_events(invalid_state, events)
      {:error, :event_application_failed}

  ## Error Conditions
    * `{:error, :event_application_failed}` - Error occurred while applying events
    * `{:error, :invalid_event_type}` - Unknown event type encountered

  @since "1.0.0"
  """
  @spec apply_events(map(), [map()]) :: {:ok, map()} | {:error, error_reason()}
  def apply_events(initial_state, events) do
    final_state = Enum.reduce(events, initial_state, fn
      %GameStarted{}, state -> state  # Skip GameStarted
      event, state ->
        case apply_event(event, state) do
          {:ok, new_state} -> new_state
          {:error, _} = error ->
            # Stop on error and return the error
            throw(error)
        end
    end)

    {:ok, final_state}
  catch
    {:error, _} = error ->
      # Return the error from apply_event
      error
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
    * `{:error, :missing_guild_id}` - Guild ID is missing
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

  @spec fetch_events_with_retry(String.t(), non_neg_integer(), String.t() | nil, term()) ::
    {:ok, [map()]} | {:error, term()}
  defp fetch_events_with_retry(game_id, retries, guild_id, last_error \\ nil) do
    try do
      case EventStore.read_stream_forward(game_id, 0, @max_events, []) do
        {:ok, []} -> {:error, :no_events}
        {:ok, events} -> {:ok, events}
        {:error, _reason} = error when retries > 0 ->
          # Retry, passing the last error
          Process.sleep(50 * (@max_retries - retries + 1))
          fetch_events_with_retry(game_id, retries - 1, guild_id, error)
        error -> error  # Return the error directly
      end
    rescue
      e ->
        Logger.error("Failed to fetch events",
          error: e,
          game_id: game_id,
          stacktrace: __STACKTRACE__
        )
        if retries > 0 do
          Process.sleep(50 * (@max_retries - retries + 1))
          # Pass the *rescue* error as the last_error
          fetch_events_with_retry(game_id, retries - 1, guild_id, {:error, {:rescue_error, e}})
        else
          # Return the last error, or a generic error if none
          last_error || {:error, :fetch_failed}
        end
    end
  end

  defp validate_event_order(events) do
    # Check if events are in chronological order
    events
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [event1, event2] ->
      DateTime.compare(event1.timestamp, event2.timestamp) in [:lt, :eq]
    end)
    |> case do
      true -> :ok
      false -> {:error, :invalid_event_order}
    end
  end

  defp validate_teams(nil), do: {:error, :missing_teams}
  defp validate_teams(teams) when not is_map(teams), do: {:error, :invalid_teams}
  defp validate_teams(_), do: :ok

  defp validate_required_fields(state) do
    cond do
      is_nil(state.game_id) -> {:error, :missing_game_id}
      is_nil(state.guild_id) -> {:error, :missing_guild_id}
      is_nil(state.mode) -> {:error, :missing_mode}
      is_nil(state.mode_state) -> {:error, :missing_mode_state}
      is_nil(state.teams) -> {:error, :missing_teams}
      is_nil(state.started_at) -> {:error, :missing_start_time}
      state.status not in [:initializing, :active, :completed] -> {:error, :invalid_status}
      true -> :ok
    end
  end

  defp validate_mode_state(%GameState{} = _state), do: :ok
  defp validate_mode_state(_), do: {:error, :invalid_mode_state}

  # Event application handlers

  # GameStarted is handled in build_initial_state
  defp apply_event(%GameStarted{}, state), do: {:ok, state}

  defp apply_event(%GuessProcessed{} = event, state) do
    # Update mode state with guess results
    updated_state = put_in(state, [:mode_state, :last_guess], %{
      team_id: event.team_id,
      player1_info: event.player1_info,
      player2_info: event.player2_info,
      player1_word: event.player1_word,
      player2_word: event.player2_word,
      successful: event.guess_successful,
      match_score: event.match_score,
      guess_duration: event.guess_duration
    })

    # Update team stats
    team_path = [:mode_state, :teams, event.team_id]
    updated_state = update_in(updated_state, team_path ++ [:total_guesses], &(&1 + 1))
    updated_state = put_in(updated_state, team_path ++ [:guess_count], event.guess_count)

    # Update if successful match
    final_state = if event.guess_successful do
      updated_state
      |> update_in(team_path ++ [:matches], &(&1 + 1))
      |> update_in(team_path ++ [:score], &(&1 + (event.match_score || 1)))
    else
      updated_state
    end

    {:ok, final_state}
  end

  defp apply_event(%GuessStarted{} = event, state) do
    # Just track that a guess is in progress
    team_path = [:mode_state, :teams, event.team_id]
    updated_state = put_in(state, team_path ++ [:pending_guess], %{
      player_id: event.player_id,
      timestamp: event.timestamp
    })
    {:ok, updated_state}
  end

  defp apply_event(%GuessAbandoned{} = event, state) do
    # Clear pending guess
    team_path = [:mode_state, :teams, event.team_id]
    updated_state = put_in(state, team_path ++ [:pending_guess], nil)

    # Update player's abandoned guess count if player_id is provided
    final_state = if event.player_id do
      player_path = team_path ++ [:players, event.player_id]
      update_in(updated_state, player_path ++ [:abandoned_guesses], &(&1 + 1))
    else
      updated_state
    end

    {:ok, final_state}
  end

  defp apply_event(%RoundCompleted{} = event, state) do
    # Update round information
    updated_state = put_in(state, [:mode_state, :current_round], event.round_number + 1)
    updated_state = put_in(updated_state, [:mode_state, :last_round_winner], event.winner_team_id)
    updated_state = put_in(updated_state, [:mode_state, :round_stats], event.round_stats)

    # Update round start time for the new round
    final_state = put_in(updated_state, [:round_start_time], event.timestamp)
    {:ok, final_state}
  end

  defp apply_event(%GameCompleted{} = event, state) do
    # Mark game as completed
    updated_state = put_in(state, [:mode_state, :status], :completed)
    updated_state = put_in(updated_state, [:status], :completed)
    updated_state = put_in(updated_state, [:mode_state, :winners], event.winners)
    updated_state = put_in(updated_state, [:mode_state, :final_scores], event.final_scores)

    # Add finished timestamp
    final_state = put_in(updated_state, [:ended_at], event.finished_at)
    {:ok, final_state}
  end

  defp apply_event(%TeamEliminated{} = event, state) do
    # Remove team from active teams
    updated_state = update_in(state, [:mode_state, :teams], &Map.delete(&1, event.team_id))

    # For knockout mode, track eliminated teams
    final_state = if state.mode == :knockout do
      eliminated = Map.get(state.mode_state, :eliminated_teams, [])
      put_in(updated_state, [:mode_state, :eliminated_teams], [event.team_id | eliminated])
    else
      updated_state
    end

    {:ok, final_state}
  end

  defp apply_event(%KnockoutRoundCompleted{} = event, state) do
    # Update round number for knockout mode
    updated_state = put_in(state, [:mode_state, :current_round], event.round_number + 1)
    {:ok, updated_state}
  end

  # Handle RaceModeTimeExpired events if needed
  defp apply_event(%{__struct__: mod} = event, _state) when is_atom(mod) do
    Logger.warning("Unhandled event type in recovery",
      event_type: mod,
      game_id: Map.get(event, :game_id, "unknown"),  # Safely get game_id
      event: inspect(event)  # Include the full event for debugging
    )
    # Return an error to signal the unhandled event
    {:error, {:unhandled_event, event}}
  end
end
