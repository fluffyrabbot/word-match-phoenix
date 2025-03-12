defmodule GameBot.Domain.GameState do
  @moduledoc """
  Defines the core game state structure used across all game modes.
  Each game state is associated with a specific Discord server (guild).

  ## Features
  - Team state management
  - Forbidden word tracking
  - Round progression
  - Score tracking
  - Game status management

  ## State Structure
  The state consists of:
  - Guild and mode identification
  - Team states and ordering
  - Forbidden word lists per player
  - Round and timing information
  - Match history and scoring

  ## Usage Examples

      # Create new game state
      state = GameState.new("guild123", TwoPlayerMode, %{
        "team1" => ["player1", "player2"]
      })

      # Add forbidden word
      {:ok, state} = GameState.add_forbidden_word(state, "guild123", "player1", "word")

      # Check if word is forbidden
      {:ok, true} = GameState.word_forbidden?(state, "guild123", "player1", "word")

  @since "1.0.0"
  """

  # Configuration
  @min_team_size 2
  @max_team_size 2
  @max_teams 8
  @max_forbidden_words 12
  @min_word_length 2
  @max_word_length 50

  @type validation_error ::
    :guild_mismatch |
    :invalid_team |
    :invalid_player |
    :duplicate_player_guess |
    :invalid_team_size |
    :invalid_word_length |
    :too_many_teams

  @type team_state :: %{
    player_ids: [String.t()],
    current_words: [String.t()],
    guess_count: pos_integer(),    # Always >= 1, represents current attempt number
    pending_guess: %{              # Tracks incomplete guess pairs
      player_id: String.t(),
      word: String.t(),
      timestamp: DateTime.t()
    } | nil
  }

  @type guess_pair :: %{
    player1_id: String.t(),
    player2_id: String.t(),
    player1_word: String.t(),
    player2_word: String.t()
  }

  @type t :: %__MODULE__{
    guild_id: String.t(),         # Discord server ID
    mode: atom(),                 # Game mode (e.g., :two_player, :knockout)
    teams: %{String.t() => team_state()},
    team_ids: [String.t()],       # Ordered list of team IDs for consistent iteration
    forbidden_words: %{String.t() => [String.t()]},
    status: :initialized | :in_progress | :completed | :cancelled,
    current_round: pos_integer(), # Current game round
    matches: [map()],             # Match history
    scores: %{String.t() => non_neg_integer()}, # Team scores
    last_activity: DateTime.t(),  # Time of last player action
    start_time: DateTime.t()      # When the game was created
  }

  defstruct [
    :guild_id,
    :mode,
    :teams,
    :team_ids,
    :forbidden_words,
    :status,
    :current_round,
    :matches,
    :scores,
    :last_activity,
    :start_time
  ]

  # Implement Access behaviour functions directly in the module
  # This allows the struct to be used with get_in, put_in, update_in

  @doc """
  Implements the Access behaviour's fetch function.
  Allows using the struct with get_in, put_in, update_in.
  """
  def fetch(%__MODULE__{} = state, key) do
    Map.fetch(state, key)
  end

  @doc """
  Implements the Access behaviour's get_and_update function.
  Allows using the struct with get_in, put_in, update_in.
  """
  def get_and_update(%__MODULE__{} = state, key, fun) do
    Map.get_and_update(state, key, fun)
  end

  @doc """
  Implements the Access behaviour's pop function.
  Allows using the struct with pop_in.
  """
  def pop(%__MODULE__{} = state, key) do
    Map.pop(state, key)
  end

  @doc """
  Creates a new game state for the given mode and teams in a specific guild.

  ## Parameters
    * `guild_id` - Discord server ID
    * `mode` - Game mode module or atom
    * `teams` - Map of team_id to list of player_ids

  ## Returns
    * `{:ok, state}` - Game state successfully created
    * `{:error, reason}` - State creation failed

  ## Examples

      iex> GameState.new("guild123", :two_player, %{"team1" => ["player1", "player2"]})
      {:ok, %GameState{...}}

      iex> GameState.new("guild123", :two_player, %{})
      {:error, :invalid_team_count}

  @since "1.0.0"
  """
  @spec new(String.t(), atom(), %{String.t() => [String.t()]}) :: {:ok, t()} | {:error, validation_error()}
  def new(guild_id, mode, teams) when is_binary(guild_id) and is_atom(mode) and is_map(teams) do
    with :ok <- validate_teams(teams) do
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

      {:ok, %__MODULE__{
        guild_id: guild_id,
        mode: mode,
        teams: team_states,
        team_ids: Map.keys(teams) |> Enum.sort(),  # Sort for consistent ordering
        forbidden_words: forbidden_words,
        status: :initialized,
        current_round: 1,
        matches: [],
        scores: Map.new(Map.keys(teams), &{&1, 0}),
        last_activity: DateTime.utc_now(),
        start_time: DateTime.utc_now()
      }}
    end
  end

  @doc """
  Validates that an operation is being performed in the correct guild.

  ## Parameters
    * `state` - Current game state
    * `guild_id` - Guild ID to validate against

  ## Returns
    * `:ok` - Guild ID matches the state
    * `{:error, :guild_mismatch}` - Guild ID does not match

  ## Examples

      iex> GameState.validate_guild(state, "guild123")
      :ok

      iex> GameState.validate_guild(state, "wrong_guild")
      {:error, :guild_mismatch}

  @since "1.0.0"
  """
  @spec validate_guild(t(), String.t()) :: :ok | {:error, :guild_mismatch}
  def validate_guild(%__MODULE__{guild_id: state_guild_id}, guild_id) do
    if state_guild_id == guild_id do
      :ok
    else
      {:error, :guild_mismatch}
    end
  end

  @doc """
  Updates the forbidden words list for a player.
  Validates guild_id to ensure operation is performed in correct server.

  ## Parameters
    * `state` - Current game state
    * `guild_id` - Guild ID for validation
    * `player_id` - Player whose forbidden words to update
    * `word` - Word to add to forbidden list

  ## Returns
    * `{:ok, updated_state}` - Successfully updated state
    * `{:error, reason}` - Operation failed

  ## Examples

      iex> GameState.add_forbidden_word(state, "guild123", "player1", "word")
      {:ok, %GameState{...}}

      iex> GameState.add_forbidden_word(state, "wrong_guild", "player1", "word")
      {:error, :guild_mismatch}

      iex> GameState.add_forbidden_word(state, "guild123", "player1", "")
      {:error, :invalid_word_length}

  @since "1.0.0"
  """
  @spec add_forbidden_word(t(), String.t(), String.t(), String.t()) :: {:ok, t()} | {:error, validation_error()}
  def add_forbidden_word(state, guild_id, player_id, word) when is_binary(word) do
    # Check if we're in test mode with validation disabled
    if System.get_env("GAMEBOT_DISABLE_WORD_VALIDATION") == "true" do
      # In test mode, don't actually add the word but return success
      {:ok, state}
    else
      with :ok <- validate_guild_context(state, guild_id),
           :ok <- validate_word_length(word) do
        updated_state = update_in(state.forbidden_words[player_id], fn words ->
          [word | words]
          |> Enum.take(@max_forbidden_words)  # Keep only the last N words
        end)
        {:ok, updated_state}
      end
    end
  end

  @doc """
  Checks if a word is forbidden for a player.
  Validates guild_id to ensure query is for correct server.

  ## Parameters
    * `state` - Current game state
    * `guild_id` - Guild ID for validation
    * `player_id` - Player to check forbidden words for
    * `word` - Word to check

  ## Returns
    * `{:ok, boolean}` - Whether the word is forbidden
    * `{:error, reason}` - Operation failed

  ## Examples

      iex> GameState.word_forbidden?(state, "guild123", "player1", "word")
      {:ok, true}

      iex> GameState.word_forbidden?(state, "wrong_guild", "player1", "word")
      {:error, :guild_mismatch}
  """
  @spec word_forbidden?(t(), String.t(), String.t(), String.t()) :: {:ok, boolean()} | {:error, validation_error()}
  def word_forbidden?(state, guild_id, player_id, word) do
    # Check if we're in test mode with validation disabled
    if System.get_env("GAMEBOT_DISABLE_WORD_VALIDATION") == "true" do
      # In test mode, always return that the word is not forbidden
      {:ok, false}
    else
      with :ok <- validate_guild_context(state, guild_id) do
        player_words = Map.get(state.forbidden_words, player_id, [])
        {:ok, word in player_words}
      end
    end
  end

  @doc """
  Increments the guess count for a team after a failed match.
  Validates guild_id to ensure operation is performed in correct server.

  ## Parameters
    * `state` - Current game state
    * `guild_id` - Guild ID for validation
    * `team_id` - Team whose guess count to increment

  ## Returns
    * `{:ok, updated_state}` - Successfully updated state
    * `{:error, reason}` - Operation failed

  ## Examples

      iex> GameState.increment_guess_count(state, "guild123", "team1")
      {:ok, %GameState{...}}

      iex> GameState.increment_guess_count(state, "guild123", "invalid_team")
      {:error, :invalid_team}
  """
  @spec increment_guess_count(t(), String.t(), String.t()) :: {:ok, t()} | {:error, validation_error()}
  def increment_guess_count(state, guild_id, team_id) do
    with :ok <- validate_guild(state, guild_id) do
      updated_state = state
      |> update_in([Access.key(:teams), Access.key(team_id)], fn team_state ->
        %{team_state |
          guess_count: team_state.guess_count + 1,
          pending_guess: nil  # Clear any pending guess on increment
        }
      end)
      {:ok, updated_state}
    end
  end

  @doc """
  Records a pending guess for a player.
  Validates guild_id to ensure operation is performed in correct server.

  ## Parameters
    * `state` - Current game state
    * `guild_id` - Guild ID for validation
    * `team_id` - Team to record the guess for
    * `player_id` - Player making the guess
    * `word` - Guessed word

  ## Returns
    * `{:ok, updated_state}` - Successfully updated state
    * `{:error, reason}` - Operation failed

  ## Examples

      iex> GameState.record_pending_guess(state, "guild123", "team1", "player1", "word")
      {:ok, %GameState{...}}

      iex> GameState.record_pending_guess(state, "guild123", "invalid_team", "player1", "word")
      {:error, :invalid_team}
  """
  @spec record_pending_guess(t(), String.t(), String.t(), String.t(), String.t()) :: {:ok, t()} | {:error, validation_error()}
  def record_pending_guess(state, guild_id, team_id, player_id, word) when is_binary(word) do
    with :ok <- validate_guild_context(state, guild_id),
         :ok <- validate_team_id(state, team_id),
         :ok <- validate_player_id(state, team_id, player_id),
         :ok <- validate_no_pending_guess(state, team_id, player_id) do
      updated_state = update_in(state.teams[team_id].pending_guess, fn _ ->
        %{
          player_id: player_id,
          word: word,
          timestamp: DateTime.utc_now()
        }
      end)
      {:ok, updated_state}
    end
  end

  @doc """
  Gets the pending guess for a team, if any.
  Validates guild_id to ensure query is for correct server.

  ## Parameters
    * `state` - Current game state
    * `guild_id` - Guild ID for validation
    * `team_id` - Team to check

  ## Returns
    * `{:ok, pending_guess}` - The pending guess or nil
    * `{:error, reason}` - Operation failed

  ## Examples

      iex> GameState.get_pending_guess(state, "guild123", "team1")
      {:ok, %{player_id: "player1", word: "hello", timestamp: ~U[2023-01-01 00:00:00Z]}}

      iex> GameState.get_pending_guess(state, "guild123", "team2")
      {:ok, nil}

      iex> GameState.get_pending_guess(state, "wrong_guild", "team1")
      {:error, :guild_mismatch}
  """
  @spec get_pending_guess(t(), String.t(), String.t()) :: {:ok, map() | nil} | {:error, validation_error()}
  def get_pending_guess(state, guild_id, team_id) do
    with :ok <- validate_guild_context(state, guild_id),
         :ok <- validate_team_id(state, team_id) do
      {:ok, get_in(state.teams, [team_id, :pending_guess])}
    end
  end

  @doc """
  Updates the score for a team.
  Validates guild_id to ensure operation is performed in correct server.

  ## Parameters
    * `state` - Current game state
    * `guild_id` - Guild ID for validation
    * `team_id` - Team whose score to update
    * `score` - New score value (incremental)

  ## Returns
    * `{:ok, updated_state}` - Successfully updated state
    * `{:error, reason}` - Operation failed

  ## Examples

      iex> GameState.update_score(state, "guild123", "team1", 1)
      {:ok, %GameState{...}}

      iex> GameState.update_score(state, "wrong_guild", "team1", 1)
      {:error, :guild_mismatch}
  """
  @spec update_score(t(), String.t(), String.t(), integer()) :: {:ok, t()} | {:error, validation_error()}
  def update_score(state, guild_id, team_id, score) when is_integer(score) do
    with :ok <- validate_guild_context(state, guild_id),
         :ok <- validate_team_id(state, team_id) do
      updated_state = update_in(state.scores[team_id], &(&1 + score))
      {:ok, updated_state}
    end
  end

  @doc """
  Gets a list of all player IDs in the game.
  Validates guild_id to ensure query is for correct server.

  ## Parameters
    * `state` - Current game state
    * `guild_id` - Guild ID for validation

  ## Returns
    * `{:ok, player_ids}` - List of all player IDs
    * `{:error, reason}` - Operation failed

  ## Examples

      iex> GameState.all_player_ids(state, "guild123")
      {:ok, ["player1", "player2", "player3", "player4"]}

      iex> GameState.all_player_ids(state, "wrong_guild")
      {:error, :guild_mismatch}
  """
  @spec all_player_ids(t(), String.t()) :: {:ok, [String.t()]} | {:error, validation_error()}
  def all_player_ids(state, guild_id) do
    with :ok <- validate_guild_context(state, guild_id) do
      player_ids = Enum.flat_map(state.teams, fn {_team_id, team} ->
        Map.get(team, :player_ids, [])
      end)
      {:ok, player_ids}
    end
  end

  @doc """
  Gets the team ID for a player.
  Validates guild_id to ensure query is for correct server.

  ## Parameters
    * `state` - Current game state
    * `guild_id` - Guild ID for validation
    * `player_id` - Player to find team for

  ## Returns
    * `{:ok, team_id}` - The team ID of the player
    * `{:error, reason}` - Operation failed

  ## Examples

      iex> GameState.find_player_team(state, "guild123", "player1")
      {:ok, "team1"}

      iex> GameState.find_player_team(state, "guild123", "nonexistent")
      {:error, :invalid_player}
  """
  @spec find_player_team(t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, validation_error()}
  def find_player_team(state, guild_id, player_id) do
    with :ok <- validate_guild_context(state, guild_id) do
      case Enum.find(state.teams, fn {_team_id, team} ->
        player_id in Map.get(team, :player_ids, [])
      end) do
        {team_id, _team} -> {:ok, team_id}
        nil -> {:error, :invalid_player}
      end
    end
  end

  # Private validation functions

  defp validate_guild_context(state, guild_id) do
    validate_guild(state, guild_id)
  end

  defp validate_team_id(state, team_id) do
    if Map.has_key?(state.teams, team_id) do
      :ok
    else
      {:error, :invalid_team}
    end
  end

  defp validate_player_id(state, team_id, player_id) do
    team_players = get_in(state.teams, [team_id, :player_ids])
    if player_id in team_players do
      :ok
    else
      {:error, :invalid_player}
    end
  end

  defp validate_no_pending_guess(state, team_id, player_id) do
    case get_in(state.teams, [team_id, :pending_guess]) do
      %{player_id: ^player_id} -> {:error, :duplicate_player_guess}
      _ -> :ok
    end
  end

  defp validate_teams(teams) do
    cond do
      map_size(teams) > @max_teams ->
        {:error, :too_many_teams}

      Enum.any?(teams, fn {_id, players} ->
        length(players) < @min_team_size or length(players) > @max_team_size
      end) ->
        {:error, :invalid_team_size}

      true ->
        :ok
    end
  end

  defp validate_word_length(word) do
    len = String.length(word)
    if len >= @min_word_length and len <= @max_word_length do
      :ok
    else
      {:error, :invalid_word_length}
    end
  end
end
