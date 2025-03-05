defmodule GameBot.GameSessions.Session do
  @moduledoc """
  GenServer managing an active game session.
  Handles state management while delegating game logic to the appropriate game mode.
  """
  use GenServer
  require Logger

  alias GameBot.Domain.GameModes.BaseMode
  alias GameBot.Bot.CommandHandler
  alias GameBot.Domain.{GameState, WordService, Events}
  alias GameBot.Infrastructure.EventStore

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

    # Initialize the game mode
    case apply(mode, :init, [game_id, mode_config]) do
      {:ok, mode_state, events} ->
        state = %{
          game_id: game_id,
          guild_id: guild_id,
          mode: mode,
          mode_state: mode_state,
          teams: %{},
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
    :ok = persist_events(state.pending_events)

    # Register players in the active games ETS table
    register_players(state)

    # Start round management
    ref = schedule_round_check()

    {:noreply, %{state | status: :active, round_timer_ref: ref, pending_events: []}}
  end

  @impl true
  def handle_call({:submit_guess, team_id, player_id, word}, _from, state) do
    with :ok <- validate_guess(word, player_id, state),
         {:ok, mode_state, events} <- record_guess(team_id, player_id, word, state) do

      # Process complete guess pair if available
      case mode_state.pending_guess do
        %{player1_word: word1, player2_word: word2} ->
          handle_guess_pair(word1, word2, team_id, %{state | mode_state: mode_state}, events)

        :pending ->
          # Persist events from recording the guess
          :ok = persist_events(events)
          {:reply, {:ok, :pending}, %{state | mode_state: mode_state, pending_events: []}}
      end
    else
      {:error, reason} ->
        # Create and persist error event
        error_event = Events.GuessError.new(state.game_id, team_id, player_id, word, reason)
        :ok = persist_events([error_event])
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:check_round_end, _from, state) do
    case apply(state.mode, :check_round_end, [state.mode_state]) do
      {:round_end, winners, events} ->
        # First update state with round results
        {updated_state, round_events} = update_round_results(state, winners)

        # Persist round end events
        :ok = persist_events(events ++ round_events)

        # Then check if game should end
        case apply(state.mode, :check_game_end, [updated_state.mode_state]) do
          {:game_end, game_winners, game_events} ->
            handle_game_end(game_winners, updated_state, game_events)
          :continue ->
            # Start new round if game continues
            {new_state, new_round_events} = start_new_round(updated_state)
            :ok = persist_events(new_round_events)
            {:reply, {:round_end, winners}, new_state}
        end
      :continue ->
        {:reply, :continue, state}
      {:error, reason} ->
        error_event = Events.RoundCheckError.new(state.game_id, reason)
        :ok = persist_events([error_event])
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:check_game_end, _from, state) do
    case apply(state.mode, :check_game_end, [state.mode_state]) do
      {:game_end, winners} ->
        handle_game_end(winners, state)
      :continue ->
        {:reply, :continue, state}
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
      {:reply, {:round_end, _}, _} = result ->
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
      CommandHandler.set_active_game(player_id, game_id)
    end
  end

  defp unregister_players(%{teams: teams}) do
    for {_team_id, %{player_ids: player_ids}} <- teams,
        player_id <- player_ids do
      CommandHandler.clear_active_game(player_id)
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

  defp persist_events(events) when is_list(events) do
    EventStore.append_events(events)
  end

  defp handle_guess_pair(word1, word2, team_id, state, previous_events) do
    # Get result from mode
    case apply(state.mode, :process_guess_pair, [state.mode_state, team_id, %{
      player1_word: word1,
      player2_word: word2
    }]) do
      {:ok, new_mode_state, events} ->
        # Persist all events
        :ok = persist_events(previous_events ++ events)

        # Return result based on match status
        result = if Enum.any?(events, &match?(%Events.GuessMatched{}, &1)), do: :match, else: :no_match
        {:reply, {:ok, result}, %{state | mode_state: new_mode_state}}

      {:error, reason} ->
        error_event = Events.GuessPairError.new(state.game_id, team_id, word1, word2, reason)
        :ok = persist_events([error_event])
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
    :ok = persist_events(events)

    {:reply, {:game_end, winners}, final_state}
  end
end
