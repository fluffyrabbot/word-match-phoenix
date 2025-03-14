defmodule GameBot.Domain.GameModes.BaseMode do
  @moduledoc """
  Defines the base behaviour and common functionality for all game modes.
  This module provides the contract that all game modes must implement,
  along with shared utility functions for state management.

  ## Behaviour Contract
  Game modes must implement the following callbacks:
  - `init/3` - Initialize game state with configuration
  - `process_guess_pair/3` - Handle guess pairs from teams
  - `handle_guess_abandoned/4` - Handle abandoned guesses
  - `check_round_end/1` - Check if current round should end
  - `check_game_end/1` - Check if game should end

  ## Common State Structure
  All game modes share these base state fields:
  - `game_id` - Unique identifier for the game
  - `teams` - Map of team states
  - `round_number` - Current round number
  - `start_time` - Game start timestamp
  - `status` - Current game status

  ## Usage Example
      defmodule MyGameMode do
        @behaviour GameBot.Domain.GameModes.BaseMode

        @impl true
        def init(game_id, teams, config) do
          {:ok, state} = BaseMode.initialize_game(__MODULE__, game_id, teams, config)
          {:ok, state}
        end

        # ... implement other callbacks ...
      end

  @since "1.0.0"
  """

  alias GameBot.Domain.GameState
  alias GameBot.Domain.Events.GameEvents.{
    GameStarted,
    GuessProcessed,
    GuessAbandoned,
    TeamEliminated,
    GameCompleted
  }

  @type config :: term()
  @type game_id :: String.t()
  @type team_id :: String.t()
  @type player_id :: String.t()
  @type word :: String.t()
  @type error :: {:error, term()}
  @type guess_pair :: %{
    player1_id: player_id(),
    player2_id: player_id(),
    player1_word: word(),
    player2_word: word()
  }

  @doc """
  Callback to initialize a new game state.

  ## Parameters
    * `game_id` - Unique identifier for the game
    * `teams` - Map of team_id to list of player_ids
    * `config` - Mode-specific configuration

  ## Returns
    * `{:ok, state}` - Successfully initialized state
    * `{:error, reason}` - Failed to initialize state

  ## Example Implementation
      @impl true
      def init(game_id, teams, config) do
        {:ok, state} = BaseMode.initialize_game(__MODULE__, game_id, teams, config)
        {:ok, state}
      end
  """
  @callback init(game_id(), %{team_id() => [player_id()]}, config()) ::
    {:ok, GameState.t()} | error()

  @doc """
  Callback to process a guess pair from a team.

  ## Parameters
    * `state` - Current game state
    * `team_id` - ID of the team making the guess
    * `guess_pair` - Map containing both players' guesses

  ## Returns
    * `{:ok, new_state, event}` - Successfully processed guess pair
    * `{:error, reason}` - Failed to process guess pair

  ## Example Implementation
      @impl true
      def process_guess_pair(state, team_id, guess_pair) do
        with {:ok, state, event} <- BaseMode.process_guess_pair(state, team_id, guess_pair) do
          {:ok, state, event}
        end
      end
  """
  @callback process_guess_pair(GameState.t(), team_id(), guess_pair()) ::
    {:ok, GameState.t(), GuessProcessed.t()} | error()

  @doc """
  Callback to handle abandoned guesses.

  ## Parameters
    * `state` - Current game state
    * `team_id` - ID of the team with abandoned guess
    * `reason` - Reason for abandonment (:timeout | :player_quit)
    * `last_guess` - Last recorded guess before abandonment

  ## Returns
    * `{:ok, new_state, event}` - Successfully handled abandonment
    * `{:error, reason}` - Failed to handle abandonment

  ## Example Implementation
      @impl true
      def handle_guess_abandoned(state, team_id, reason, last_guess) do
        BaseMode.handle_guess_abandoned(state, team_id, reason, last_guess)
      end
  """
  @callback handle_guess_abandoned(GameState.t(), team_id(), :timeout | :player_quit, map() | nil) ::
    {:ok, GameState.t(), GuessAbandoned.t()} | error()

  @doc """
  Callback to check if the current round should end.

  ## Parameters
    * `state` - Current game state

  ## Returns
    * `{:round_end, winners}` - Round has ended with list of winning teams
    * `:continue` - Round should continue
    * `{:error, reason}` - Error checking round end

  ## Example Implementation
      @impl true
      def check_round_end(state) do
        :continue
      end
  """
  @callback check_round_end(GameState.t()) ::
    {:round_end, [team_id()]} | :continue | error()

  @doc """
  Callback to check if the game should end.

  ## Parameters
    * `state` - Current game state

  ## Returns
    * `{:game_end, winners}` - Game is complete with list of winning teams
    * `:continue` - Game should continue
    * `{:error, reason}` - Error checking game end

  ## Example Implementation
      @impl true
      def check_game_end(state) do
        :continue
      end
  """
  @callback check_game_end(GameState.t()) ::
    {:game_end, [team_id()]} | :continue | error()

  @doc """
  Initializes a base game state with common fields.
  Used by game modes to set up their initial state.

  ## Parameters
    * `mode` - Module implementing the game mode
    * `game_id` - Unique identifier for the game
    * `teams` - Map of team_id to list of player_ids
    * `config` - Mode-specific configuration

  ## Returns
    * `{:ok, state}` - Successfully initialized base state
    * `{:error, reason}` - Failed to initialize state

  ## Examples

      iex> BaseMode.initialize_game(MyMode, "game-123", %{"team1" => ["p1", "p2"]}, %{})
      {:ok, %{game_id: "game-123", mode: MyMode, teams: %{...}, ...}}

  @since "1.0.0"
  """
  @spec initialize_game(module(), game_id(), %{team_id() => [player_id()]}, config()) ::
    {:ok, GameState.t()} | error()
  def initialize_game(mode, game_id, teams, config) do
    # Extract guild_id from config or use default
    guild_id = get_in(config, [:metadata, :guild_id]) || "default_guild"

    # Initialize state with guild_id
    {:ok, state} = GameState.new(guild_id, mode, teams)

    event = %GameStarted{
      game_id: game_id,
      guild_id: guild_id,
      mode: mode,
      round_number: 1,
      teams: teams,
      team_ids: Map.keys(teams),
      player_ids: List.flatten(Map.values(teams)),
      config: config,
      timestamp: DateTime.utc_now(),
      metadata: %{guild_id: guild_id}
    }

    {:ok, state, [event]}
  end

  @doc """
  Process a guess pair from a team.
  Validates the guess, processes it, and emits appropriate events.

  ## Parameters
    * `state` - Current game state
    * `team_id` - Team making the guess
    * `guess_pair` - Map containing guess details:
      * `:player1_id` - ID of first player
      * `:player2_id` - ID of second player
      * `:player1_word` - Word from first player
      * `:player2_word` - Word from second player

  ## Returns
    * `{:ok, state, events}` - Successfully processed the guess
    * `{:error, reason}` - Failed to process the guess

  ## Examples

      iex> BaseMod.process_guess_pair(state, "team1", %{player1_id: "p1", ...})
      {:ok, updated_state, [%GuessProcessed{}]}

      iex> BaseMod.process_guess_pair(state, "invalid", guess_pair)
      {:error, :invalid_team}
  """
  @spec process_guess_pair(GameState.t(), String.t(), guess_pair()) ::
    {:ok, GameState.t(), GuessProcessed.t()} | {:error, term()}
  def process_guess_pair(state, team_id, guess_pair) when is_map(guess_pair) do
    # Extract fields from guess_pair
    player1_id = Map.get(guess_pair, :player1_id)
    player2_id = Map.get(guess_pair, :player2_id)
    player1_word = Map.get(guess_pair, :player1_word)
    player2_word = Map.get(guess_pair, :player2_word)
    player1_duration = Map.get(guess_pair, :player1_duration, 0)
    player2_duration = Map.get(guess_pair, :player2_duration, 0)

    # Validate inputs
    with {:ok, team} <- get_team(state, team_id),
         :ok <- validate_guess_pair(state, team_id, guess_pair) do
      # Get current round guess count
      round_guess_count = team.guess_count + 1

      # Calculate total guesses across all teams
      total_guesses = get_total_guesses(state) + 1

      # Validate match
      guess_successful = player1_word == player2_word and player1_word != "" and player2_word != ""

      # Calculate the guess duration (use max time as the total duration)
      guess_duration = max(player1_duration, player2_duration)

      # Record times
      end_time = DateTime.utc_now()

      # Create the event
      event = %GuessProcessed{
        game_id: game_id(state),
        guild_id: state.guild_id,
        mode: state.mode,
        team_id: team_id,
        player1_id: player1_id,
        player2_id: player2_id,
        player1_word: player1_word,
        player2_word: player2_word,
        guess_successful: guess_successful,
        guess_count: round_guess_count,
        round_number: state.current_round,
        round_guess_count: round_guess_count,
        total_guesses: total_guesses,
        guess_duration: guess_duration,
        player1_duration: player1_duration,
        player2_duration: player2_duration,
        match_score: if(guess_successful, do: 1, else: 0),
        timestamp: end_time,
        metadata: %{}
      }

      # Update state based on result
      state = if guess_successful do
        record_match(state, team_id, player1_word)
      else
        state
      end

      # Update state
      state = record_guess_pair(state, team_id, guess_pair)

      # Return updated state and events - return the single event, not a list
      {:ok, state, event}
    end
  end

  @doc """
  Common implementation for handling abandoned guesses.
  Updates team state and generates appropriate event.

  ## Parameters
    * `state` - Current game state
    * `team_id` - ID of the team with abandoned guess
    * `reason` - Reason for abandonment
    * `last_guess` - Last recorded guess before abandonment

  ## Returns
    * `{:ok, new_state, event}` - Successfully handled abandonment
    * `{:error, reason}` - Failed to handle abandonment

  ## Examples

      iex> BaseMode.handle_guess_abandoned(state, "team1", :timeout, last_guess)
      {:ok, %{...updated state...}, %GuessAbandoned{...}}

  @since "1.0.0"
  """
  @spec handle_guess_abandoned(GameState.t(), team_id(), atom(), map() | nil) ::
    {:ok, GameState.t(), GuessAbandoned.t()} | error()
  def handle_guess_abandoned(state, team_id, reason, last_guess) do
    team_state = get_in(state.teams, [team_id])
    now = DateTime.utc_now()

    event = %GuessAbandoned{
      game_id: game_id(state),
      guild_id: state.guild_id,
      mode: state.mode,
      round_number: state.round_number,
      team_id: team_id,
      player1_id: last_guess["player1_id"],
      player2_id: last_guess["player2_id"],
      reason: reason,
      abandoning_player_id: last_guess["abandoning_player_id"],
      last_guess: last_guess,
      guess_count: team_state.guess_count,
      round_guess_count: team_state.guess_count,
      total_guesses: Map.get(team_state, :total_guesses, team_state.guess_count),
      guess_duration: nil,  # No duration for abandoned guesses
      timestamp: now,
      metadata: %{}
    }

    {:ok, updated_state} = GameState.increment_guess_count(state, state.guild_id, team_id)
    {:ok, updated_state, event}
  end

  @doc """
  Validates the given guess pair against the current game state.

  ## Parameters
    * `state` - Current game state
    * `team_id` - Team making the guess
    * `guess_pair` - Map containing guess details

  ## Returns
    * `:ok` - Guess pair is valid
    * `{:error, reason}` - Validation error
  """
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

      # Skip word_forbidden checks in test environment
      System.get_env("GAMEBOT_DISABLE_WORD_VALIDATION") == "true" ->
        :ok

      word_forbidden?(state, player1_id, player1_word) == {:ok, true} ->
        {:error, :word_forbidden}

      word_forbidden?(state, player2_id, player2_word) == {:ok, true} ->
        {:error, :word_forbidden}

      true ->
        :ok
    end
  end

  @doc """
  Checks if a word is on a player's forbidden word list.

  ## Parameters
    * `state` - Current game state
    * `player_id` - Player ID to check for
    * `word` - Word to check if forbidden

  ## Returns
    * `{:ok, true}` - Word is forbidden
    * `{:ok, false}` - Word is allowed
    * `{:error, reason}` - Error checking word

  @since "1.0.0"
  """
  @spec word_forbidden?(GameState.t(), player_id(), String.t()) ::
          {:ok, boolean()} | {:error, term()}
  def word_forbidden?(state, player_id, word) do
    # Bypass word validation in test environment
    disable_word_validation = System.get_env("GAMEBOT_DISABLE_WORD_VALIDATION") == "true"

    if disable_word_validation do
      {:ok, false}
    else
      normalized_word = String.downcase(word)
      player_forbidden_words = get_in(state.forbidden_words, [player_id]) || []

      # Check if word is in the player's forbidden word list
      is_forbidden = Enum.any?(player_forbidden_words, fn forbidden ->
        String.downcase(forbidden) == normalized_word
      end)

      {:ok, is_forbidden}
    end
  end

  @doc """
  Records a guess pair in the game state.
  """
  def record_guess_pair(state, _team_id, %{
    player1_id: player1_id,
    player2_id: player2_id,
    player1_word: player1_word,
    player2_word: player2_word
  }) do
    now = DateTime.utc_now()

    state
    |> add_forbidden_words(player1_id, player1_word, player2_id, player2_word)
    |> Map.put(:last_activity, now)
  end

  @doc """
  Records a successful match in the game state.
  """
  def record_match(state, team_id, matched_word) do
    match = %{
      team_id: team_id,
      word: matched_word,
      guess_count: get_in(state.teams, [team_id, :guess_count]),
      timestamp: DateTime.utc_now()
    }

    %{state | matches: [match | state.matches]}
  end

  @doc """
  Handles team elimination.
  """
  def handle_elimination(state, team_id, reason) do
    event = %TeamEliminated{
      game_id: game_id(state),
      team_id: team_id,
      reason: reason,
      final_state: Map.get(state.teams, team_id),
      timestamp: DateTime.utc_now()
    }

    {:ok, state, event}
  end

  @doc """
  Handles game completion.
  """
  def handle_completion(state, winners) do
    event = %GameCompleted{
      game_id: game_id(state),
      winners: winners,
      final_scores: state.scores,
      timestamp: DateTime.utc_now()
    }

    state = %{state | status: :completed}
    {:ok, state, event}
  end

  # Private helpers

  defp game_id(%GameState{mode: mode, start_time: start_time}) do
    "#{mode}-#{DateTime.to_unix(start_time)}"
  end

  defp add_forbidden_words(state, player1_id, word1, player2_id, word2) do
    {:ok, state_with_word1} = GameState.add_forbidden_word(state, state.guild_id, player1_id, word1)
    {:ok, state_with_both} = GameState.add_forbidden_word(state_with_word1, state.guild_id, player2_id, word2)
    state_with_both
  end

  @doc """
  Gets count of active teams.

  ## Parameters
    * `state` - Game state to check

  ## Returns
    * Integer count of active teams
  """
  @spec count_active_teams(GameState.t()) :: non_neg_integer()
  def count_active_teams(state) do
    map_size(state.teams)
  end

  @doc """
  Common implementation for validating events across all game modes.

  This function provides a centralized validation mechanism that all game modes can use,
  reducing code duplication while allowing mode-specific validation rules.

  ## Parameters
    * `event` - The event to validate
    * `expected_mode` - The expected mode for this event (e.g., :two_player, :knockout)
    * `team_requirements` - Requirements for team count validation:
      * `:exact` - Requires exactly the specified count
      * `:minimum` - Requires at least the specified count
    * `team_count` - The required number of teams (used with team_requirements)

  ## Returns
    * `:ok` - Event is valid for this mode
    * `{:error, reason}` - Event is invalid with reason

  ## Examples

      iex> BaseMode.validate_event(event, :two_player, :exact, 1)
      :ok

      iex> BaseMode.validate_event(event, :knockout, :minimum, 2)
      :ok
  """
  @spec validate_event(struct(), atom(), :exact | :minimum, non_neg_integer()) :: :ok | {:error, String.t()}
  def validate_event(event, expected_mode, team_requirements \\ :minimum, team_count \\ 1)

  def validate_event(%{mode: mode} = _event, expected_mode, _team_requirements, _team_count)
      when mode != expected_mode do
    {:error, "Invalid mode for #{inspect(expected_mode)} mode: expected #{inspect(expected_mode)}, got #{inspect(mode)}"}
  end

  def validate_event(%{__struct__: struct_type} = event, expected_mode, team_requirements, team_count) do
    case struct_type do
      GameBot.Domain.Events.GameEvents.GameStarted ->
        validate_game_started(event, expected_mode, team_requirements, team_count)
      GameBot.Domain.Events.GameEvents.GuessProcessed ->
        :ok
      GameBot.Domain.Events.GameEvents.RoundStarted ->
        :ok
      GameBot.Domain.Events.GameEvents.RoundFinished ->
        :ok
      GameBot.Domain.Events.GameEvents.GameCompleted ->
        :ok
      _ ->
        :ok  # Other event types don't need mode-specific validation
    end
  end

  def validate_event(_event, _expected_mode, _team_requirements, _team_count), do: :ok

  @doc false
  # Validates game started event based on team requirements
  defp validate_game_started(%{teams: teams}, expected_mode, :exact, team_count) do
    if map_size(teams) != team_count do
      {:error, "#{inspect(expected_mode)} mode requires exactly #{team_count} team(s), got #{map_size(teams)}"}
    else
      :ok
    end
  end

  defp validate_game_started(%{teams: teams}, expected_mode, :minimum, team_count) do
    if map_size(teams) < team_count do
      {:error, "#{inspect(expected_mode)} mode requires at least #{team_count} team(s), got #{map_size(teams)}"}
    else
      :ok
    end
  end

  @doc """
  Common implementation for validating team requirements across all game modes.

  This function provides a centralized validation mechanism for team requirements
  that all game modes can use during initialization.

  ## Parameters
    * `teams` - Map of team_id to list of player_ids
    * `team_requirements` - Requirements for team count validation:
      * `:exact` - Requires exactly the specified count
      * `:minimum` - Requires at least the specified count
    * `team_count` - The required number of teams (used with team_requirements)
    * `mode_name` - The name of the mode for error messages

  ## Returns
    * `:ok` - Teams are valid for this mode
    * `{:error, reason}` - Teams are invalid with reason

  ## Examples

      iex> BaseMode.validate_teams(teams, :exact, 1, "TwoPlayer")
      :ok

      iex> BaseMode.validate_teams(teams, :minimum, 2, "Knockout")
      :ok
  """
  @spec validate_teams(%{String.t() => [String.t()]}, :exact | :minimum, non_neg_integer(), String.t()) ::
    :ok | {:error, {:invalid_team_count, String.t()}}
  def validate_teams(teams, :exact, team_count, mode_name) do
    if map_size(teams) != team_count do
      {:error, {:invalid_team_count, "#{mode_name} mode requires exactly #{team_count} team(s), got #{map_size(teams)}"}}
    else
      :ok
    end
  end

  def validate_teams(teams, :minimum, team_count, mode_name) do
    if map_size(teams) < team_count do
      {:error, {:invalid_team_count, "#{mode_name} mode requires at least #{team_count} team(s), got #{map_size(teams)}"}}
    else
      :ok
    end
  end

  @doc """
  Validates that a team exists in the game state.

  ## Parameters
    * `state` - Current game state
    * `team_id` - Team ID to validate

  ## Returns
    * `:ok` - Team exists
    * `{:error, :invalid_team}` - Team doesn't exist
  """
  @spec validate_team_exists(GameState.t(), team_id()) :: :ok | {:error, :invalid_team}
  defp validate_team_exists(state, team_id) do
    if Map.has_key?(state.teams, team_id) do
      :ok
    else
      {:error, :invalid_team}
    end
  end

  @doc """
  Validates that guess contents are valid (non-empty words).

  ## Parameters
    * `word1` - First word to validate
    * `word2` - Second word to validate

  ## Returns
    * `:ok` - Words are valid
    * `{:error, :invalid_guess}` - Words are invalid
  """
  @spec validate_guess_contents(String.t(), String.t()) :: :ok | {:error, :invalid_guess}
  defp validate_guess_contents(word1, word2) do
    cond do
      is_nil(word1) or is_nil(word2) ->
        {:error, :invalid_guess}
      String.trim(word1) == "" or String.trim(word2) == "" ->
        {:error, :invalid_guess}
      true ->
        :ok
    end
  end

  @doc """
  Gets a team from the state by team ID.

  ## Parameters
    * `state` - The current game state
    * `team_id` - The ID of the team to retrieve

  ## Returns
    * `{:ok, team}` - Successfully retrieved team
    * `{:error, :invalid_team}` - Team not found
  """
  @spec get_team(GameState.t(), String.t()) :: {:ok, map()} | {:error, :invalid_team}
  def get_team(state, team_id) do
    case Map.get(state.teams, team_id) do
      nil -> {:error, :invalid_team}
      team -> {:ok, team}
    end
  end

  @doc """
  Calculates the total number of guesses across all teams.

  ## Parameters
    * `state` - The current game state

  ## Returns
    * Total guess count as an integer
  """
  @spec get_total_guesses(GameState.t()) :: non_neg_integer()
  def get_total_guesses(state) do
    state.teams
    |> Enum.map(fn {_team_id, team} -> Map.get(team, :guess_count, 0) end)
    |> Enum.sum()
  end
end
