defmodule GameBot.Domain.Events.GuessEvents do
  @moduledoc """
  Defines guess-related events in the domain.
  """

  alias GameBot.Domain.Events.{Metadata, EventStructure, GameEvents, ValidationHelpers}

  defmodule GuessProcessed do
    @moduledoc """
    Emitted when a guess has been processed.

    Base fields:
    - game_id: Unique identifier for the game
    - guild_id: Discord guild ID where the guess was made
    - mode: Game mode (e.g., :word_match)
    - round_number: Current round number
    - timestamp: When the guess was processed
    - metadata: Additional context about the event

    Event-specific fields:
    - team_id: Unique identifier for the team
    - player1_id: ID of the first player
    - player2_id: ID of the second player
    - player1_word: Word provided by player 1
    - player2_word: Word provided by player 2
    - guess_successful: Whether the guess was successful
    - match_score: Current match score
    - guess_count: Number of guesses in this match
    - round_guess_count: Number of guesses in this round
    - total_guesses: Total number of guesses across all rounds
    - guess_duration: Duration of the guess in milliseconds
    - player1_duration: Time taken by player 1 to provide their word
    - player2_duration: Time taken by player 2 to provide their word
    """
    use GameBot.Domain.Events.BaseEvent,
      event_type: "guess_processed",
      version: 1,
      fields: [
        field(:team_id, :string),
        field(:player1_id, :string),
        field(:player2_id, :string),
        field(:player1_word, :string),
        field(:player2_word, :string),
        field(:guess_successful, :boolean),
        field(:match_score, :integer),
        field(:guess_count, :integer),
        field(:round_guess_count, :integer),
        field(:total_guesses, :integer),
        field(:guess_duration, :integer),
        field(:player1_duration, :integer),
        field(:player2_duration, :integer)
      ]

    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      # Base fields (from BaseEvent)
      id: Ecto.UUID.t(),
      game_id: String.t(),
      guild_id: String.t(),
      mode: atom(),
      round_number: integer(),
      timestamp: DateTime.t(),
      metadata: Metadata.t(),
      type: String.t(),
      version: pos_integer(),

      # Custom fields
      team_id: String.t(),
      player1_id: String.t(),
      player2_id: String.t(),
      player1_word: String.t(),
      player2_word: String.t(),
      guess_successful: boolean(),
      match_score: integer(),
      guess_count: integer(),
      round_guess_count: integer(),
      total_guesses: integer(),
      guess_duration: integer(),
      player1_duration: integer(),
      player2_duration: integer(),

      # Ecto timestamps
      inserted_at: DateTime.t() | nil,
      updated_at: DateTime.t() | nil
    }

    @doc """
    Returns the list of required fields for this event.
    """
    @spec required_fields() :: [atom()]
    def required_fields do
      [
        :game_id, :guild_id, :mode, :round_number, :team_id,
        :player1_id, :player2_id, :player1_word, :player2_word,
        :guess_successful, :match_score, :guess_count, :round_guess_count,
        :total_guesses, :guess_duration, :player1_duration, :player2_duration,
        :metadata
      ]
    end

    @doc """
    Validates custom fields specific to this event.
    """
    @spec validate_custom_fields(Ecto.Changeset.t()) :: Ecto.Changeset.t()
    def validate_custom_fields(changeset) do
      super(changeset)
      |> validate_required([
        :team_id, :player1_id, :player2_id, :player1_word, :player2_word,
        :guess_successful, :match_score, :guess_count, :round_guess_count,
        :total_guesses, :guess_duration, :player1_duration, :player2_duration
      ])
    end

    @doc """
    Validates the event.

    Implements the GameEvents.validate/1 callback.
    """
    @impl GameEvents
    @spec validate(map()) :: :ok | {:error, String.t()}
    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event),
           :ok <- validate_team_id(event.team_id),
           :ok <- validate_string_value(event.player1_id),
           :ok <- validate_string_value(event.player2_id),
           :ok <- validate_word(event.player1_word, "player1_word"),
           :ok <- validate_word(event.player2_word, "player2_word"),
           :ok <- validate_non_negative(event.match_score, "match_score"),
           :ok <- validate_non_negative(event.guess_count, "guess_count"),
           :ok <- validate_non_negative(event.round_guess_count, "round_guess_count"),
           :ok <- validate_non_negative(event.total_guesses, "total_guesses"),
           :ok <- validate_non_negative(event.guess_duration, "guess_duration"),
           :ok <- validate_non_negative(event.player1_duration, "player1_duration"),
           :ok <- validate_non_negative(event.player2_duration, "player2_duration") do
        :ok
      end
    end

    @doc """
    Converts the event to a map for storage.
    """
    @impl true
    def to_map(%__MODULE__{} = event) do
      %{
        "team_id" => event.team_id,
        "player1_id" => event.player1_id,
        "player2_id" => event.player2_id,
        "player1_word" => event.player1_word,
        "player2_word" => event.player2_word,
        "guess_successful" => event.guess_successful,
        "match_score" => event.match_score,
        "guess_count" => event.guess_count,
        "round_guess_count" => event.round_guess_count,
        "total_guesses" => event.total_guesses,
        "guess_duration" => event.guess_duration,
        "player1_duration" => event.player1_duration,
        "player2_duration" => event.player2_duration,
        "game_id" => event.game_id,
        "guild_id" => event.guild_id,
        "mode" => to_string(event.mode),
        "round_number" => event.round_number,
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "metadata" => event.metadata || %{}
      }
    end

    @doc """
    Creates an event struct from a map.
    """
    @impl true
    def from_map(data) do
      mode = if is_binary(data["mode"]), do: String.to_existing_atom(data["mode"]), else: data["mode"]

      %__MODULE__{
        team_id: data["team_id"],
        player1_id: data["player1_id"],
        player2_id: data["player2_id"],
        player1_word: data["player1_word"],
        player2_word: data["player2_word"],
        guess_successful: data["guess_successful"],
        match_score: data["match_score"],
        guess_count: data["guess_count"],
        round_guess_count: data["round_guess_count"],
        total_guesses: data["total_guesses"],
        guess_duration: data["guess_duration"],
        player1_duration: data["player1_duration"],
        player2_duration: data["player2_duration"],
        metadata: data["metadata"] || %{},
        game_id: data["game_id"],
        guild_id: data["guild_id"],
        mode: mode,
        round_number: data["round_number"],
        timestamp:
          case DateTime.from_iso8601(data["timestamp"]) do
            {:ok, datetime, _} -> datetime
            {:error, _} -> GameEvents.parse_timestamp(data["timestamp"])
          end,
        type: "guess_processed",
        version: 1
      }
    end

    @doc """
    Creates a new GuessProcessed event.

    ## Parameters
      * `team_id` - Unique identifier for the team
      * `player1_id` - ID of the first player
      * `player2_id` - ID of the second player
      * `player1_word` - Word provided by player 1
      * `player2_word` - Word provided by player 2
      * `guess_successful` - Whether the guess was successful
      * `match_score` - Current match score
      * `guess_count` - Number of guesses in this match
      * `round_guess_count` - Number of guesses in this round
      * `total_guesses` - Total number of guesses across all rounds
      * `guess_duration` - Duration of the guess in milliseconds
      * `player1_duration` - Time taken by player 1 to provide their word
      * `player2_duration` - Time taken by player 2 to provide their word
      * `game_id` - Unique identifier for the game
      * `guild_id` - Discord guild ID where the guess was made
      * `mode` - Game mode (e.g., :word_match)
      * `round_number` - Current round number
      * `metadata` - Additional metadata for the event (optional)

    ## Returns
      * `{:ok, %GuessProcessed{}}` - A new GuessProcessed event struct
      * `{:error, reason}` - If validation fails
    """
    @spec new(
      String.t(),
      String.t(),
      String.t(),
      String.t(),
      String.t(),
      boolean(),
      integer(),
      integer(),
      integer(),
      integer(),
      integer(),
      integer(),
      integer(),
      String.t(),
      String.t(),
      atom(),
      integer(),
      map()
    ) :: {:ok, %__MODULE__{}} | {:error, String.t()}
    def new(
      team_id,
      player1_id,
      player2_id,
      player1_word,
      player2_word,
      guess_successful,
      match_score,
      guess_count,
      round_guess_count,
      total_guesses,
      guess_duration,
      player1_duration,
      player2_duration,
      game_id,
      guild_id,
      mode,
      round_number,
      metadata \\ %{}
    ) do
      event = %__MODULE__{
        team_id: team_id,
        player1_id: player1_id,
        player2_id: player2_id,
        player1_word: player1_word,
        player2_word: player2_word,
        guess_successful: guess_successful,
        match_score: match_score,
        guess_count: guess_count,
        round_guess_count: round_guess_count,
        total_guesses: total_guesses,
        guess_duration: guess_duration,
        player1_duration: player1_duration,
        player2_duration: player2_duration,
        game_id: game_id,
        guild_id: guild_id,
        mode: mode,
        round_number: round_number,
        timestamp: DateTime.utc_now(),
        metadata: metadata,
        type: "guess_processed",
        version: 1
      }

      case validate(event) do
        :ok -> {:ok, event}
        error -> error
      end
    end

    # Private validation functions

    @spec validate_team_id(String.t() | nil) :: :ok | {:error, String.t()}
    defp validate_team_id(nil), do: {:error, "team_id is required"}
    defp validate_team_id(id) when is_binary(id) and byte_size(id) > 0, do: :ok
    defp validate_team_id(_), do: {:error, "team_id must be a non-empty string"}

    @spec validate_string_value(String.t() | nil) :: :ok | {:error, String.t()}
    defp validate_string_value(nil), do: :ok
    defp validate_string_value(value) when is_binary(value), do: :ok
    defp validate_string_value(_), do: {:error, "must be a string"}

    @spec validate_word(String.t() | nil, String.t()) :: :ok | {:error, String.t()}
    defp validate_word(nil, field), do: {:error, "#{field} is required"}
    defp validate_word(word, _field) when is_binary(word), do: :ok
    defp validate_word(_, field), do: {:error, "#{field} must be a string"}

    @spec validate_non_negative(integer() | nil, String.t()) :: :ok | {:error, String.t()}
    defp validate_non_negative(nil, field), do: {:error, "#{field} is required"}
    defp validate_non_negative(value, _field) when is_integer(value) and value >= 0, do: :ok
    defp validate_non_negative(_, field), do: {:error, "#{field} must be a non-negative integer"}
  end

  defmodule GuessStarted do
    @moduledoc """
    Emitted when a player starts a guess.

    Base fields:
    - game_id: Unique identifier for the game
    - guild_id: Discord guild ID where the guess is being made
    - mode: Game mode (e.g., :word_match)
    - round_number: Current round number
    - timestamp: When the guess was started
    - metadata: Additional context about the event

    Event-specific fields:
    - team_id: Unique identifier for the team
    - player_id: ID of the player starting the guess
    - channel_id: Discord channel ID where the guess is being made
    """
    use GameBot.Domain.Events.BaseEvent,
      event_type: "guess_started",
      version: 1,
      fields: [
        field(:team_id, :string),
        field(:player_id, :string),
        field(:channel_id, :string)
      ]

    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      # Base fields (from BaseEvent)
      id: Ecto.UUID.t(),
      game_id: String.t(),
      guild_id: String.t(),
      mode: atom(),
      round_number: integer(),
      timestamp: DateTime.t(),
      metadata: Metadata.t(),
      type: String.t(),
      version: pos_integer(),

      # Custom fields
      team_id: String.t(),
      player_id: String.t(),
      channel_id: String.t(),

      # Ecto timestamps
      inserted_at: DateTime.t() | nil,
      updated_at: DateTime.t() | nil
    }

    @doc """
    Returns the list of required fields for this event.
    """
    @spec required_fields() :: [atom()]
    def required_fields do
      [:game_id, :guild_id, :mode, :round_number, :team_id, :player_id, :channel_id, :metadata]
    end

    @doc """
    Validates custom fields specific to this event.
    """
    @spec validate_custom_fields(Ecto.Changeset.t()) :: Ecto.Changeset.t()
    def validate_custom_fields(changeset) do
      super(changeset)
      |> validate_required([:team_id, :player_id, :channel_id])
    end

    @doc """
    Validates the event.

    Implements the GameEvents.validate/1 callback.
    """
    @impl GameEvents
    @spec validate(map()) :: :ok | {:error, String.t()}
    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event),
           :ok <- ValidationHelpers.validate_string_value(event.team_id),
           :ok <- ValidationHelpers.validate_string_value(event.player_id),
           :ok <- ValidationHelpers.validate_string_value(event.channel_id) do
        :ok
      end
    end

    @doc """
    Converts the event to a map for serialization.

    Implements the GameEvents.to_map/1 callback.
    """
    @impl GameEvents
    @spec to_map(t()) :: map()
    def to_map(%__MODULE__{} = event) do
      %{
        "team_id" => event.team_id,
        "player_id" => event.player_id,
        "channel_id" => event.channel_id,
        "metadata" => event.metadata || %{},
        "game_id" => event.game_id,
        "guild_id" => event.guild_id,
        "mode" => to_string(event.mode),
        "round_number" => event.round_number
      }
    end

    @doc """
    Creates an event from a serialized map.

    Implements the GameEvents.from_map/1 callback.
    """
    @impl GameEvents
    @spec from_map(map()) :: %__MODULE__{}
    def from_map(data) do
      mode = if is_binary(data["mode"]), do: String.to_existing_atom(data["mode"]), else: data["mode"]

      %__MODULE__{
        team_id: data["team_id"],
        player_id: data["player_id"],
        channel_id: data["channel_id"],
        metadata: data["metadata"] || %{},
        game_id: data["game_id"],
        guild_id: data["guild_id"],
        mode: mode,
        round_number: data["round_number"],
        timestamp:
          case DateTime.from_iso8601(data["timestamp"]) do
            {:ok, datetime, _} -> datetime
            {:error, _} -> GameEvents.parse_timestamp(data["timestamp"])
          end,
        type: "guess_started",
        version: 1
      }
    end

    @doc """
    Creates a new GuessStarted event.

    ## Parameters
      * `team_id` - Unique identifier for the team
      * `player_id` - ID of the player starting the guess
      * `channel_id` - Discord channel ID where the guess is being made
      * `game_id` - Unique identifier for the game
      * `guild_id` - Discord guild ID where the guess is being made
      * `mode` - Game mode (e.g., :word_match)
      * `round_number` - Current round number
      * `metadata` - Additional metadata for the event (optional)

    ## Returns
      * `{:ok, %GuessStarted{}}` - A new GuessStarted event struct
      * `{:error, reason}` - If validation fails
    """
    @spec new(
      String.t(),
      String.t(),
      String.t(),
      String.t(),
      String.t(),
      atom(),
      integer(),
      map()
    ) :: {:ok, %__MODULE__{}} | {:error, String.t()}
    def new(
      team_id,
      player_id,
      channel_id,
      game_id,
      guild_id,
      mode,
      round_number,
      metadata \\ %{}
    ) do
      now = DateTime.utc_now()

      # Ensure metadata has required fields
      enhanced_metadata = ValidationHelpers.ensure_metadata_fields(metadata, guild_id)

      attrs = %{
        team_id: team_id,
        player_id: player_id,
        channel_id: channel_id,
        game_id: game_id,
        guild_id: guild_id,
        mode: mode,
        round_number: round_number,
        timestamp: now,
        metadata: enhanced_metadata
      }

      # Create and validate the event
      event = struct!(__MODULE__, attrs)

      case validate(event) do
        :ok -> {:ok, event}
        error -> error
      end
    end
  end

  defmodule GuessAbandoned do
    @moduledoc """
    Emitted when a guess is abandoned.

    Base fields:
    - game_id: Unique identifier for the game
    - guild_id: Discord guild ID where the guess was made
    - mode: Game mode (e.g., :word_match)
    - round_number: Current round number
    - timestamp: When the guess was abandoned
    - metadata: Additional context about the event

    Event-specific fields:
    - team_id: Unique identifier for the team
    - player1_id: ID of the first player
    - player2_id: ID of the second player
    - reason: Reason for the abandonment
    - abandoning_player_id: ID of the player abandoning the guess
    - last_guess: Last guess information
    - guess_count: Number of guesses in this match
    - round_guess_count: Number of guesses in this round
    - total_guesses: Total number of guesses across all rounds
    - guess_duration: Duration of the guess in milliseconds
    """
    use GameBot.Domain.Events.BaseEvent,
      event_type: "guess_abandoned",
      version: 1,
      fields: [
        field(:team_id, :string),
        field(:player1_id, :string),
        field(:player2_id, :string),
        field(:reason, Ecto.Enum, values: [:timeout, :player_quit, :disconnected]),
        field(:abandoning_player_id, :string),
        field(:last_guess, :map),
        field(:guess_count, :integer),
        field(:round_guess_count, :integer),
        field(:total_guesses, :integer),
        field(:guess_duration, :integer)
      ]

    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      # Base fields (from BaseEvent)
      id: Ecto.UUID.t(),
      game_id: String.t(),
      guild_id: String.t(),
      mode: atom(),
      round_number: integer(),
      timestamp: DateTime.t(),
      metadata: Metadata.t(),
      type: String.t(),
      version: pos_integer(),

      # Custom fields
      team_id: String.t(),
      player1_id: String.t(),
      player2_id: String.t(),
      reason: :timeout | :player_quit | :disconnected,
      abandoning_player_id: String.t(),
      last_guess: map() | nil,
      guess_count: integer(),
      round_guess_count: integer(),
      total_guesses: integer(),
      guess_duration: integer() | nil,

      # Ecto timestamps
      inserted_at: DateTime.t() | nil,
      updated_at: DateTime.t() | nil
    }

    @doc """
    Returns the list of required fields for this event.
    """
    @spec required_fields() :: [atom()]
    def required_fields do
      [:game_id, :guild_id, :mode, :round_number, :team_id, :player1_id, :player2_id, :reason, :abandoning_player_id, :last_guess, :guess_count, :round_guess_count, :total_guesses, :guess_duration, :metadata]
    end

    @doc """
    Validates custom fields specific to this event.
    """
    @spec validate_custom_fields(Ecto.Changeset.t()) :: Ecto.Changeset.t()
    def validate_custom_fields(changeset) do
      super(changeset)
      |> validate_required([:team_id, :player1_id, :player2_id, :reason, :abandoning_player_id, :last_guess, :guess_count, :round_guess_count, :total_guesses, :guess_duration])
    end

    @doc """
    Validates the event.

    Implements the GameEvents.validate/1 callback.
    """
    @impl GameEvents
    @spec validate(map()) :: :ok | {:error, String.t()}
    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event),
           :ok <- validate_team_id(event.team_id),
           :ok <- ValidationHelpers.validate_string_value(event.player1_id),
           :ok <- ValidationHelpers.validate_string_value(event.player2_id),
           :ok <- validate_reason(event.reason),
           :ok <- ValidationHelpers.validate_string_value(event.abandoning_player_id),
           :ok <- validate_last_guess(event.last_guess),
           :ok <- ValidationHelpers.validate_non_negative(event.guess_count, "guess_count"),
           :ok <- ValidationHelpers.validate_non_negative(event.round_guess_count, "round_guess_count"),
           :ok <- ValidationHelpers.validate_non_negative(event.total_guesses, "total_guesses"),
           :ok <- ValidationHelpers.validate_non_negative(event.guess_duration, "guess_duration") do
        :ok
      end
    end

    @doc """
    Converts the event to a map for serialization.

    Implements the GameEvents.to_map/1 callback.
    """
    @impl GameEvents
    @spec to_map(t()) :: map()
    def to_map(%__MODULE__{} = event) do
      %{
        "team_id" => event.team_id,
        "player1_id" => event.player1_id,
        "player2_id" => event.player2_id,
        "reason" => event.reason,
        "abandoning_player_id" => event.abandoning_player_id,
        "last_guess" => event.last_guess,
        "guess_count" => event.guess_count,
        "round_guess_count" => event.round_guess_count,
        "total_guesses" => event.total_guesses,
        "guess_duration" => event.guess_duration,
        "metadata" => event.metadata || %{},
        "game_id" => event.game_id,
        "guild_id" => event.guild_id,
        "mode" => to_string(event.mode),
        "round_number" => event.round_number
      }
    end

    @doc """
    Creates an event from a serialized map.

    Implements the GameEvents.from_map/1 callback.
    """
    @impl GameEvents
    @spec from_map(map()) :: %__MODULE__{}
    def from_map(data) do
      mode = if is_binary(data["mode"]), do: String.to_existing_atom(data["mode"]), else: data["mode"]

      %__MODULE__{
        team_id: data["team_id"],
        player1_id: data["player1_id"],
        player2_id: data["player2_id"],
        reason: data["reason"],
        abandoning_player_id: data["abandoning_player_id"],
        last_guess: data["last_guess"],
        guess_count: data["guess_count"],
        round_guess_count: data["round_guess_count"],
        total_guesses: data["total_guesses"],
        guess_duration: data["guess_duration"],
        metadata: data["metadata"] || %{},
        game_id: data["game_id"],
        guild_id: data["guild_id"],
        mode: mode,
        round_number: data["round_number"],
        timestamp:
          case DateTime.from_iso8601(data["timestamp"]) do
            {:ok, datetime, _} -> datetime
            {:error, _} -> GameEvents.parse_timestamp(data["timestamp"])
          end,
        type: "guess_abandoned",
        version: 1
      }
    end

    @doc """
    Creates a new GuessAbandoned event.

    ## Parameters
      * `team_id` - Unique identifier for the team
      * `player1_id` - ID of the first player
      * `player2_id` - ID of the second player
      * `reason` - Reason for the abandonment
      * `abandoning_player_id` - ID of the player abandoning the guess
      * `last_guess` - Last guess information
      * `guess_count` - Number of guesses in this match
      * `round_guess_count` - Number of guesses in this round
      * `total_guesses` - Total number of guesses across all rounds
      * `guess_duration` - Duration of the guess in milliseconds
      * `game_id` - Unique identifier for the game
      * `guild_id` - Discord guild ID where the guess was made
      * `mode` - Game mode (e.g., :word_match)
      * `round_number` - Current round number
      * `metadata` - Additional metadata for the event (optional)

    ## Returns
      * `{:ok, %GuessAbandoned{}}` - A new GuessAbandoned event struct
      * `{:error, reason}` - If validation fails
    """
    @spec new(
      String.t(),
      String.t(),
      String.t(),
      atom(),
      String.t(),
      map() | nil,
      non_neg_integer(),
      non_neg_integer(),
      non_neg_integer(),
      non_neg_integer() | nil,
      String.t(),
      String.t(),
      atom(),
      pos_integer(),
      map()
    ) :: {:ok, %__MODULE__{}} | {:error, String.t()}
    def new(
      team_id,
      player1_id,
      player2_id,
      reason,
      abandoning_player_id,
      last_guess,
      guess_count,
      round_guess_count,
      total_guesses,
      guess_duration,
      game_id,
      guild_id,
      mode,
      round_number,
      metadata \\ %{}
    ) do
      event = %__MODULE__{
        team_id: team_id,
        player1_id: player1_id,
        player2_id: player2_id,
        reason: reason,
        abandoning_player_id: abandoning_player_id,
        last_guess: last_guess,
        guess_count: guess_count,
        round_guess_count: round_guess_count,
        total_guesses: total_guesses,
        guess_duration: guess_duration,
        game_id: game_id,
        guild_id: guild_id,
        mode: mode,
        round_number: round_number,
        timestamp: DateTime.utc_now(),
        metadata: metadata,
        type: "guess_abandoned",
        version: 1
      }

      case validate(event) do
        :ok -> {:ok, event}
        error -> error
      end
    end

    # Private validation functions

    @spec validate_team_id(String.t() | nil) :: :ok | {:error, String.t()}
    defp validate_team_id(nil), do: {:error, "team_id is required"}
    defp validate_team_id(id) when is_binary(id) and byte_size(id) > 0, do: :ok
    defp validate_team_id(_), do: {:error, "team_id must be a non-empty string"}

    @spec validate_reason(atom() | nil) :: :ok | {:error, String.t()}
    defp validate_reason(nil), do: {:error, "reason is required"}
    defp validate_reason(reason) when reason in [:timeout, :player_quit, :disconnected], do: :ok
    defp validate_reason(_), do: {:error, "invalid reason"}

    @spec validate_last_guess(map() | nil) :: :ok | {:error, String.t()}
    defp validate_last_guess(nil), do: :ok
    defp validate_last_guess(guess) when is_map(guess), do: :ok
    defp validate_last_guess(_), do: {:error, "invalid last_guess format"}
  end
end
