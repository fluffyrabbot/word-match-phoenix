defmodule GameBot.Domain.GameModes.KnockoutMode do
  @moduledoc """
  Knockout Mode implementation where teams compete in rounds with eliminations.
  Teams are eliminated through various conditions until one team remains.

  ## Game Rules
  - Teams compete in rounds with a 5-minute time limit per round
  - Maximum of 12 guesses allowed per round
  - Teams are eliminated in three ways:
    1. Immediate elimination upon reaching 12 guesses without matching
    2. End of round elimination for teams that haven't matched within time limit
    3. End of round elimination for 3 teams with highest guess counts (when >8 teams)
  - Round restarts after eliminations with 5-second delay
  - Game continues until one team remains

  ## State Structure
  The mode maintains the following state:
  - Active teams and their current status
  - Round number and timing information
  - Elimination history with reasons
  - Team performance metrics

  ## Usage Example
      # Initialize mode
      {:ok, state} = KnockoutMode.init("game-123", teams, %{
        time_limit: 300,  # 5 minutes
        max_guesses: 12
      })

      # Process a guess pair
      {:ok, state, event} = KnockoutMode.process_guess_pair(state, "team1", guess_pair)

      # Check for eliminations
      {:round_end, winners} = KnockoutMode.check_round_end(state)

  @since "1.0.0"
  """

  @behaviour GameBot.Domain.GameModes.BaseMode

  alias GameBot.Domain.GameState
  alias GameBot.Domain.Events.GameEvents.{
    GameStarted,
    GuessProcessed,
    GuessAbandoned,
    TeamEliminated,
    KnockoutRoundCompleted
  }

  # Configuration
  @round_time_limit 300  # 5 minutes in seconds
  @max_guesses 12       # Maximum guesses before elimination
  @forced_elimination_threshold 8  # Teams above this count trigger forced eliminations
  @teams_to_eliminate 3  # Number of teams to eliminate when above threshold
  @min_teams 2         # Minimum teams to start

  @type elimination_reason ::
    :time_expired |     # Failed to match within time limit
    :guess_limit |      # Exceeded maximum guesses
    :forced_elimination # Eliminated due to high guess count

  @type elimination_data :: %{
    team_id: String.t(),
    round_number: pos_integer(),
    reason: elimination_reason(),
    guess_count: non_neg_integer(),
    eliminated_at: DateTime.t()
  }

  @type state :: %{
    game_id: String.t(),
    teams: %{String.t() => GameState.team_state()},
    round_number: pos_integer(),
    round_start_time: DateTime.t(),
    eliminated_teams: [elimination_data()]
  }

  @doc """
  Initializes a new Knockout mode game state.

  ## Parameters
    * `game_id` - Unique identifier for the game
    * `teams` - Map of team_id to list of player_ids (minimum 2 teams)
    * `config` - Mode configuration (currently unused)

  ## Returns
    * `{:ok, state}` - Successfully initialized state
    * `{:error, reason}` - Failed to initialize state

  ## Examples

      iex> KnockoutMode.init("game-123", %{"team1" => ["p1"], "team2" => ["p2"]}, %{})
      {:ok, %{game_id: "game-123", round_number: 1, ...}}

      iex> KnockoutMode.init("game-123", %{"team1" => ["p1"]}, %{})
      {:error, {:invalid_team_count, "Knockout mode requires at least 2 teams"}}

  @since "1.0.0"
  """
  @impl true
  @spec init(String.t(), %{String.t() => [String.t()]}, map()) :: {:ok, state()} | {:error, term()}
  def init(game_id, teams, config) do
    with :ok <- GameBot.Domain.GameModes.BaseMode.validate_teams(teams, :minimum, @min_teams, "Knockout"),
         {:ok, state, events} <- GameBot.Domain.GameModes.BaseMode.initialize_game(__MODULE__, game_id, teams, config) do

      now = DateTime.utc_now()
      state = %{state |
        round_number: 1,
        round_start_time: now,
        eliminated_teams: []
      }

      {:ok, state, events}
    end
  end

  @doc """
  Processes a guess pair from a team.
  Handles eliminations based on guess limits.

  ## Parameters
    * `state` - Current game state
    * `team_id` - ID of the team making the guess
    * `guess_pair` - Map containing both players' guesses

  ## Returns
    * `{:ok, new_state, events}` - Successfully processed guess pair
    * `{:error, reason}` - Failed to process guess pair

  ## Examples

      iex> KnockoutMode.process_guess_pair(state, "team1", guess_pair)
      {:ok, %{...updated state...}, [%GuessProcessed{}, %TeamEliminated{...}]}

  ## State Updates
  - On successful match:
    * Resets team's guess count
  - On failed match:
    * Increments team's guess count
    * Eliminates team if guess limit reached

  @since "1.0.0"
  """
  @impl true
  @spec process_guess_pair(state(), String.t(), map()) ::
    {:ok, state(), [struct()]} | {:error, term()}
  def process_guess_pair(state, team_id, guess_pair) do
    with :ok <- validate_active_team(state, team_id),
         :ok <- validate_round_time(state),
         {:ok, state, event} <- GameBot.Domain.GameModes.BaseMode.process_guess_pair(state, team_id, guess_pair) do

      cond do
        event.guess_successful ->
          # Reset guess count for next round
          state = update_in(state.teams[team_id], &%{&1 | guess_count: 0})
          {:ok, state, event}

        event.guess_count >= @max_guesses ->
          # Eliminate team for exceeding guess limit
          {state, elimination_event} = eliminate_team(state, team_id, :guess_limit)
          {:ok, state, [event, elimination_event]}

        true ->
          {:ok, state, event}
      end
    end
  end

  @doc """
  Handles abandoned guesses in the game.
  Delegates to base mode implementation after validation.

  ## Parameters
    * `state` - Current game state
    * `team_id` - ID of the team with abandoned guess
    * `reason` - Reason for abandonment
    * `last_guess` - Last recorded guess before abandonment

  ## Returns
    * `{:ok, new_state, event}` - Successfully handled abandonment
    * `{:error, reason}` - Failed to handle abandonment

  @since "1.0.0"
  """
  @impl true
  @spec handle_guess_abandoned(state(), String.t(), atom(), map() | nil) ::
    {:ok, state(), GuessAbandoned.t()} | {:error, term()}
  def handle_guess_abandoned(state, team_id, reason, last_guess) do
    with :ok <- validate_active_team(state, team_id) do
      GameBot.Domain.GameModes.BaseMode.handle_guess_abandoned(state, team_id, reason, last_guess)
    end
  end

  @doc """
  Checks if the current round should end.
  Handles time-based eliminations and forced eliminations.

  ## Parameters
    * `state` - Current game state

  ## Returns
    * `{:round_end, state}` - Round has ended with updated state
    * `:continue` - Round should continue
    * `{:error, reason}` - Error checking round end

  ## Examples

      iex> KnockoutMode.check_round_end(state_with_expired_time)
      {:round_end, updated_state}

      iex> KnockoutMode.check_round_end(state_with_active_time)
      :continue

  @since "1.0.0"
  """
  @impl true
  @spec check_round_end(state()) :: {:round_end, state()} | :continue | {:error, term()}
  def check_round_end(state) do
    now = DateTime.utc_now()
    elapsed_seconds = DateTime.diff(now, state.round_start_time)

    if elapsed_seconds >= @round_time_limit do
      # Handle round time expiry
      state = handle_round_time_expired(state)

      # Start new round if game continues
      case check_game_end(state) do
        {:game_end, winners} ->
          {:game_end, winners}
        :continue ->
          state = %{state |
            round_number: state.round_number + 1,
            round_start_time: now
          }
          {:round_end, state}
      end
    else
      :continue
    end
  end

  @doc """
  Checks if the game should end.
  Game ends when only one team remains.

  ## Parameters
    * `state` - Current game state

  ## Returns
    * `{:game_end, winners}` - Game is complete with list of winning teams
    * `:continue` - Game should continue

  ## Examples

      iex> KnockoutMode.check_game_end(state_with_one_team)
      {:game_end, ["team1"]}

      iex> KnockoutMode.check_game_end(state_with_multiple_teams)
      :continue

  @since "1.0.0"
  """
  @impl true
  @spec check_game_end(state()) :: {:game_end, [String.t()]} | :continue
  def check_game_end(state) do
    active_teams = get_active_teams(state)
    cond do
      length(active_teams) == 1 -> {:game_end, active_teams}
      length(active_teams) == 0 -> {:game_end, []}
      true -> :continue
    end
  end

  # Private Functions

  @doc false
  # Validates that a team is still active
  defp validate_active_team(state, team_id) do
    if Map.has_key?(state.teams, team_id) do
      :ok
    else
      {:error, {:team_eliminated, "Team #{team_id} has been eliminated from the game"}}
    end
  end

  @doc false
  # Validates that the round time hasn't expired
  defp validate_round_time(state) do
    elapsed = DateTime.diff(DateTime.utc_now(), state.round_start_time)
    if elapsed < @round_time_limit do
      :ok
    else
      {:error, {:round_time_expired, "Round time has expired"}}
    end
  end

  @doc false
  # Handles round time expiry eliminations
  defp handle_round_time_expired(state) do
    # First eliminate teams that haven't matched
    state = eliminate_unmatched_teams(state)

    # Then eliminate worst performing teams if above threshold
    active_team_count = count_active_teams(state)
    if active_team_count > @forced_elimination_threshold do
      eliminate_worst_teams(state, @teams_to_eliminate)
    else
      state
    end
  end

  @doc false
  # Eliminates teams that haven't matched within time limit
  defp eliminate_unmatched_teams(state) do
    now = DateTime.utc_now()

    {eliminated, remaining} = Enum.split_with(state.teams, fn {_id, team} ->
      !team.current_match_complete
    end)

    eliminated_data = Enum.map(eliminated, fn {team_id, team} ->
      %{
        team_id: team_id,
        round_number: state.round_number,
        reason: :time_expired,
        guess_count: team.guess_count,
        eliminated_at: now
      }
    end)

    %{state |
      teams: Map.new(remaining),
      eliminated_teams: state.eliminated_teams ++ eliminated_data
    }
  end

  @doc false
  # Eliminates worst performing teams based on guess count
  defp eliminate_worst_teams(state, count) do
    now = DateTime.utc_now()

    # Sort teams by guess count (highest first)
    sorted_teams = Enum.sort_by(state.teams, fn {_id, team} ->
      team.guess_count
    end, :desc)

    # Take the specified number of teams to eliminate
    {to_eliminate, to_keep} = Enum.split(sorted_teams, count)

    eliminated_data = Enum.map(to_eliminate, fn {team_id, team} ->
      %{
        team_id: team_id,
        round_number: state.round_number,
        reason: :forced_elimination,
        guess_count: team.guess_count,
        eliminated_at: now
      }
    end)

    %{state |
      teams: Map.new(to_keep),
      eliminated_teams: state.eliminated_teams ++ eliminated_data
    }
  end

  @doc false
  # Eliminates a single team and generates elimination event
  defp eliminate_team(state, team_id, reason) do
    team = state.teams[team_id]
    now = DateTime.utc_now()

    elimination_data = %{
      team_id: team_id,
      round_number: state.round_number,
      reason: reason,
      guess_count: team.guess_count,
      eliminated_at: now
    }

    event = %TeamEliminated{
      game_id: state.game_id,
      team_id: team_id,
      round_number: state.round_number,
      reason: reason,
      timestamp: now,
      metadata: %{}
    }

    state = %{state |
      teams: Map.delete(state.teams, team_id),
      eliminated_teams: [elimination_data | state.eliminated_teams]
    }

    {state, event}
  end

  @doc false
  # Gets list of active team IDs
  defp get_active_teams(state) do
    Map.keys(state.teams)
  end

  @doc false
  # Gets count of active teams
  defp count_active_teams(state) do
    map_size(state.teams)
  end

  @doc """
  Validates an event for the Knockout mode.
  Ensures that events contain the required fields and values for this mode.

  ## Parameters
    * `event` - The event to validate

  ## Returns
    * `:ok` - Event is valid for this mode
    * `{:error, reason}` - Event is invalid with reason

  ## Examples

      iex> KnockoutMode.validate_event(%GameEvents.GameStarted{mode: :knockout})
      :ok

      iex> KnockoutMode.validate_event(%GameEvents.GameStarted{mode: :two_player})
      {:error, "Invalid mode for KnockoutMode: expected :knockout, got :two_player"}
  """
  @spec validate_event(struct()) :: :ok | {:error, String.t()}
  def validate_event(event) do
    GameBot.Domain.GameModes.BaseMode.validate_event(event, :knockout, :minimum, 2)
  end
end
