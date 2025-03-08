defmodule GameBot.Domain.GameModes.TwoPlayerMode do
  @moduledoc """
  Two Player cooperative game mode implementation.
  Players work together to match words within a specified number of rounds,
  aiming to maintain an average guess count below the success threshold.

  ## Game Rules
  - Fixed number of rounds (default: 5)
  - Success threshold for average guesses (default: 4)
  - Both players must participate in each round
  - Guess count resets after each successful match
  - Game ends when all rounds are completed
  - Team wins if average guesses across rounds is below threshold

  ## State Structure
  The mode maintains the following state:
  - Round count and requirements
  - Success threshold for average guesses
  - Total guesses across all rounds
  - Current round number
  - Completion timestamp

  ## Usage Example
      # Initialize mode
      {:ok, state} = TwoPlayerMode.init("game-123", teams, %{
        rounds_required: 5,
        success_threshold: 4
      })

      # Process a guess pair
      {:ok, state, event} = TwoPlayerMode.process_guess_pair(state, "team1", guess_pair)

  @since "1.0.0"
  """

  @behaviour GameBot.Domain.GameModes.BaseMode

  alias GameBot.Domain.GameState
  alias GameBot.Domain.Events.GameEvents.{GuessProcessed, GuessAbandoned}

  # Configuration
  @default_rounds 5
  @default_success_threshold 4

  @type config :: %{
    rounds_required: pos_integer(),  # Number of rounds to complete
    success_threshold: pos_integer()  # Maximum average guesses for success
  }

  @type guess_pair :: %{
    player1_word: String.t(),
    player2_word: String.t()
  }

  @type state :: %{
    rounds_required: pos_integer(),
    success_threshold: pos_integer(),
    current_round: pos_integer(),
    total_guesses: non_neg_integer(),
    completion_time: DateTime.t() | nil
  }

  @doc """
  Initializes a new Two Player mode game state.

  ## Parameters
    * `game_id` - Unique identifier for the game
    * `teams` - Map of team_id to list of player_ids (must be exactly one team)
    * `config` - Mode configuration:
      * `:rounds_required` - Number of rounds to complete (default: 5)
      * `:success_threshold` - Maximum average guesses for success (default: 4)

  ## Returns
    * `{:ok, state}` - Successfully initialized state
    * `{:error, :invalid_team_count}` - Wrong number of teams provided

  ## Examples

      iex> TwoPlayerMode.init("game-123", %{"team1" => ["p1", "p2"]}, %{})
      {:ok, %{rounds_required: 5, success_threshold: 4, ...}}

      iex> TwoPlayerMode.init("game-123", %{"team1" => ["p1"], "team2" => ["p2"]}, %{})
      {:error, :invalid_team_count}

  @since "1.0.0"
  """
  @impl true
  @spec init(String.t(), %{String.t() => [String.t()]}, config()) :: {:ok, state(), [GameBot.Domain.Events.BaseEvent.t()]} | {:error, term()}
  def init(game_id, teams, config) do
    with :ok <- GameBot.Domain.GameModes.BaseMode.validate_teams(teams, :exact, 1, "TwoPlayer"),
         :ok <- validate_team_size(teams),
         :ok <- validate_config(config) do
      config = Map.merge(default_config(), config)

      {:ok, state, events} = GameBot.Domain.GameModes.BaseMode.initialize_game(__MODULE__, game_id, teams, config)

      # Initialize all required fields to prevent KeyError
      state = Map.merge(state, %{
        rounds_required: config.rounds_required,
        success_threshold: config.success_threshold,
        current_round: 1,
        total_guesses: 0,
        team_guesses: %{},
        completion_time: nil
      })

      {:ok, state, events}
    end
  end

  @doc """
  Processes a guess pair from a team.
  Updates state based on match success and manages round progression.

  ## Parameters
    * `state` - Current game state
    * `team_id` - ID of the team making the guess
    * `guess_pair` - Map containing both players' guesses

  ## Returns
    * `{:ok, new_state, event}` - Successfully processed guess pair
    * `{:error, reason}` - Failed to process guess pair

  ## Examples

      iex> TwoPlayerMode.process_guess_pair(state, "team1", %{
      ...>   player1_word: "hello",
      ...>   player2_word: "hello"
      ...> })
      {:ok, %{...updated state...}, %GuessProcessed{...}}

  ## State Updates
  - On successful match:
    * Increments current round
    * Adds guess count to total
    * Resets team's guess count
  - On failed match:
    * Maintains current round
    * Updates team's guess count

  @since "1.0.0"
  """
  @impl true
  @spec process_guess_pair(state(), String.t(), guess_pair()) ::
    {:ok, state(), GuessProcessed.t()} | {:error, term()}
  def process_guess_pair(state, team_id, guess_pair) do
    with {:ok, state, event} <- GameBot.Domain.GameModes.BaseMode.process_guess_pair(state, team_id, guess_pair) do
      state = if event.guess_successful do
        # Update total guesses and advance round
        %{state |
          total_guesses: state.total_guesses + event.guess_count,
          current_round: state.current_round + 1
        }
      else
        state
      end

      {:ok, state, event}
    end
  end

  @doc """
  Handles abandoned guesses in the game.
  Delegates to base mode implementation.

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
  In Two Player mode, rounds end only on successful matches.

  ## Parameters
    * `state` - Current game state

  ## Returns
    * `:continue` - Round should continue

  @since "1.0.0"
  """
  @impl true
  @spec check_round_end(state()) :: :continue
  def check_round_end(state) do
    :continue
  end

  @doc """
  Checks if the game should end.
  Game ends when required number of rounds is completed.

  ## Parameters
    * `state` - Current game state

  ## Returns
    * `{:game_end, winners}` - Game is complete with list of winning teams
    * `:continue` - Game should continue

  ## Examples

      iex> TwoPlayerMode.check_game_end(%{current_round: 6, rounds_required: 5, ...})
      {:game_end, ["team1"]}  # Team won with good average

      iex> TwoPlayerMode.check_game_end(%{current_round: 3, rounds_required: 5, ...})
      :continue

  @since "1.0.0"
  """
  @impl true
  @spec check_game_end(state()) :: {:game_end, [String.t()]} | :continue
  def check_game_end(%{current_round: current, rounds_required: required} = state) when current > required do
    # Calculate final metrics
    avg_guesses = state.total_guesses / state.rounds_required
    winners = if avg_guesses <= state.success_threshold, do: Map.keys(state.teams), else: []

    {:game_end, winners}
  end

  def check_game_end(_state) do
    :continue
  end

  # Private Functions

  @doc false
  # Returns default configuration for the game mode
  defp default_config do
    %{
      rounds_required: @default_rounds,
      success_threshold: @default_success_threshold
    }
  end

  @doc """
  Validates an event for the Two Player mode.
  Ensures that events contain the required fields and values for this mode.

  ## Parameters
    * `event` - The event to validate

  ## Returns
    * `:ok` - Event is valid for this mode
    * `{:error, reason}` - Event is invalid with reason

  ## Examples

      iex> TwoPlayerMode.validate_event(%GameEvents.GameStarted{mode: :two_player})
      :ok

      iex> TwoPlayerMode.validate_event(%GameEvents.GameStarted{mode: :knockout})
      {:error, "Invalid mode for TwoPlayerMode: expected :two_player, got :knockout"}

  @since "1.0.0"
  """
  @spec validate_event(struct()) :: :ok | {:error, String.t()}
  def validate_event(event) do
    GameBot.Domain.GameModes.BaseMode.validate_event(event, :two_player, :exact, 1)
  end

  @doc false
  # Validates team size
  defp validate_team_size(teams) do
    if Enum.all?(teams, fn {_id, players} -> length(players) == 2 end) do
      :ok
    else
      {:error, {:invalid_team_size, "Each team must have exactly 2 players"}}
    end
  end

  @doc false
  # Validates configuration parameters
  defp validate_config(config) do
    cond do
      is_nil(config) ->
        {:error, :missing_config}
      Map.get(config, :rounds_required, @default_rounds) <= 0 ->
        {:error, :invalid_rounds}
      Map.get(config, :success_threshold, @default_success_threshold) <= 0 ->
        {:error, :invalid_threshold}
      true ->
        :ok
    end
  end

  @doc false
  # Validates guess pair and team status
  defp validate_guess_pair(state, team_id, %{
    player1_id: player1_id,
    player2_id: player2_id,
    player1_word: player1_word,
    player2_word: player2_word
  }) do
    team_players = get_in(state.teams, [team_id, :player_ids])

    cond do
      !Map.has_key?(state.teams, team_id) ->
        {:error, :invalid_team}

      player1_id not in team_players or player2_id not in team_players ->
        {:error, :invalid_player}

      player1_id == player2_id ->
        {:error, :same_player}

      GameBot.Domain.GameState.word_forbidden?(state, state.guild_id, player1_id, player1_word) ->
        {:error, :word_forbidden}

      GameBot.Domain.GameState.word_forbidden?(state, state.guild_id, player2_id, player2_word) ->
        {:error, :word_forbidden}

      true ->
        :ok
    end
  end
end
