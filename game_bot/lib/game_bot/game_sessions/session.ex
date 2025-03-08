defmodule GameBot.GameSessions.Session do
  @moduledoc """
  GenServer managing an active game session.
  Handles state management while delegating game logic to the appropriate game mode.
  """
  use GenServer
  require Logger

  alias GameBot.Bot.CommandHandler
  alias GameBot.Domain.{GameState, WordService, Events}
  alias GameBot.Domain.Events.{
    GameEvents,
    ErrorEvents.GuessError,
    ErrorEvents.GuessPairError,
    ErrorEvents.RoundCheckError
  }
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Base, as: EventStore
  alias GameBot.Domain.Events.{EventRegistry, Metadata}
  alias GameBot.Domain.Events.GameEvents.{GameCompleted, GuessProcessed}
  alias GameBot.Domain.Events.ErrorEvents.{GuessError, GuessPairError}

  # Constants for timeouts
  @round_check_interval :timer.seconds(5)  # How often to check round status

  # Client API

  @doc """
  Starts a new game session.
  """
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
    GenServer.call(via_tuple(game_id), {:submit_guess, team_id, player_id, word})
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

    # Initialize the game mode
    case apply(mode, :init, [game_id, teams, mode_config]) do
      {:ok, mode_state, events} ->
        state = %{
          game_id: game_id,
          guild_id: guild_id,
          mode: mode,
          mode_state: mode_state,
          teams: teams,
          started_at: DateTime.utc_now(),
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
  def handle_continue(:post_init, state) do
    # Persist any initialization events
    :ok = persist_events(state.pending_events, state)

    # Register players in the active games ETS table
    register_players(state)

    # Start round management
    ref = schedule_round_check()

    {:noreply, %{state | status: :active, round_timer_ref: ref, pending_events: []}}
  end

  @impl true
  def handle_call({:submit_guess, team_id, player_id, word}, _from, state) do
    with :ok <- validate_guild_context(word, player_id, state),
         :ok <- validate_guess(word, player_id, state),
         {:ok, mode_state, events} <- record_guess(team_id, player_id, word, state) do

      # Process complete guess pair if available
      case mode_state.pending_guess do
        %{player1_word: word1, player2_word: word2} ->
          handle_guess_pair(word1, word2, team_id, %{state | mode_state: mode_state}, events)

        :pending ->
          # Persist events from recording the guess
          :ok = persist_events(events, state)
          {:reply, {:ok, :pending}, %{state | mode_state: mode_state, pending_events: []}}
      end
    else
      {:error, reason} ->
        error_event = GuessError.new(state.game_id, team_id, player_id, word, reason)
        :ok = persist_events([error_event], state)
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:check_round_end, _from, state) do
    case state.mode.check_round_end(state.mode_state) do
      {:round_end, winners, events} ->
        # First update state with round results
        {updated_state, round_events} = update_round_results(state, winners)

        # Persist round end events
        :ok = persist_events(events ++ round_events, updated_state)

        # Then check if game should end
        case apply(state.mode, :check_game_end, [updated_state.mode_state]) do
          {:game_end, game_winners, game_events} ->
            handle_game_end(game_winners, updated_state, game_events)
          :continue ->
            # Start new round if game continues
            {new_state, new_round_events} = start_new_round(updated_state)
            :ok = persist_events(new_round_events, new_state)
            {:reply, {:round_end, winners}, new_state}
        end
      :continue ->
        {:reply, :continue, state}
      {:error, reason} ->
        error_event = RoundCheckError.new(state.game_id, reason)
        :ok = persist_events([error_event], state)
        {:reply, {:error, reason}, state}
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

        game_completed = Events.GameCompleted.new(
          state.game_id,
          state.guild_id,
          state.mode,
          winners,
          final_scores,
          game_duration
        )

        # Persist events
        {:ok, _} = EventStore.append_to_stream(
          state.game_id,
          :any_version,
          [game_completed | events]
        )

        {:reply, {:ok, :game_completed}, updated_state}

      :continue ->
        {:reply, {:ok, :continue}, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_info(:check_round_status, state) do
    # Check round status and reschedule
    case check_round_end(state.game_id) do
      {:reply, :continue, state} ->
        ref = schedule_round_check()
        {:noreply, %{state | round_timer_ref: ref}}
      {:reply, {:round_end, _}, _} = _result ->
        # Round ended, don't reschedule
        {:noreply, %{state | round_timer_ref: nil}}
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
    {:via, Registry, {GameBot.GameRegistry, game_id}}
  end

  defp register_players(%{teams: teams, game_id: game_id}) do
    for {_team_id, %{player_ids: player_ids}} <- teams,
        player_id <- player_ids do
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
      # Check if player has already submitted a guess
      has_player_submitted?(team_state, player_id) ->
        {:error, :guess_already_submitted}

      # Special handling for "give up" command
      word == "give up" ->
        :ok

      # Normal word validation
      !WordService.valid_word?(word) ->
        {:error, :invalid_word}

      GameState.word_forbidden?(state.mode_state, state.guild_id, player_id, word) == {:ok, true} ->
        {:error, :forbidden_word}

      true ->
        :ok
    end
  end

  defp record_guess(team_id, player_id, word, state) do
    team_state = get_in(state.mode_state.teams, [team_id])

    case team_state.pending_guess do
      nil ->
        # First guess of the pair
        {:ok,
          put_in(state.mode_state.teams[team_id].pending_guess, %{
            player_id: player_id,
            word: word,
            timestamp: DateTime.utc_now()
          }),
          []  # No events for first guess
        }

      %{player_id: pending_player_id} = pending when pending_player_id != player_id ->
        # Second guess - create complete pair
        {:ok,
          put_in(state.mode_state.teams[team_id].pending_guess, %{
            player1_id: pending_player_id,
            player2_id: player_id,
            player1_word: pending.word,
            player2_word: word
          }),
          []  # Events will be generated when processing the complete pair
        }

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
  defp has_player_submitted?(%{pending_guess: %{player_id: pending_id}}, player_id), do: pending_id == player_id
  defp has_player_submitted?(%{pending_guess: %{player1_id: p1, player2_id: p2}}, player_id), do: player_id in [p1, p2]
  defp has_player_submitted?(_, _), do: false

  defp persist_events(game_id, events) do
    # Use the adapter's safe functions instead of direct EventStore access
    EventStore.append_to_stream(game_id, :any, events)
  end

  defp handle_guess_pair(word1, word2, team_id, state, previous_events) do
    case state.mode.process_guess_pair(state.mode_state, team_id, {word1, word2}) do
      {:ok, new_mode_state, events} ->
        # Persist all events
        :ok = persist_events(events, state)

        # Return result based on match status
        result = if Enum.any?(events, fn
          %GameBot.Domain.Events.GuessEvents.GuessProcessed{guess_successful: true} -> true
          _ -> false
        end), do: :match, else: :no_match
        {:reply, {:ok, result}, %{state | mode_state: new_mode_state}}

      {:error, reason} ->
        error_event = GuessPairError.new(state.game_id, team_id, word1, word2, reason)
        :ok = persist_events([error_event], state)
        {:reply, {:error, reason}, state}
    end
  end

  defp schedule_round_check do
    Process.send_after(self(), :check_round_status, @round_check_interval)
  end

  defp update_round_results(state, winners) do
    case apply(state.mode, :handle_round_end, [state.mode_state, winners]) do
      {:ok, new_mode_state, events} ->
        {%{state | mode_state: new_mode_state}, events}
    end
  end

  defp start_new_round(state) do
    case apply(state.mode, :start_new_round, [state.mode_state]) do
      {:ok, new_mode_state, events} ->
        ref = schedule_round_check()
        {%{state | mode_state: new_mode_state, round_timer_ref: ref}, events}
    end
  end

  defp handle_game_end(winners, state, events) do
    # Create final game state
    final_state = %{state |
      status: :completed,
      round_timer_ref: nil,
      mode_state: %{state.mode_state | winners: winners}
    }

    # Clean up timers and registrations
    if state.round_timer_ref, do: Process.cancel_timer(state.round_timer_ref)
    unregister_players(state)

    # Persist game end events
    :ok = persist_events(events, final_state)

    {:reply, {:game_end, winners}, final_state}
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
    state.teams
    |> Enum.map(fn {team_id, team_state} ->
      {team_id, %{
        score: team_state.score,
        matches: team_state.matches,
        total_guesses: team_state.total_guesses,
        average_guesses: compute_average_guesses(team_state),
        player_stats: compute_player_stats(team_state)
      }}
    end)
    |> Map.new()
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
