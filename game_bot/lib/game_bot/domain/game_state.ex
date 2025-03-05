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
  @max_teams 12
  @max_forbidden_words 12
  @min_word_length 2
  @max_word_length 50

  @type validation_error ::
    :guild_mismatch |
    :invalid_team |
    :invalid_player |
    :duplicate_player_guess |
    :invalid_team_size |
    :too_many_teams |
    :invalid_word_length

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
    guild_id: String.t(),         # Discord server ID where game is being played
    mode: atom(),                 # Module implementing the game mode
    teams: %{String.t() => team_state()},  # Map of team_id to team_state
    team_ids: [String.t()],      # Ordered list of team IDs for consistent ordering
    forbidden_words: %{String.t() => [String.t()]},  # Map of player_id to [forbidden words]
    round_number: pos_integer(),  # Current round number
    start_time: DateTime.t() | nil,  # Game start timestamp
    last_activity: DateTime.t() | nil,  # Last guess timestamp
    matches: [map()],            # List of successful matches with metadata
    scores: %{String.t() => term()},  # Map of team_id to current score
    status: :waiting | :in_progress | :completed  # Game status
  }

  defstruct [
    guild_id: nil,
    mode: nil,
    teams: %{},
    team_ids: [],
    forbidden_words: %{},
    round_number: 1,
    start_time: nil,
    last_activity: nil,
    matches: [],
    scores: %{},
    status: :waiting
  ]

  @doc """
  Creates a new game state for the given mode and teams in a specific guild.

  ## Parameters
    * `guild_id` - Discord server ID where the game is being played
    * `mode` - Module implementing the game mode
    * `teams` - Map of team_id to list of player_ids

  ## Returns
    * A new GameState struct initialized with the provided parameters
    * `{:error, reason}` - If validation fails

  ## Examples

      iex> GameState.new("guild123", TwoPlayerMode, %{"team1" => ["p1", "p2"]})
      {:ok, %GameState{
        guild_id: "guild123",
        mode: TwoPlayerMode,
        teams: %{
          "team1" => %{
            player_ids: ["p1", "p2"],
            current_words: [],
            guess_count: 1,
            pending_guess: nil
          }
        },
        team_ids: ["team1"],
        forbidden_words: %{"p1" => [], "p2" => []}
      }}

      iex> GameState.new("guild123", TwoPlayerMode, %{"team1" => ["p1"]})
      {:error, :invalid_team_size}

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

      forbidden_words = teams
      |> Enum.flat_map(fn {_team_id, player_ids} -> player_ids end)
      |> Map.new(fn player_id -> {player_id, []} end)

      {:ok, %__MODULE__{
        guild_id: guild_id,
        mode: mode,
        teams: team_states,
        team_ids: Map.keys(teams) |> Enum.sort(),  # Sort for consistent ordering
        forbidden_words: forbidden_words
      }}
    end
  end

  @doc """
  Validates that an operation is being performed in the correct guild.

  ## Parameters
    * `state` - Current game state
    * `guild_id` - Guild ID to validate against

  ## Returns
    * `:ok` - Guild IDs match
    * `{:error, :guild_mismatch}` - Guild IDs don't match

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
    with :ok <- validate_guild(state, guild_id),
         :ok <- validate_word_length(word) do
      updated_state = update_in(state.forbidden_words[player_id], fn words ->
        [word | words]
        |> Enum.take(@max_forbidden_words)  # Keep only the last N words
      end)
      {:ok, updated_state}
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
    with :ok <- validate_guild(state, guild_id) do
      player_words = Map.get(state.forbidden_words, player_id, [])
      {:ok, word in player_words}
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
  Records a pending guess for a player in a team.
  Validates guild_id to ensure operation is performed in correct server.

  ## Parameters
    * `state` - Current game state
    * `guild_id` - Guild ID for validation
    * `team_id` - Team ID for the guess
    * `player_id` - Player making the guess
    * `word` - The guessed word

  ## Returns
    * `{:ok, updated_state, guess_pair}` - Guess pair completed
    * `{:pending, updated_state}` - First guess recorded
    * `{:error, reason}` - Operation failed

  ## Examples

      iex> GameState.record_pending_guess(state, "guild123", "team1", "player1", "word")
      {:pending, %GameState{...}}

      iex> GameState.record_pending_guess(state, "guild123", "team1", "player2", "word")
      {:ok, %GameState{...}, %{player1_id: "player1", player2_id: "player2", ...}}
  """
  @spec record_pending_guess(t(), String.t(), String.t(), String.t(), String.t()) ::
    {:ok, t(), guess_pair()} |
    {:pending, t()} |
    {:error, validation_error()}
  def record_pending_guess(state, guild_id, team_id, player_id, word) do
    with :ok <- validate_guild(state, guild_id) do
      case get_in(state.teams, [team_id]) do
        nil ->
          {:error, :invalid_team}

        team_state ->
          case team_state.pending_guess do
            nil ->
              # No pending guess, record this one
              state = put_in(state.teams[team_id].pending_guess, %{
                player_id: player_id,
                word: word,
                timestamp: DateTime.utc_now()
              })
              {:pending, state}

            %{player_id: pending_player_id} when pending_player_id == player_id ->
              {:error, :duplicate_player_guess}

            %{player_id: other_player_id, word: other_word} ->
              # Complete the pair
              state = put_in(state.teams[team_id].pending_guess, nil)
              {:ok, state, %{
                player1_id: other_player_id,
                player2_id: player_id,
                player1_word: other_word,
                player2_word: word
              }}
          end
      end
    end
  end

  @doc """
  Clears a pending guess for a team.
  Validates guild_id to ensure operation is performed in correct server.

  ## Parameters
    * `state` - Current game state
    * `guild_id` - Guild ID for validation
    * `team_id` - Team whose pending guess to clear

  ## Returns
    * `{:ok, updated_state}` - Successfully cleared pending guess
    * `{:error, reason}` - Operation failed

  ## Examples

      iex> GameState.clear_pending_guess(state, "guild123", "team1")
      {:ok, %GameState{...}}

      iex> GameState.clear_pending_guess(state, "wrong_guild", "team1")
      {:error, :guild_mismatch}
  """
  @spec clear_pending_guess(t(), String.t(), String.t()) :: {:ok, t()} | {:error, validation_error()}
  def clear_pending_guess(state, guild_id, team_id) do
    with :ok <- validate_guild(state, guild_id) do
      updated_state = put_in(state.teams[team_id].pending_guess, nil)
      {:ok, updated_state}
    end
  end

  # Private Functions

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
