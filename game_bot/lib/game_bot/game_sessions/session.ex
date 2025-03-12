defmodule GameBot.GameSessions.Session do
  @moduledoc """
  GenServer managing an active game session.
  Handles state management while delegating game logic to the appropriate game mode.
  """
  use GenServer
  require Logger

  alias GameBot.Bot.CommandHandler
  alias GameBot.Domain.{GameState, WordService}
  alias GameBot.Domain.Events.GameEvents
  alias GameBot.Infrastructure.Persistence.EventStore
  alias GameBot.Domain.Events.GameEvents.GameCompleted
  alias GameBot.Domain.Events.ErrorEvents.{GuessError, GuessPairError, RoundCheckError}

  # Constants for timeouts
  @round_check_interval :timer.seconds(5)  # How often to check round status

  # Client API

  @doc """
  Starts a new game session.
  """
  @spec start_link(Keyword.t()) :: {:ok, pid()} | {:error, term()} | :ignore
  def start_link(opts) do
    game_id = Keyword.fetch!(opts, :game_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(game_id))
  end

  @doc """
  Creates a new game session from a GameStarted event.
  """
  @spec create_game(GameEvents.GameStarted.t()) :: {:ok, pid()} | {:error, term()}
  def create_game(%GameEvents.GameStarted{} = event) do
    opts = [
      game_id: event.game_id,
      mode: event.mode,
      mode_config: event.config,
      guild_id: event.guild_id,
      teams: event.teams
    ]

    GameBot.GameSessions.Supervisor.start_game(opts)
  end

  @doc """
  Submits a guess for the given team.
  """
  def submit_guess(game_id, team_id, player_id, word) do
    GenServer.cast(via_tuple(game_id), {:submit_guess, team_id, player_id, word})
  end

  @doc """
  Gets the current state of the game.
  """
  def get_state(game_id) do
    GenServer.call(via_tuple(game_id), :get_state)
  end

  @doc """
  Checks if the current round should end.
  """
  def check_round_end(game_id) do
    GenServer.call(via_tuple(game_id), :check_round_end)
  end

  @doc """
  Checks if the game should end.
  """
  def check_game_end(game_id) do
    GenServer.call(via_tuple(game_id), :check_game_end)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    game_id = Keyword.fetch!(opts, :game_id)
    mode = Keyword.fetch!(opts, :mode)
    mode_config = Keyword.fetch!(opts, :mode_config)
    guild_id = Keyword.fetch!(opts, :guild_id)
    teams = Keyword.fetch!(opts, :teams)

    # Capture the initial time as the round start time
    start_time = DateTime.utc_now()

    # Initialize the game mode
    case apply(mode, :init, [game_id, teams, mode_config]) do
      {:ok, mode_state, events} ->
        state = %{
          game_id: game_id,
          guild_id: guild_id,
          mode: mode,
          mode_state: mode_state,
          teams: teams,
          started_at: start_time,
          round_start_time: start_time, # Track when the current round started
          status: :initializing,
          round_timer_ref: nil,
          pending_events: events  # Track events that need to be persisted
        }
        {:ok, state, {:continue, :post_init}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  @spec handle_continue(atom(), map()) :: {:noreply, map()} | {:stop, term(), term()}
  def handle_continue(:post_init, state) do
    # Persist any initialization events
    # Handle potential errors from persist_events
    case persist_events(state.pending_events, state) do
      :ok ->
        # Register players in the active games ETS table
        register_players(state)

        # Start round management
        ref = schedule_round_check(state)

        {:noreply, %{state | status: :active, round_timer_ref: ref, pending_events: []}}
      {:error, reason} ->
        # Handle persistence failure during initialization
        Logger.error("Failed to persist initialization events for game #{state.game_id}: #{inspect(reason)}")
        {:stop, {:persistence_failed, reason}, state} # Stop the GenServer and return current state
    end
  end

  @impl true
  def handle_call({:submit_guess, team_id, player_id, word}, _from, state) do
    with :ok <- validate_guild_context(word, player_id, state),
         :ok <- validate_guess(word, player_id, state),
         {:ok, mode_state, events} <- record_guess(team_id, player_id, word, state) do

      # Persist events **before** modifying state
      # Handle potential errors from persist_events
      case persist_events(events, state) do
        :ok ->
          # Process complete guess pair if available
          case mode_state.pending_guess do
            %{player1_word: word1, player2_word: word2} ->
              handle_guess_pair(word1, word2, team_id, %{state | mode_state: mode_state}, events)

            _ ->
              # Only reply, do NOT persist events here.
              {:reply, {:ok, :pending}, %{state | mode_state: mode_state, pending_events: []}}
          end
        {:error, reason} ->
          # Handle persistence failure
          Logger.error("Failed to persist events for game #{state.game_id}: #{inspect(reason)}")
          {:reply, {:error, :persistence_failed}, state}
      end
    else
      {:error, reason} ->
        error_event = GuessError.new(state.game_id, team_id, player_id, word, reason)
        case persist_events([error_event], state) do
          :ok ->
            {:reply, {:error, reason}, state}
          {:error, persistence_reason} ->
            Logger.error("Failed to persist GuessError for game #{state.game_id}: #{inspect(persistence_reason)}")
            {:reply, {:error, :persistence_failed}, state}
        end
    end
  end

  @impl true
  def handle_call(:check_round_end, _from, state) do
    case state.mode.check_round_end(state.mode_state) do
      {:round_end, winners, events} ->
        # First update state with round results
        {updated_state, round_events} = update_round_results(state, winners)

        # Persist round end events
        case persist_events(events ++ round_events, updated_state) do
          :ok ->
            # Then check if game should end
            case apply(state.mode, :check_game_end, [updated_state.mode_state]) do
              {:game_end, game_winners, game_events} ->
                handle_game_end(game_winners, updated_state, game_events)
              :continue ->
                # Start new round if game continues
                {new_state, new_round_events} = start_new_round(updated_state)
                case persist_events(new_round_events, new_state) do
                  :ok ->
                    {:reply, {:round_end, winners}, new_state}
                  {:error, reason} ->
                    Logger.error("Failed to persist new round events for game #{updated_state.game_id}: #{inspect(reason)}")
                    {:reply, {:error, :persistence_failed}, updated_state}
                end
            end
          {:error, reason} ->
            Logger.error("Failed to persist round end events for game #{updated_state.game_id}: #{inspect(reason)}")
            {:reply, {:error, :persistence_failed}, state} #important to return original state
        end
      :continue ->
        {:reply, :continue, state}
      {:error, reason} ->
        error_event = RoundCheckError.new(state.game_id, reason, %{})
        case persist_events([error_event], state) do
          :ok ->
            {:reply, {:error, reason}, state}
          {:error, persistence_reason} ->
            Logger.error("Failed to persist RoundCheckError for game #{state.game_id}: #{inspect(persistence_reason)}")
            {:reply, {:error, :persistence_failed}, state}
        end
    end
  end

  @impl true
  def handle_call(:check_game_end, _from, state) do
    case apply(state.mode, :check_game_end, [state.mode_state]) do
      {:game_end, winners, events} ->
        # Process game end events
        updated_state = %{state | status: :completed}

        # Create the game completed event
        final_scores = compute_final_scores(state)
        game_duration = DateTime.diff(DateTime.utc_now(), state.started_at)
        now = DateTime.utc_now()

        game_completed = GameCompleted.new(
          state.game_id,
          state.guild_id,
          state.mode,
          1,  # round_number (default)
          winners,
          final_scores,
          game_duration,
          1,  # total_rounds (default)
          now,  # timestamp
          now   # finished_at
        )

        # Persist events
        case persist_events([game_completed | events], updated_state) do
          :ok ->
            {:reply, {:ok, :game_completed}, updated_state}
          {:error, reason} ->
            Logger.error("Failed to persist game completion events for game #{state.game_id}: #{inspect(reason)}")
            {:reply, {:error, :persistence_failed}, state} #important to return original state
        end

      :continue ->
        {:reply, {:ok, :continue}, state}

      unexpected ->  # Catch-all for unexpected return values
        Logger.error("Unexpected return from check_game_end: #{inspect(unexpected)} in game #{state.game_id}")
        {:reply, {:error, :unexpected_response}, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, %{game_id: state.game_id, status: state.status, teams: state.teams}}, state}
  end

  @impl true
  def handle_cast({:submit_guess, team_id, player_id, word}, state) do
    with :ok <- validate_guild_context(word, player_id, state),
         :ok <- validate_guess(word, player_id, state),
         {:ok, mode_state, events} <- record_guess(team_id, player_id, word, state) do
      # Persist events **before** modifying state
      case persist_events(events, state) do
        :ok ->
          # Process complete guess pair if available
          case mode_state.pending_guess do
            %{player1_word: word1, player2_word: word2} ->
              # Since handle_cast can't return a reply, we need to handle errors differently
              # We'll process the guess pair and then return a noreply
              case state.mode.process_guess_pair(state.mode_state, team_id, %{
                player1_id: mode_state.pending_guess.player1_id,
                player2_id: mode_state.pending_guess.player2_id,
                player1_word: word1,
                player2_word: word2,
                player1_duration: mode_state.pending_guess.player1_duration,
                player2_duration: mode_state.pending_guess.player2_duration
              }) do
                {:ok, new_mode_state, pair_events} ->
                  case persist_events(pair_events, state) do
                    :ok ->
                      {:noreply, %{state | mode_state: new_mode_state}}
                    {:error, reason} ->
                      Logger.error("Failed to persist guess pair events for game #{state.game_id}: #{inspect(reason)}")
                      {:noreply, state}
                  end
                {:error, reason} ->
                  error_event = GuessPairError.new(state.game_id, team_id, word1, word2, reason)
                  case persist_events([error_event], state) do
                    :ok ->
                      {:noreply, state}
                    {:error, persist_reason} ->
                      Logger.error("Failed to persist error event for game #{state.game_id}: #{inspect(persist_reason)}")
                      {:noreply, state}
                  end
              end

            :pending ->
              {:noreply, %{state | mode_state: mode_state, pending_events: []}}
          end
        {:error, reason} ->
          # Handle persistence failure.
          Logger.error("Failed to persist events for game #{state.game_id}: #{inspect(reason)}")
          {:noreply, state}
      end
    else
      {:error, reason} ->
        error_event = GuessError.new(state.game_id, team_id, player_id, word, reason)
        case persist_events([error_event], state) do
          :ok ->
            {:noreply, state}
          {:error, persistence_reason} ->
            Logger.error("Failed to persist GuessError for game #{state.game_id}: #{inspect(persistence_reason)}")
            {:noreply, state}
        end
    end
  end

  @impl true
  def handle_info(:check_round_status, state) do
    if not is_nil(state.round_timer_ref), do: Process.cancel_timer(state.round_timer_ref)

    case check_round_end(state.game_id) do
      {:reply, :continue, updated_state} ->
        ref = schedule_round_check(state)
        {:noreply, %{updated_state | round_timer_ref: ref}}

      {:reply, {:round_end, _}, updated_state} ->
        {:noreply, %{updated_state | round_timer_ref: nil}}

      {:reply, {:error, _}, _} ->
        # In case of error, reschedule the check
        ref = schedule_round_check(state)
        {:noreply, %{state | round_timer_ref: ref}}
    end
  end

  @impl true
  def terminate(_reason, state) do
    # Clean up timer
    if state.round_timer_ref, do: Process.cancel_timer(state.round_timer_ref)

    # Clean up active game registrations
    unregister_players(state)
    :ok
  end

  # Private Functions

  defp via_tuple(game_id) do
    {:via, Registry, {GameBot.GameSessions.Registry, game_id}}
  end

  @dialyzer {:nowarn_function, register_players: 1}
  defp register_players(%{teams: teams, game_id: game_id}) do
    for {_team_id, %{player_ids: player_ids}} <- teams,
        player_id <- player_ids,
        CommandHandler.get_active_game(player_id, game_id) == nil do  # Check for existing game using get_active_game
      CommandHandler.set_active_game(player_id, game_id, game_id)
    end
  end

  defp unregister_players(%{teams: teams, game_id: game_id}) do
    for {_team_id, %{player_ids: player_ids}} <- teams,
        player_id <- player_ids do
      CommandHandler.clear_active_game(player_id, game_id)
    end
  end

  defp validate_guess(word, player_id, state) do
    # First check if player already has a pending guess
    team_id = find_player_team(state, player_id)
    team_state = get_in(state.mode_state.teams, [team_id])

    cond do
      # Check for nil or empty word *before* other checks
      word in [nil, ""] ->
        {:error, :invalid_word}

      # Check if player has already submitted a guess
      has_player_submitted?(team_state, player_id) ->
        {:error, :guess_already_submitted}

      # Special handling for "give up" command
      word == "give up" ->
        :ok

      # Normal word validation
      not WordService.valid_word?(word) ->
        {:error, :invalid_word}

      GameState.word_forbidden?(state.mode_state, state.guild_id, player_id, word) == {:ok, true} ->
        {:error, :forbidden_word}

      true ->
        :ok
    end
  end

  defp record_guess(team_id, player_id, word, state) do
    team_state = get_in(state.mode_state.teams, [team_id])
    now = DateTime.utc_now()

    case team_state.pending_guess do
      nil ->
        # First guess of the pair
        {:ok,
         put_in(state.mode_state.teams[team_id].pending_guess, %{
           player_id: player_id,
           word: word,
           timestamp: now
         }),
         []} # No events for first guess

      %{player_id: pending_player_id} = pending when pending_player_id != player_id ->
        # Second guess - create complete pair with timing information

        # Check if the player is still in the game
        if player_id not in state.teams[team_id].player_ids do
          {:error, :player_not_in_game}
        else
          # Calculate durations from round start time for both players
          player1_timestamp = pending.timestamp
          player2_timestamp = now

          player1_duration = DateTime.diff(player1_timestamp, state.round_start_time, :millisecond)
          player2_duration = DateTime.diff(player2_timestamp, state.round_start_time, :millisecond)

          {:ok,
           put_in(state.mode_state.teams[team_id].pending_guess, %{
             player1_id: pending_player_id,
             player2_id: player_id,
             player1_word: pending.word,
             player2_word: word,
             player1_timestamp: player1_timestamp,
             player2_timestamp: player2_timestamp,
             player1_duration: player1_duration,
             player2_duration: player2_duration
           }),
           []} # Events will be generated when processing the complete pair
        end

      _ ->
        {:error, :guess_already_submitted}
    end
  end

  # Helper functions for guess validation

  defp find_player_team(%{mode_state: %{teams: teams}}, player_id) do
    Enum.find_value(teams, fn {team_id, team_state} ->
      if player_id in team_state.player_ids, do: team_id, else: nil
    end)
  end

  defp has_player_submitted?(%{pending_guess: nil}, _player_id), do: false

  defp has_player_submitted?(%{pending_guess: %{player_id: pending_id}}, player_id) do
    pending_id == player_id
  end

  defp has_player_submitted?(%{pending_guess: %{player1_id: p1, player2_id: p2}}, player_id) do
    player_id in [p1, p2]
  end

  defp has_player_submitted?(_, _), do: false

  defp persist_events(events, state), do: persist_events(events, state, 3)

  defp persist_events(events, state, retries) when retries > 0 do
    case EventStore.append_to_stream(state.game_id, :any_version, events, []) do
      :ok -> :ok

      {:error, reason}
      when reason == :connection_timeout or
             reason == :database_unavailable or
             reason == :timeout or
             (is_tuple(reason) and elem(reason, 0) == :shutdown) and retries > 1 ->
        delay = trunc(:math.pow(2, (3 - retries)) * 50) # Exponential backoff: 50ms -> 100ms -> 200ms
        Logger.warning("Retrying event persistence for game #{state.game_id} in #{delay}ms (#{retries - 1} retries left)")
        Process.sleep(delay)
        persist_events(events, state, retries - 1)

      {:error, reason} ->
        Logger.error("Permanent failure persisting events for game #{state.game_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # dialyzer: {:nowarn_function, handle_guess_pair: 5}
  defp handle_guess_pair(word1, word2, team_id, state, _previous_events) do
    # Extract or create the guess pair with timing information
    pending_guess = get_in(state.mode_state.teams, [team_id, :pending_guess])

    guess_pair = %{
      player1_id: pending_guess.player1_id,
      player2_id: pending_guess.player2_id,
      player1_word: word1,
      player2_word: word2
    }

    # Add timing information if available
    guess_pair = if Map.has_key?(pending_guess, :player1_duration) do
      guess_pair
      |> Map.put(:player1_duration, pending_guess.player1_duration)
      |> Map.put(:player2_duration, pending_guess.player2_duration)
    else
      # Fallback to calculate from round start if not explicitly tracked
      now = DateTime.utc_now()
      duration = DateTime.diff(now, state.round_start_time, :millisecond)
      guess_pair
      |> Map.put(:player1_duration, duration)
      |> Map.put(:player2_duration, duration)
    end

    case state.mode.process_guess_pair(state.mode_state, team_id, guess_pair) do
      {:ok, new_mode_state, events} ->
        # Persist all events
        case persist_events(events, state) do
          :ok ->
            # Return result based on match status
            result = if Enum.any?(events, fn
              %GameBot.Domain.Events.GuessEvents.GuessProcessed{guess_successful: true} -> true
              _ -> false
            end), do: :match, else: :no_match
            {:reply, {:ok, result}, %{state | mode_state: new_mode_state}}

          {:error, reason} ->
            Logger.error("Failed to persist events for game #{state.game_id}: #{inspect(reason)}")
            {:reply, {:error, :persistence_failed}, state}
        end

      {:error, reason} ->
        error_event = GuessPairError.new(state.game_id, team_id, word1, word2, reason)
        case persist_events([error_event], state) do
          :ok ->
            {:reply, {:error, reason}, state}
          {:error, persist_reason} ->
            Logger.error("Failed to persist error event for game #{state.game_id}: #{inspect(persist_reason)}")
            {:reply, {:error, :persistence_failed}, state}
        end

      other ->
        raise "Unexpected return value from process_guess_pair: #{inspect(other)}"
    end
  end


  defp schedule_round_check(state) do
    if not is_nil(state.round_timer_ref), do: Process.cancel_timer(state.round_timer_ref)
    Process.send_after(self(), :check_round_status, @round_check_interval)
  end

  defp update_round_results(state, winners) do
    # Capture 'now' at the beginning
    now = DateTime.utc_now()

    case apply(state.mode, :update_round_results, [state.mode_state, winners]) do
      {:ok, new_mode_state, events} ->
        # Use Task.Supervisor for non-blocking event persistence

        updated_state = %{state | mode_state: new_mode_state, round_start_time: now}
        {updated_state, events}

      {:error, reason} ->
        # Log the error and potentially stop the GenServer or return an error tuple
        Logger.error("Error updating round results for game #{state.game_id}: #{reason}")
        #  Consider what the appropriate action is here.  You might:
        #  1. Stop the GenServer:  {:stop, {:round_update_failed, reason}}
        #  2. Return an error tuple: {state, [{:error, :round_update_failed}]}  (less likely)
        # For now, I'll assume you want to stop the GenServer:
        {:stop, {:round_update_failed, reason}}
    end
  end

  # dialyzer: {:nowarn_function, start_new_round: 1}
  defp start_new_round(state) do
    # Capture 'now' at the beginning
    now = DateTime.utc_now()

    case apply(state.mode, :start_new_round, [state.mode_state]) do
      {:ok, new_mode_state, events} ->
        {%{state |
          mode_state: new_mode_state,
          round_timer_ref: nil,  # We'll set this in handle_info
          round_start_time: now  # Reset round start time for new round
        }, events}

      {:error, reason} ->
        Logger.error("Failed to start new round for game #{state.game_id}: #{inspect(reason)}")
        {:stop, {:new_round_failed, reason}}
    end
  end

  # dialyzer: {:nowarn_function, handle_game_end: 3}
  defp handle_game_end(winners, state, events) do
    # Capture 'now' at the beginning
    now = DateTime.utc_now()

    final_state = %{state |
      status: :completed,
      round_timer_ref: nil,
      mode_state: %{state.mode_state | winners: winners},
      ended_at: now
    }

    # Clean up timers and registrations
    if state.round_timer_ref, do: Process.cancel_timer(state.round_timer_ref)
    unregister_players(state)

    # Persist game end events *synchronously* and handle the result
    case persist_events(events, final_state) do
      :ok ->
        {:reply, {:game_end, winners}, final_state}
      {:error, reason} ->
        Logger.error("Game #{state.game_id} failed to finalize: #{inspect(reason)}")
        {:reply, {:error, :persistence_failed}, state}  # Return an error
    end
  end

  defp validate_guild_context(_word, player_id, %{guild_id: guild_id} = _state) do
    # Check if this player belongs to this guild
    # This is a simplified check - you would need to implement actual guild membership validation
    if player_in_guild?(player_id, guild_id) do
      :ok
    else
      {:error, :not_in_guild}
    end
  end

  defp player_in_guild?(_player_id, _guild_id) do
    # Implementation would depend on how you store guild memberships
    # This is a placeholder
    true
  end

  # Helper to compute detailed final scores for GameCompleted event
  defp compute_final_scores(state) do
    Enum.into(state.teams, %{}, fn {team_id, team_state} ->
      {team_id, %{
        score: team_state.score,
        matches: team_state.matches,
        total_guesses: team_state.total_guesses,
        average_guesses: compute_average_guesses(team_state),
        player_stats: compute_player_stats(team_state)
      }}
    end)
  end

  defp compute_average_guesses(%{total_guesses: total, matches: matches}) when matches > 0 do
    total / matches
  end
  defp compute_average_guesses(_), do: 0.0

  defp compute_player_stats(team_state) do
    team_state.players
    |> Enum.map(fn {player_id, stats} ->
      {player_id, %{
        total_guesses: stats.total_guesses,
        successful_matches: stats.successful_matches,
        abandoned_guesses: stats.abandoned_guesses,
        average_guess_count: compute_average_guesses(stats)
      }}
    end)
    |> Map.new()
  end
end
