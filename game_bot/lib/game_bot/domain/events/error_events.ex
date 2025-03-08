defmodule GameBot.Domain.Events.ErrorEvents do
  @moduledoc """
  Defines error events that can occur during game play.
  """

  alias GameBot.Domain.Events.{EventStructure, Metadata}

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
    use EventStructure

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

    @impl true
    def event_type(), do: "guess_error"

    @impl true
    def event_version(), do: 1

    @impl true
    def validate(event) do
      with :ok <- validate_required_base_fields(event),
           :ok <- validate_event_fields(event) do
        :ok
      end
    end

    defp validate_required_base_fields(%__MODULE__{} = event) do
      cond do
        is_nil(event.game_id) -> {:error, "game_id is required"}
        is_nil(event.guild_id) -> {:error, "guild_id is required"}
        is_nil(event.timestamp) -> {:error, "timestamp is required"}
        true -> :ok
      end
    end

    defp validate_event_fields(%__MODULE__{} = event) do
      with :ok <- validate_team_id(event.team_id),
           :ok <- validate_player_id(event.player_id),
           :ok <- validate_word(event.word),
           :ok <- validate_reason(event.reason) do
        :ok
      end
    end

    defp validate_team_id(nil), do: {:error, "team_id is required"}
    defp validate_team_id(_), do: :ok

    defp validate_player_id(nil), do: {:error, "player_id is required"}
    defp validate_player_id(_), do: :ok

    defp validate_word(nil), do: {:error, "word is required"}
    defp validate_word(""), do: {:error, "word cannot be empty"}
    defp validate_word(_), do: :ok

    defp validate_reason(nil), do: {:error, "reason is required"}
    defp validate_reason(reason) when reason in [:invalid_word, :not_players_turn, :word_already_guessed, :invalid_player, :invalid_team], do: :ok
    defp validate_reason(_), do: {:error, "invalid reason"}

    @impl true
    def to_map(%__MODULE__{} = event) do
      %{
        "game_id" => event.game_id,
        "guild_id" => event.guild_id,
        "team_id" => event.team_id,
        "player_id" => event.player_id,
        "word" => event.word,
        "reason" => Atom.to_string(event.reason),
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "metadata" => event.metadata || %{}
      }
    end

    @impl true
    def from_map(data) do
      %__MODULE__{
        game_id: data["game_id"],
        guild_id: data["guild_id"],
        team_id: data["team_id"],
        player_id: data["player_id"],
        word: data["word"],
        reason: String.to_existing_atom(data["reason"]),
        timestamp: EventStructure.parse_timestamp(data["timestamp"]),
        metadata: data["metadata"] || %{}
      }
    end

    def new(game_id, guild_id, team_id, player_id, word, reason) do
      %__MODULE__{
        game_id: game_id,
        guild_id: guild_id,
        team_id: team_id,
        player_id: player_id,
        word: word,
        reason: reason,
        timestamp: DateTime.utc_now(),
        metadata: %{}
      }
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
    use EventStructure

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

    @impl true
    def event_type(), do: "guess_pair_error"

    @impl true
    def event_version(), do: 1

    @impl true
    def validate(event) do
      with :ok <- validate_required_base_fields(event),
           :ok <- validate_event_fields(event) do
        :ok
      end
    end

    defp validate_required_base_fields(%__MODULE__{} = event) do
      cond do
        is_nil(event.game_id) -> {:error, "game_id is required"}
        is_nil(event.guild_id) -> {:error, "guild_id is required"}
        is_nil(event.timestamp) -> {:error, "timestamp is required"}
        true -> :ok
      end
    end

    defp validate_event_fields(%__MODULE__{} = event) do
      with :ok <- validate_team_id(event.team_id),
           :ok <- validate_words(event.word1, event.word2),
           :ok <- validate_reason(event.reason) do
        :ok
      end
    end

    defp validate_team_id(nil), do: {:error, "team_id is required"}
    defp validate_team_id(_), do: :ok

    defp validate_words(nil, _), do: {:error, "word1 is required"}
    defp validate_words(_, nil), do: {:error, "word2 is required"}
    defp validate_words("", _), do: {:error, "word1 cannot be empty"}
    defp validate_words(_, ""), do: {:error, "word2 cannot be empty"}
    defp validate_words(word, word), do: {:error, "word1 and word2 cannot be the same"}
    defp validate_words(_, _), do: :ok

    defp validate_reason(nil), do: {:error, "reason is required"}
    defp validate_reason(reason) when reason in [:invalid_word_pair, :not_teams_turn, :words_already_guessed, :invalid_team, :same_words], do: :ok
    defp validate_reason(_), do: {:error, "invalid reason"}

    @impl true
    def to_map(%__MODULE__{} = event) do
      %{
        "game_id" => event.game_id,
        "guild_id" => event.guild_id,
        "team_id" => event.team_id,
        "word1" => event.word1,
        "word2" => event.word2,
        "reason" => Atom.to_string(event.reason),
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "metadata" => event.metadata || %{}
      }
    end

    @impl true
    def from_map(data) do
      %__MODULE__{
        game_id: data["game_id"],
        guild_id: data["guild_id"],
        team_id: data["team_id"],
        word1: data["word1"],
        word2: data["word2"],
        reason: String.to_existing_atom(data["reason"]),
        timestamp: EventStructure.parse_timestamp(data["timestamp"]),
        metadata: data["metadata"] || %{}
      }
    end

    def new(game_id, guild_id, team_id, word1, word2, reason) do
      %__MODULE__{
        game_id: game_id,
        guild_id: guild_id,
        team_id: team_id,
        word1: word1,
        word2: word2,
        reason: reason,
        timestamp: DateTime.utc_now(),
        metadata: %{}
      }
    end
  end

  defmodule RoundCheckError do
    @moduledoc """
    Emitted when there is an error checking round status.

    Base fields:
    - game_id: Unique identifier for the game
    - guild_id: Discord guild ID where the game is being played
    - timestamp: When the error occurred
    - metadata: Additional context about the error

    Event-specific fields:
    - reason: Why the round check failed (see @type reason())
    """
    use EventStructure

    @type reason :: :invalid_round_state | :round_not_found | :game_not_found | :invalid_game_state

    @type t :: %__MODULE__{
      # Base fields
      game_id: String.t(),
      guild_id: String.t(),
      timestamp: DateTime.t(),
      metadata: metadata(),
      # Event-specific fields
      reason: reason()
    }
    defstruct [:game_id, :guild_id, :reason, :timestamp, :metadata]

    @impl true
    def event_type(), do: "round_check_error"

    @impl true
    def event_version(), do: 1

    @impl true
    def validate(event) do
      with :ok <- validate_required_base_fields(event),
           :ok <- validate_reason(event.reason) do
        :ok
      end
    end

    defp validate_required_base_fields(%__MODULE__{} = event) do
      cond do
        is_nil(event.game_id) -> {:error, "game_id is required"}
        is_nil(event.guild_id) -> {:error, "guild_id is required"}
        is_nil(event.timestamp) -> {:error, "timestamp is required"}
        true -> :ok
      end
    end

    defp validate_reason(nil), do: {:error, "reason is required"}
    defp validate_reason(reason) when reason in [:invalid_round_state, :round_not_found, :game_not_found, :invalid_game_state], do: :ok
    defp validate_reason(_), do: {:error, "invalid reason"}

    @impl true
    def to_map(%__MODULE__{} = event) do
      %{
        "game_id" => event.game_id,
        "guild_id" => event.guild_id,
        "reason" => Atom.to_string(event.reason),
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "metadata" => event.metadata || %{}
      }
    end

    @impl true
    def from_map(data) do
      %__MODULE__{
        game_id: data["game_id"],
        guild_id: data["guild_id"],
        reason: String.to_existing_atom(data["reason"]),
        timestamp: EventStructure.parse_timestamp(data["timestamp"]),
        metadata: data["metadata"] || %{}
      }
    end

    def new(game_id, guild_id, reason) do
      %__MODULE__{
        game_id: game_id,
        guild_id: guild_id,
        reason: reason,
        timestamp: DateTime.utc_now(),
        metadata: %{}
      }
    end
  end
end
