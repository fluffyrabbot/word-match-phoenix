defmodule GameBot.Domain.Events.ErrorEvents do
  @moduledoc """
  Defines error events that can occur during game play.
  """

  alias GameBot.Domain.Events.Metadata

  @type metadata :: Metadata.t()

  defmodule GuessError do
    @moduledoc """
    Emitted when there is an error processing a guess.

    Base fields:
    - game_id: Unique identifier for the game
    - guild_id: Discord guild ID where the game is being played
    - timestamp: When the error occurred
    - metadata: Additional context about the error

    Event-specific fields:
    - team_id: ID of the team that made the guess
    - player_id: ID of the player that made the guess
    - word: The word that was guessed
    - reason: Why the guess failed (see @type reason())
    """
    use GameBot.Domain.Events.EventBuilderAdapter

    @type reason :: :invalid_word | :not_players_turn | :word_already_guessed | :invalid_player | :invalid_team

    @type t :: %__MODULE__{
      # Base fields
      game_id: String.t(),
      guild_id: String.t(),
      timestamp: DateTime.t(),
      metadata: metadata(),
      # Event-specific fields
      team_id: String.t(),
      player_id: String.t(),
      word: String.t(),
      reason: reason()
    }
    defstruct [:game_id, :guild_id, :team_id, :player_id, :word, :reason, :timestamp, :metadata]

    @doc """
    Returns the string type identifier for this event.
    """
    def event_type(), do: "guess_error"

    @impl true
    def validate_attrs(attrs) do
      with {:ok, base_attrs} <- super(attrs),
           :ok <- validate_required_field(attrs, :team_id),
           :ok <- validate_required_field(attrs, :player_id),
           :ok <- validate_required_field(attrs, :word),
           :ok <- validate_required_field(attrs, :reason),
           :ok <- validate_string_field(attrs, :team_id),
           :ok <- validate_string_field(attrs, :player_id),
           :ok <- validate_string_field(attrs, :word),
           :ok <- validate_reason(attrs.reason) do
        {:ok, base_attrs}
      end
    end

    defp validate_reason(nil), do: {:error, {:validation, "reason is required"}}
    defp validate_reason(reason) when reason in [:invalid_word, :not_players_turn, :word_already_guessed, :invalid_player, :invalid_team], do: :ok
    defp validate_reason(_), do: {:error, {:validation, "invalid reason"}}

    @doc """
    Creates a new GuessError event with the specified attributes.

    ## Parameters
    - game_id: Unique identifier for the game
    - guild_id: Discord guild ID where the game is being played
    - team_id: ID of the team that made the guess
    - player_id: ID of the player that made the guess
    - word: The word that was guessed
    - reason: Why the guess failed
    - metadata: Optional event metadata

    ## Returns
    - `{:ok, event}` if validation succeeds
    - `{:error, reason}` if validation fails
    """
    @spec create(String.t(), String.t(), String.t(), String.t(), String.t(), reason(), map()) :: {:ok, t()} | {:error, term()}
    def create(game_id, guild_id, team_id, player_id, word, reason, metadata \\ %{}) do
      attrs = %{
        game_id: game_id,
        guild_id: guild_id,
        team_id: team_id,
        player_id: player_id,
        word: word,
        reason: reason
      }

      new(attrs, metadata)
    end
  end

  defmodule GuessPairError do
    @moduledoc """
    Emitted when there is an error processing a guess pair.

    Base fields:
    - game_id: Unique identifier for the game
    - guild_id: Discord guild ID where the game is being played
    - timestamp: When the error occurred
    - metadata: Additional context about the error

    Event-specific fields:
    - team_id: ID of the team that made the guess pair
    - word1: First word in the pair
    - word2: Second word in the pair
    - reason: Why the guess pair failed (see @type reason())
    """
    use GameBot.Domain.Events.EventBuilderAdapter

    @type reason :: :invalid_word_pair | :not_teams_turn | :words_already_guessed | :invalid_team | :same_words

    @type t :: %__MODULE__{
      # Base fields
      game_id: String.t(),
      guild_id: String.t(),
      timestamp: DateTime.t(),
      metadata: metadata(),
      # Event-specific fields
      team_id: String.t(),
      word1: String.t(),
      word2: String.t(),
      reason: reason()
    }
    defstruct [:game_id, :guild_id, :team_id, :word1, :word2, :reason, :timestamp, :metadata]

    @doc """
    Returns the string type identifier for this event.
    """
    def event_type(), do: "guess_pair_error"

    @impl true
    def validate_attrs(attrs) do
      with {:ok, base_attrs} <- super(attrs),
           :ok <- validate_required_field(attrs, :team_id),
           :ok <- validate_required_field(attrs, :word1),
           :ok <- validate_required_field(attrs, :word2),
           :ok <- validate_required_field(attrs, :reason),
           :ok <- validate_string_field(attrs, :team_id),
           :ok <- validate_string_field(attrs, :word1),
           :ok <- validate_string_field(attrs, :word2),
           :ok <- validate_words(attrs.word1, attrs.word2),
           :ok <- validate_reason(attrs.reason) do
        {:ok, base_attrs}
      end
    end

    defp validate_words(word, word), do: {:error, {:validation, "word1 and word2 cannot be the same"}}
    defp validate_words(_, _), do: :ok

    defp validate_reason(nil), do: {:error, {:validation, "reason is required"}}
    defp validate_reason(reason) when reason in [:invalid_word_pair, :not_teams_turn, :words_already_guessed, :invalid_team, :same_words], do: :ok
    defp validate_reason(_), do: {:error, {:validation, "invalid reason"}}

    @doc """
    Creates a new GuessPairError event with the specified attributes.

    ## Parameters
    - game_id: Unique identifier for the game
    - guild_id: Discord guild ID where the game is being played
    - team_id: ID of the team that made the guess pair
    - word1: First word in the pair
    - word2: Second word in the pair
    - reason: Why the guess pair failed
    - metadata: Optional event metadata

    ## Returns
    - `{:ok, event}` if validation succeeds
    - `{:error, reason}` if validation fails
    """
    @spec create(String.t(), String.t(), String.t(), String.t(), String.t(), reason(), map()) :: {:ok, t()} | {:error, term()}
    def create(game_id, guild_id, team_id, word1, word2, reason, metadata \\ %{}) do
      attrs = %{
        game_id: game_id,
        guild_id: guild_id,
        team_id: team_id,
        word1: word1,
        word2: word2,
        reason: reason
      }

      new(attrs, metadata)
    end
  end

  defmodule GameError do
    @moduledoc """
    Emitted when there is an error related to game state.

    Base fields:
    - game_id: Unique identifier for the game
    - guild_id: Discord guild ID where the game is being played
    - timestamp: When the error occurred
    - metadata: Additional context about the error

    Event-specific fields:
    - reason: Why the game operation failed (see @type reason())
    - details: Optional additional information about the error
    """
    use GameBot.Domain.Events.EventBuilderAdapter

    @type reason :: :game_not_found | :game_already_exists | :invalid_game_state | :invalid_operation

    @type t :: %__MODULE__{
      # Base fields
      game_id: String.t(),
      guild_id: String.t(),
      timestamp: DateTime.t(),
      metadata: metadata(),
      # Event-specific fields
      reason: reason(),
      details: String.t() | nil
    }
    defstruct [:game_id, :guild_id, :reason, :details, :timestamp, :metadata]

    @doc """
    Returns the string type identifier for this event.
    """
    def event_type(), do: "game_error"

    @impl true
    def validate_attrs(attrs) do
      with {:ok, base_attrs} <- super(attrs),
           :ok <- validate_required_field(attrs, :reason),
           :ok <- validate_reason(attrs.reason),
           :ok <- validate_string_field(attrs, :details) do
        {:ok, base_attrs}
      end
    end

    defp validate_reason(nil), do: {:error, {:validation, "reason is required"}}
    defp validate_reason(reason) when reason in [:game_not_found, :game_already_exists, :invalid_game_state, :invalid_operation], do: :ok
    defp validate_reason(_), do: {:error, {:validation, "invalid reason"}}

    @doc """
    Creates a new GameError event with the specified attributes.

    ## Parameters
    - game_id: Unique identifier for the game
    - guild_id: Discord guild ID where the game is being played
    - reason: Why the game operation failed
    - details: Optional additional information about the error
    - metadata: Optional event metadata

    ## Returns
    - `{:ok, event}` if validation succeeds
    - `{:error, reason}` if validation fails
    """
    @spec create(String.t(), String.t(), reason(), String.t() | nil, map()) :: {:ok, t()} | {:error, term()}
    def create(game_id, guild_id, reason, details \\ nil, metadata \\ %{}) do
      attrs = %{
        game_id: game_id,
        guild_id: guild_id,
        reason: reason,
        details: details
      }

      new(attrs, metadata)
    end
  end
end
