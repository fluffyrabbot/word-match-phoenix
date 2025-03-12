defmodule GameBot.Domain.Events.GuessEvents do
  @moduledoc """
  Contains event structs for guess-related events in the game domain.
  """

  alias GameBot.Domain.Events.Metadata

  @type metadata :: Metadata.t()
  @type player_info :: {integer(), String.t(), String.t() | nil}  # {discord_id, username, nickname}

  defmodule GuessProcessed do
    @moduledoc """
    Emitted when a guess attempt is processed.
    This event represents the complete lifecycle of a guess:
    1. Both players have submitted their words
    2. The guess has been validated
    3. The match has been checked
    4. The result has been recorded

    Base fields:
    - game_id: Unique identifier for the game
    - guild_id: Discord guild ID where the game is being played
    - timestamp: When the guess was processed
    - metadata: Additional context about the event

    Event-specific fields:
    - team_id: ID of the team that made the guess
    - player1_info: {discord_id, username, nickname} tuple for the first player
    - player2_info: {discord_id, username, nickname} tuple for the second player
    - player1_word: Word submitted by the first player
    - player2_word: Word submitted by the second player
    - guess_successful: Whether the guess resulted in a match
    - match_score: Score for the match (if successful)
    - guess_count: Number of guesses made by this team in the game
    - round_guess_count: Number of guesses made by this team in the current round
    - total_guesses: Number of guesses made by all teams in the game
    - guess_duration: Duration of the guess in milliseconds
    - player1_duration: Time in milliseconds player1 took to submit their word
    - player2_duration: Time in milliseconds player2 took to submit their word
    """
    use GameBot.Domain.Events.EventBuilderAdapter

    @type t :: %__MODULE__{
      # Base fields
      game_id: String.t(),
      guild_id: String.t(),
      timestamp: DateTime.t(),
      metadata: GameBot.Domain.Events.GuessEvents.metadata(),
      # Event-specific fields
      team_id: String.t(),
      player1_info: GameBot.Domain.Events.GuessEvents.player_info(),
      player2_info: GameBot.Domain.Events.GuessEvents.player_info(),
      player1_word: String.t(),
      player2_word: String.t(),
      guess_successful: boolean(),
      match_score: integer() | nil,
      guess_count: non_neg_integer(),
      round_guess_count: non_neg_integer(),
      total_guesses: non_neg_integer(),
      guess_duration: non_neg_integer(),
      player1_duration: non_neg_integer(),
      player2_duration: non_neg_integer()
    }

    defstruct [
      :game_id,
      :guild_id,
      :team_id,
      :player1_info,
      :player2_info,
      :player1_word,
      :player2_word,
      :guess_successful,
      :match_score,
      :guess_count,
      :round_guess_count,
      :total_guesses,
      :guess_duration,
      :player1_duration,
      :player2_duration,
      :timestamp,
      :metadata
    ]

    @doc """
    Returns the string type identifier for this event.
    """
    @impl true
    def event_type(), do: "guess_processed"

    @impl true
    def event_version(), do: 1

    def validate_attrs(attrs) do
      with {:ok, base_attrs} <- super(attrs),
           :ok <- validate_required_field(attrs, :team_id),
           :ok <- validate_required_field(attrs, :player1_info),
           :ok <- validate_required_field(attrs, :player2_info),
           :ok <- validate_required_field(attrs, :player1_word),
           :ok <- validate_required_field(attrs, :player2_word),
           :ok <- validate_required_field(attrs, :guess_successful),
           :ok <- validate_required_field(attrs, :guess_count),
           :ok <- validate_required_field(attrs, :round_guess_count),
           :ok <- validate_required_field(attrs, :total_guesses),
           :ok <- validate_required_field(attrs, :guess_duration),
           :ok <- validate_required_field(attrs, :player1_duration),
           :ok <- validate_required_field(attrs, :player2_duration),
           :ok <- validate_string_field(attrs, :team_id),
           :ok <- validate_string_field(attrs, :player1_word),
           :ok <- validate_string_field(attrs, :player2_word),
           :ok <- validate_player_info_tuple(attrs, :player1_info),
           :ok <- validate_player_info_tuple(attrs, :player2_info),
           :ok <- validate_boolean_field(attrs, :guess_successful),
           :ok <- validate_non_negative_integer_field(attrs, :guess_count),
           :ok <- validate_non_negative_integer_field(attrs, :round_guess_count),
           :ok <- validate_non_negative_integer_field(attrs, :total_guesses),
           :ok <- validate_non_negative_integer_field(attrs, :guess_duration),
           :ok <- validate_non_negative_integer_field(attrs, :player1_duration),
           :ok <- validate_non_negative_integer_field(attrs, :player2_duration),
           :ok <- validate_match_score(attrs) do
        {:ok, base_attrs}
      end
    end

    defp validate_player_info_tuple(attrs, field) do
      case Map.get(attrs, field) do
        nil ->
          {:error, {:validation, "#{field} is required"}}
        {discord_id, username, nickname} when is_integer(discord_id) and is_binary(username) and (is_binary(nickname) or is_nil(nickname)) ->
          :ok
        _ ->
          {:error, {:validation, "#{field} must be a tuple {discord_id, username, nickname} where discord_id is an integer, username is a string, and nickname is a string or nil"}}
      end
    end

    defp validate_match_score(%{guess_successful: true, match_score: nil}) do
      {:error, {:validation, "match_score is required when guess is successful"}}
    end

    defp validate_match_score(%{guess_successful: false, match_score: score}) when not is_nil(score) do
      {:error, {:validation, "match_score must be nil when guess is not successful"}}
    end

    defp validate_match_score(_), do: :ok

    @doc """
    Creates a new GuessProcessed event with the specified attributes.

    ## Parameters
    - attrs: Map of event attributes
    - metadata: Event metadata map or struct

    ## Returns
    - `{:ok, event}` if validation succeeds
    - `{:error, reason}` if validation fails
    """
    @spec create(map(), map()) :: {:ok, t()} | {:error, term()}
    def create(attrs, metadata \\ %{}) do
      new(attrs, metadata)
    end
  end

  defmodule GuessStarted do
    @moduledoc """
    Emitted when a player initiates a guess.
    This event represents the start of a guess attempt.

    Base fields:
    - game_id: Unique identifier for the game
    - guild_id: Discord guild ID where the game is being played
    - timestamp: When the guess was initiated
    - metadata: Additional context about the event

    Event-specific fields:
    - team_id: ID of the team making the guess
    - player_id: ID of the player initiating the guess
    - channel_id: Channel where the guess was initiated
    """
    use GameBot.Domain.Events.EventBuilderAdapter

    @type t :: %__MODULE__{
      # Base fields
      game_id: String.t(),
      guild_id: String.t(),
      timestamp: DateTime.t(),
      metadata: metadata(),
      # Event-specific fields
      team_id: String.t(),
      player_id: String.t(),
      channel_id: String.t()
    }

    defstruct [
      :game_id,
      :guild_id,
      :team_id,
      :player_id,
      :channel_id,
      :timestamp,
      :metadata
    ]

    @doc """
    Returns the string type identifier for this event.
    """
    @impl true
    def event_type(), do: "guess_started"

    @impl true
    def event_version(), do: 1

    def validate_attrs(attrs) do
      with {:ok, base_attrs} <- super(attrs),
           :ok <- validate_required_field(attrs, :team_id),
           :ok <- validate_required_field(attrs, :player_id),
           :ok <- validate_required_field(attrs, :channel_id),
           :ok <- validate_string_field(attrs, :team_id),
           :ok <- validate_string_field(attrs, :player_id),
           :ok <- validate_string_field(attrs, :channel_id) do
        {:ok, base_attrs}
      end
    end

    @doc """
    Creates a new GuessStarted event with the specified attributes.

    ## Parameters
    - game_id: Unique identifier for the game
    - guild_id: Discord guild ID where the game is being played
    - team_id: ID of the team making the guess
    - player_id: ID of the player initiating the guess
    - channel_id: Channel where the guess was initiated
    - metadata: Optional event metadata

    ## Returns
    - `{:ok, event}` if validation succeeds
    - `{:error, reason}` if validation fails
    """
    @spec create(String.t(), String.t(), String.t(), String.t(), String.t(), map()) :: {:ok, t()} | {:error, term()}
    def create(game_id, guild_id, team_id, player_id, channel_id, metadata \\ %{}) do
      attrs = %{
        game_id: game_id,
        guild_id: guild_id,
        team_id: team_id,
        player_id: player_id,
        channel_id: channel_id
      }

      new(attrs, metadata)
    end
  end

  defmodule GuessAbandoned do
    @moduledoc """
    Emitted when a guess attempt is abandoned.
    This can occur due to timeout, user cancellation, or system intervention.

    Base fields:
    - game_id: Unique identifier for the game
    - guild_id: Discord guild ID where the game is being played
    - timestamp: When the guess was abandoned
    - metadata: Additional context about the event

    Event-specific fields:
    - team_id: ID of the team that was making the guess
    - player_id: ID of the player who initiated the guess (if known)
    - reason: Why the guess was abandoned (:timeout, :user_cancelled, :system_cancelled)
    """
    use GameBot.Domain.Events.EventBuilderAdapter

    @type reason :: :timeout | :user_cancelled | :system_cancelled

    @type t :: %__MODULE__{
      # Base fields
      game_id: String.t(),
      guild_id: String.t(),
      timestamp: DateTime.t(),
      metadata: metadata(),
      # Event-specific fields
      team_id: String.t(),
      player_id: String.t() | nil,
      reason: reason()
    }

    defstruct [
      :game_id,
      :guild_id,
      :team_id,
      :player_id,
      :reason,
      :timestamp,
      :metadata
    ]

    @doc """
    Returns the string type identifier for this event.
    """
    @impl true
    def event_type(), do: "guess_abandoned"

    @impl true
    def event_version(), do: 1

    def validate_attrs(attrs) do
      with {:ok, base_attrs} <- super(attrs),
           :ok <- validate_required_field(attrs, :team_id),
           :ok <- validate_required_field(attrs, :reason),
           :ok <- validate_string_field(attrs, :team_id),
           :ok <- validate_string_field(attrs, :player_id),
           :ok <- validate_reason(attrs.reason) do
        {:ok, base_attrs}
      end
    end

    defp validate_reason(nil), do: {:error, {:validation, "reason is required"}}
    defp validate_reason(reason) when reason in [:timeout, :user_cancelled, :system_cancelled], do: :ok
    defp validate_reason(_), do: {:error, {:validation, "invalid reason"}}

    @doc """
    Creates a new GuessAbandoned event with the specified attributes.

    ## Parameters
    - game_id: Unique identifier for the game
    - guild_id: Discord guild ID where the game is being played
    - team_id: ID of the team that was making the guess
    - player_id: ID of the player who initiated the guess (if known)
    - reason: Why the guess was abandoned
    - metadata: Optional event metadata

    ## Returns
    - `{:ok, event}` if validation succeeds
    - `{:error, reason}` if validation fails
    """
    @spec create(String.t(), String.t(), String.t(), String.t() | nil, reason(), map()) :: {:ok, t()} | {:error, term()}
    def create(game_id, guild_id, team_id, player_id \\ nil, reason, metadata \\ %{}) do
      attrs = %{
        game_id: game_id,
        guild_id: guild_id,
        team_id: team_id,
        player_id: player_id,
        reason: reason
      }

      new(attrs, metadata)
    end
  end
end
