defmodule GameBot.Domain.GameModes.RaceMode do
  @moduledoc """
  Race Mode implementation where teams compete to complete the most matches
  within a time limit. Teams play asynchronously, with each match immediately
  starting a new round for that team.

  ## Game Rules
  - Fixed time limit (default: 3 minutes)
  - Teams play asynchronously (no waiting for other teams)
  - Each match immediately starts a new round for that team
  - No elimination - all teams play until time expires
  - Teams can give up on difficult word pairs
  - One point per successful match
  - Tiebreaker based on average guesses per match

  ## State Structure
  The mode maintains the following state:
  - Time limit and start time
  - Matches completed by each team
  - Total guesses by each team
  - Team-specific round states
  - Give up command handling

  ## Usage Example
      # Initialize mode
      {:ok, state} = RaceMode.init("game-123", teams, %{
        time_limit: 180  # 3 minutes
      })

      # Process a guess pair
      {:ok, state, event} = RaceMode.process_guess_pair(state, "team1", guess_pair)

      # Handle give up command
      {:ok, state, event} = RaceMode.process_guess_pair(state, "team1", %{
        player1_word: "give up",
        player2_word: "word"
      })

  @since "1.0.0"
  """

  @behaviour GameBot.Domain.GameModes.BaseMode

  alias GameBot.Domain.Events.GameEvents.{
    GuessAbandoned,
    RaceModeTimeExpired,
    RoundRestarted
  }

  # Configuration
  @default_time_limit 180  # 3 minutes in seconds
  @give_up_command "give up"

  @type config :: %{
    time_limit: pos_integer()  # Time limit in seconds
  }

  @type team_stats :: %{
    matches: non_neg_integer(),
    total_guesses: non_neg_integer(),
    average_guesses: float()
  }

  @type state :: %{
    game_id: String.t(),
    guild_id: String.t(),
    time_limit: pos_integer(),
    start_time: DateTime.t(),
    matches_by_team: %{String.t() => non_neg_integer()},
    total_guesses_by_team: %{String.t() => non_neg_integer()}
  }

  @doc """
  Initializes a new Race mode game state.

  ## Parameters
    * `game_id` - Unique identifier for the game
    * `teams` - Map of team_id to list of player_ids
    * `config` - Mode configuration:
      * `:time_limit` - Game duration in seconds (default: 180)

  ## Returns
    * `{:ok, state, events}` - Successfully initialized state with events
    * `{:error, reason}` - Failed to initialize state

  ## Examples

      iex> RaceMode.init("game-123", teams, %{time_limit: 180})
      {:ok, %{game_id: "game-123", time_limit: 180, ...}, []}

      iex> RaceMode.init("game-123", teams, %{time_limit: 0})
      {:error, :invalid_time_limit}

  @since "1.0.0"
  """
  @impl true
  @spec init(String.t(), %{String.t() => [String.t()]}, map()) :: {:ok, state()} | {:error, term()}
  def init(game_id, teams, config) do
    with :ok <- GameBot.Domain.GameModes.BaseMode.validate_teams(teams, :minimum, 2, "Race"),
         :ok <- validate_config(config) do
      config = Map.merge(default_config(), config)
      guild_id = Map.get(config, :guild_id)

      if is_nil(guild_id) do
        {:error, :missing_guild_id}
      else
        {:ok, state, events} = GameBot.Domain.GameModes.BaseMode.initialize_game(__MODULE__, game_id, teams, config)

        # Initialize all required fields to prevent KeyError
        state = Map.merge(state, %{
          guild_id: guild_id,
          time_limit: config.time_limit,
          start_time: DateTime.utc_now(),
          matches_by_team: %{},
          total_guesses_by_team: %{}
        })

        {:ok, state, events}
      end
    end
  end

  @doc """
  Processes a guess pair from a team.
  Handles both normal guesses and give up commands.

  ## Parameters
    * `state` - Current game state
    * `team_id` - ID of the team making the guess
    * `guess_pair` - Map containing both players' guesses

  ## Returns
    * `{:ok, new_state, events}` - Successfully processed guess pair
    * `{:error, reason}` - Failed to process guess pair

  ## Examples

      iex> RaceMode.process_guess_pair(state, "team1", %{
      ...>   player1_word: "hello",
      ...>   player2_word: "hello"
      ...> })
      {:ok, %{...updated state...}, %GuessProcessed{...}}

      iex> RaceMode.process_guess_pair(state, "team1", %{
      ...>   player1_word: "give up",
      ...>   player2_word: "word"
      ...> })
      {:ok, %{...updated state...}, %RoundRestarted{...}}

  ## State Updates
  - On successful match:
    * Increments team's match count
    * Updates total guesses
    * Resets team's guess count
  - On give up:
    * Counts as a failed attempt
    * Resets team's words and guess count
  - On failed match:
    * Updates team's guess count

  @since "1.0.0"
  """
  @impl true
  @spec process_guess_pair(state(), String.t(), map()) ::
    {:ok, state(), struct()} | {:error, term()}
  def process_guess_pair(state, team_id, guess_pair) do
    with :ok <- validate_guess_pair(state, team_id, guess_pair) do
      case {guess_pair.player1_word, guess_pair.player2_word} do
        # Handle cases where either player gives up
        {@give_up_command, _} ->
          handle_give_up(state, team_id, guess_pair)
        {_, @give_up_command} ->
          handle_give_up(state, team_id, guess_pair)
        # Normal guess processing
        _ ->
          with {:ok, state, event} <- GameBot.Domain.GameModes.BaseMode.process_guess_pair(state, team_id, guess_pair) do
            # Make sure the event is accessible regardless of how it's retrieved
            guess_successful = Map.get(event, :guess_successful)
            guess_count = Map.get(event, :guess_count)

            state = if guess_successful do
              # Update match count and total guesses for the team - don't use update_in on struct fields
              state = Map.update(state, :matches_by_team, %{team_id => 1}, fn matches ->
                Map.update(matches, team_id, 1, &(&1 + 1))
              end)

              # Update total guesses in a similar way
              Map.update(state, :total_guesses_by_team, %{team_id => guess_count}, fn total_guesses ->
                Map.update(total_guesses, team_id, guess_count, &(&1 + guess_count))
              end)
            else
              state
            end

            {:ok, state, event}
          end
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
    GameBot.Domain.GameModes.BaseMode.handle_guess_abandoned(state, team_id, reason, last_guess)
  end

  @doc """
  Checks if the current round should end.
  In Race mode, rounds are team-specific and end on matches.

  ## Parameters
    * `state` - Current game state

  ## Returns
    * `:continue` - Round should continue

  @since "1.0.0"
  """
  @impl true
  @spec check_round_end(state()) :: :continue
  def check_round_end(_state) do
    :continue
  end

  @doc """
  Checks if the game should end.
  Game ends when time limit is reached.

  ## Parameters
    * `state` - Current game state

  ## Returns
    * `{:game_end, winners, events}` - Game is complete with winners and final events
    * `:continue` - Game should continue

  ## Examples

      iex> RaceMode.check_game_end(state_with_expired_time)
      {:game_end, ["team1"], [%RaceModeTimeExpired{...}]}

      iex> RaceMode.check_game_end(state_with_active_time)
      :continue

  @since "1.0.0"
  """
  @impl true
  @spec check_game_end(state()) :: {:game_end, [String.t()], [struct()]} | :continue
  def check_game_end(state) do
    now = DateTime.utc_now()
    elapsed_seconds = DateTime.diff(now, state.start_time)

    if elapsed_seconds >= state.time_limit do
      # Find team(s) with most matches
      {winners, _max_matches} = find_winners(state)

      # Generate time expired event
      time_expired_event = %RaceModeTimeExpired{
        game_id: state.game_id,
        final_matches: state.matches_by_team,
        timestamp: now
      }

      # Return winners based on most matches, with average guesses as tiebreaker
      {:game_end, winners, [time_expired_event]}
    else
      :continue
    end
  end

  # Private Functions

  @doc false
  # Returns default configuration for the game mode
  defp default_config do
    %{
      time_limit: @default_time_limit
    }
  end

  @doc false
  # Validates configuration parameters
  defp validate_config(config) do
    cond do
      is_nil(config) ->
        {:error, :missing_config}
      Map.get(config, :time_limit, @default_time_limit) <= 0 ->
        {:error, :invalid_time_limit}
      true ->
        :ok
    end
  end

  @doc false
  # Validates the guess pair for race mode-specific rules
  defp validate_guess_pair(state, team_id, %{
    player1_id: player1_id,
    player2_id: player2_id,
    player1_word: player1_word,
    player2_word: player2_word
  }) do
    # Get team players first so we can reference it in the cond
    team_players = get_in(state.teams, [team_id, :player_ids]) || []

    cond do
      !Map.has_key?(state.teams, team_id) ->
        {:error, :invalid_team}

      player1_id not in team_players or player2_id not in team_players ->
        {:error, :invalid_player}

      player1_id == player2_id ->
        {:error, :same_player}

      player1_word == @give_up_command or player2_word == @give_up_command ->
        :ok

      # Skip word_forbidden checks in test environment
      System.get_env("GAMEBOT_DISABLE_WORD_VALIDATION") == "true" ->
        :ok

      GameBot.Domain.GameState.word_forbidden?(state, state.guild_id, player1_id, player1_word) ->
        {:error, :word_forbidden}

      GameBot.Domain.GameState.word_forbidden?(state, state.guild_id, player2_id, player2_word) ->
        {:error, :word_forbidden}

      true ->
        :ok
    end
  end

  @doc false
  # Handles give up command from a player
  defp handle_give_up(state, team_id, guess_pair) do
    # Create a guess processed event first to record the give-up in the standard guess flow
    # This will ensure the give-up appears in replays alongside normal guesses
    guess_count = get_in(state.teams, [team_id, :guess_count]) + 1

    # Get player info from state
    player1_id = guess_pair.player1_id
    player2_id = guess_pair.player2_id
    player1_info = %{id: player1_id, name: get_in(state, [:players, player1_id, :name])}
    player2_info = %{id: player2_id, name: get_in(state, [:players, player2_id, :name])}

    # Calculate durations based on actual submission times
    # When a player gives up, we record their actual submission time
    # For the example, we'll use a placeholder calculation based on round start time
    now = DateTime.utc_now()
    round_start_time = Map.get(state, :round_start_time, DateTime.add(now, -60, :second))
    elapsed_ms = DateTime.diff(now, round_start_time, :millisecond)

    {player1_duration, player2_duration} =
      cond do
        guess_pair.player1_word == @give_up_command ->
          # Player 1 gave up, so their duration is the current elapsed time
          # Player 2's submission is unknown, so we use nil
          {elapsed_ms, nil}
        guess_pair.player2_word == @give_up_command ->
          # Player 2 gave up, so their duration is the current elapsed time
          # Player 1's submission is unknown, so we use nil
          {nil, elapsed_ms}
        true ->
          # Both gave up (unlikely) or some other edge case
          {nil, nil}
      end

    guess_processed_event = %GameBot.Domain.Events.GuessEvents.GuessProcessed{
      game_id: state.game_id,
      guild_id: state.guild_id,
      team_id: team_id,
      player1_info: player1_info,
      player2_info: player2_info,
      player1_word: guess_pair.player1_word,
      player2_word: guess_pair.player2_word,
      guess_successful: false, # Give up is always unsuccessful
      match_score: nil, # No match score for unsuccessful guesses
      guess_count: guess_count,
      round_guess_count: guess_count,
      total_guesses: Map.get(state.total_guesses_by_team, team_id, 0) + 1,
      guess_duration: elapsed_ms, # Use actual time from round start
      player1_duration: player1_duration,
      player2_duration: player2_duration,
      timestamp: now
    }

    # Create a round restart event with both players' information
    round_restart_event = %RoundRestarted{
      game_id: state.game_id,
      guild_id: state.guild_id,
      team_id: team_id,
      giving_up_player: if(guess_pair.player1_word == @give_up_command, do: guess_pair.player1_id, else: guess_pair.player2_id),
      teammate_word: if(guess_pair.player1_word == @give_up_command, do: guess_pair.player2_word, else: guess_pair.player1_word),
      guess_count: guess_count,
      timestamp: DateTime.utc_now()
    }

    # Update total guesses to count this as a failed attempt
    state = update_in(state.total_guesses_by_team[team_id], &(&1 + 1))

    # Clear the current words for the team and reset their guess count
    # Note: The session manager will handle getting new words
    state = update_in(state.teams[team_id], fn team_state ->
      %{team_state |
        current_words: [],
        guess_count: 0,
        pending_guess: nil
      }
    end)

    # Return both events in a list, with GuessProcessed coming first
    {:ok, state, [guess_processed_event, round_restart_event]}
  end

  @doc false
  # Finds winners based on matches and average guesses
  defp find_winners(state) do
    # Get highest match count
    max_matches = Enum.max(Map.values(state.matches_by_team))

    # Find all teams with max matches
    teams_with_max = Enum.filter(state.matches_by_team, fn {_team, matches} ->
      matches == max_matches
    end)
    |> Enum.map(&elem(&1, 0))

    if length(teams_with_max) == 1 do
      # Single winner
      {teams_with_max, max_matches}
    else
      # Tiebreaker based on average guesses per match
      winner = Enum.min_by(teams_with_max, fn team_id ->
        total_guesses = state.total_guesses_by_team[team_id]
        matches = state.matches_by_team[team_id]
        total_guesses / matches
      end)

      {[winner], max_matches}
    end
  end

  @doc """
  Validates an event for the Race mode.
  Ensures that events contain the required fields and values for this mode.

  ## Parameters
    * `event` - The event to validate

  ## Returns
    * `:ok` - Event is valid for this mode
    * `{:error, reason}` - Event is invalid with reason

  ## Examples

      iex> RaceMode.validate_event(%GameEvents.GameStarted{mode: :race})
      :ok

      iex> RaceMode.validate_event(%GameEvents.GameStarted{mode: :two_player})
      {:error, "Invalid mode for RaceMode: expected :race, got :two_player"}
  """
  @spec validate_event(struct()) :: :ok | {:error, String.t()}
  def validate_event(event) do
    GameBot.Domain.GameModes.BaseMode.validate_event(event, :race, :minimum, 2)
  end
end
