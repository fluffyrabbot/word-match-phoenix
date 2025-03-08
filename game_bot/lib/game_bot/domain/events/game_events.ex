defmodule GameBot.Domain.Events.GameEvents do
  @moduledoc """
  Defines all events used in the game system.
  Events are immutable records of things that have happened in the system.
  """

  alias GameBot.Domain.Events.{Metadata, EventStructure}

  @type metadata :: Metadata.t()
  @type team_info :: EventStructure.team_info()
  @type player_info :: EventStructure.player_info()

  @doc """
  The Event behaviour ensures all events can be properly stored and loaded.

  Required callbacks:
  - event_type(): Returns a string identifier for the event (e.g. "game_started")
  - event_version(): Returns the version number of the event schema
  - to_map(event): Converts the event struct to a simple map for storage
  - from_map(data): Creates an event struct from stored map data
  - validate(event): Validates the event data
  """
  @callback event_type() :: String.t()
  @callback event_version() :: pos_integer()
  @callback to_map(struct()) :: map()
  @callback from_map(map()) :: struct()
  @callback validate(struct()) :: :ok | {:error, term()}

  # Base fields that should be included in all events
  @base_fields EventStructure.base_fields()

  @doc """
  Converts any event to a storable format with metadata.
  """
  def serialize(event) do
    module = event.__struct__

    # Validate event before serialization
    case module.validate(event) do
      :ok ->
        %{
          "event_type" => module.event_type(),
          "event_version" => module.event_version(),
          "data" => module.to_map(event),
          "stored_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        }
      {:error, reason} ->
        raise "Invalid event: #{inspect(reason)}"
    end
  end

  @doc """
  Reconstructs an event from stored data.
  """
  def deserialize(%{"event_type" => type, "data" => data}) do
    # Find the appropriate module for this event type
    module = get_event_module(type)

    # Deserialize using the module's from_map function
    module.from_map(data)
  end

  @doc """
  Parses a timestamp string into a DateTime struct.
  """
  def parse_timestamp(timestamp) do
    EventStructure.parse_timestamp(timestamp)
  end

  @doc """
  Standard validation function that all events can use.
  Checks base fields and event-specific validation.
  """
  def validate_event(event) do
    EventStructure.validate(event)
  end

  # Private helpers

  # Maps event type strings to their module implementations
  defp get_event_module(type) do
    case type do
      "game_created" -> GameBot.Domain.Events.GameEvents.GameCreated
      "game_started" -> GameBot.Domain.Events.GameEvents.GameStarted
      "game_completed" -> GameBot.Domain.Events.GameEvents.GameCompleted
      "round_started" -> GameBot.Domain.Events.GameEvents.RoundStarted
      "guess_processed" -> GameBot.Domain.Events.GameEvents.GuessProcessed
      "guess_abandoned" -> GameBot.Domain.Events.GameEvents.GuessAbandoned
      "team_eliminated" -> GameBot.Domain.Events.GameEvents.TeamEliminated
      _ -> raise "Unknown event type: #{type}"
    end
  end

  # Game lifecycle events
  defmodule GameStarted do
    @moduledoc "Emitted when a new game is started"
    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      game_id: String.t(),
      guild_id: String.t(),
      mode: atom(),
      round_number: pos_integer(),           # Always 1 for game start
      teams: %{String.t() => [String.t()]},  # team_id => [player_ids]
      team_ids: [String.t()],                # Ordered list of team IDs
      player_ids: [String.t()],              # Ordered list of all player IDs
      roles: %{String.t() => atom()},        # player_id => role mapping
      config: map(),                         # Mode-specific configuration
      started_at: DateTime.t(),              # Added missing field
      timestamp: DateTime.t(),
      metadata: GameBot.Domain.Events.GameEvents.metadata()
    }
    defstruct [:game_id, :guild_id, :mode, :round_number, :teams, :team_ids, :player_ids, :roles, :config, :started_at, :timestamp, :metadata]

    def event_type(), do: "game_started"
    def event_version(), do: 1

    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event) do
        cond do
          is_nil(event.teams) -> {:error, "teams is required"}
          is_nil(event.team_ids) -> {:error, "team_ids is required"}
          is_nil(event.player_ids) -> {:error, "player_ids is required"}
          Enum.empty?(event.team_ids) -> {:error, "team_ids cannot be empty"}
          Enum.empty?(event.player_ids) -> {:error, "player_ids cannot be empty"}
          !Enum.all?(Map.keys(event.teams), &(&1 in event.team_ids)) -> {:error, "invalid team_id in teams map"}
          !Enum.all?(List.flatten(Map.values(event.teams)), &(&1 in event.player_ids)) -> {:error, "invalid player_id in teams"}
          true -> :ok
        end
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "game_id" => event.game_id,
        "guild_id" => event.guild_id,
        "mode" => Atom.to_string(event.mode),
        "round_number" => 1,
        "teams" => event.teams,
        "team_ids" => event.team_ids,
        "player_ids" => event.player_ids,
        "roles" => Map.new(event.roles, fn {k, v} -> {k, Atom.to_string(v)} end),
        "config" => event.config,
        "started_at" => DateTime.to_iso8601(event.started_at),
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        game_id: data["game_id"],
        guild_id: data["guild_id"],
        mode: String.to_existing_atom(data["mode"]),
        round_number: 1,
        teams: data["teams"],
        team_ids: data["team_ids"],
        player_ids: data["player_ids"],
        roles: Map.new(data["roles"] || %{}, fn {k, v} -> {k, String.to_existing_atom(v)} end),
        config: data["config"],
        started_at: GameBot.Domain.Events.GameEvents.parse_timestamp(data["started_at"]),
        timestamp: GameBot.Domain.Events.GameEvents.parse_timestamp(data["timestamp"]),
        metadata: data["metadata"] || %{}
      }
    end
  end

  defmodule RoundStarted do
    @moduledoc "Emitted when a new round begins"
    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      game_id: String.t(),
      guild_id: String.t(),  # Added missing field
      mode: atom(),
      round_number: pos_integer(),
      team_states: map(),                    # Initial team states for round
      timestamp: DateTime.t(),
      metadata: GameBot.Domain.Events.GameEvents.metadata()
    }
    defstruct [:game_id, :guild_id, :mode, :round_number, :team_states, :timestamp, :metadata]

    def event_type(), do: "round_started"
    def event_version(), do: 1

    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event) do
        cond do
          is_nil(event.team_states) -> {:error, "team_states is required"}
          true -> :ok
        end
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "game_id" => event.game_id,
        "guild_id" => event.guild_id,
        "mode" => Atom.to_string(event.mode),
        "round_number" => event.round_number,
        "team_states" => event.team_states,
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        game_id: data["game_id"],
        guild_id: data["guild_id"],
        mode: String.to_existing_atom(data["mode"]),
        round_number: data["round_number"],
        team_states: data["team_states"],
        timestamp: GameBot.Domain.Events.GameEvents.parse_timestamp(data["timestamp"]),
        metadata: data["metadata"] || %{}
      }
    end
  end

  # Gameplay Events
  defmodule GuessProcessed do
    @moduledoc "Emitted when both players have submitted their guesses and the attempt is processed"
    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      game_id: String.t(),
      guild_id: String.t(),
      mode: atom(),
      round_number: pos_integer(),
      team_id: String.t(),
      player1_info: GameBot.Domain.Events.GameEvents.player_info(),
      player2_info: GameBot.Domain.Events.GameEvents.player_info(),
      player1_word: String.t(),
      player2_word: String.t(),
      guess_successful: boolean(),
      guess_count: pos_integer(),
      match_score: integer(),
      round_guess_count: pos_integer(),
      total_guesses: pos_integer(),
      guess_duration: integer(),
      timestamp: DateTime.t(),
      metadata: GameBot.Domain.Events.GameEvents.metadata()
    }
    defstruct [:game_id, :guild_id, :mode, :round_number, :team_id, :player1_info, :player2_info,
               :player1_word, :player2_word, :guess_successful, :guess_count, :match_score,
               :round_guess_count, :total_guesses, :guess_duration, :timestamp, :metadata]

    def event_type(), do: "guess_processed"
    def event_version(), do: 1

    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event) do
        cond do
          is_nil(event.team_id) -> {:error, "team_id is required"}
          is_nil(event.player1_info) -> {:error, "player1_info is required"}
          is_nil(event.player2_info) -> {:error, "player2_info is required"}
          is_nil(event.player1_word) -> {:error, "player1_word is required"}
          is_nil(event.player2_word) -> {:error, "player2_word is required"}
          is_nil(event.guess_count) -> {:error, "guess_count is required"}
          event.guess_count < 1 -> {:error, "guess_count must be positive"}
          true -> :ok
        end
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "game_id" => event.game_id,
        "guild_id" => event.guild_id,
        "mode" => Atom.to_string(event.mode),
        "round_number" => event.round_number,
        "team_id" => event.team_id,
        "player1_info" => event.player1_info,
        "player2_info" => event.player2_info,
        "player1_word" => event.player1_word,
        "player2_word" => event.player2_word,
        "guess_successful" => event.guess_successful,
        "guess_count" => event.guess_count,
        "match_score" => event.match_score,
        "round_guess_count" => event.round_guess_count,
        "total_guesses" => event.total_guesses,
        "guess_duration" => event.guess_duration,
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        game_id: data["game_id"],
        guild_id: data["guild_id"],
        mode: String.to_existing_atom(data["mode"]),
        round_number: data["round_number"],
        team_id: data["team_id"],
        player1_info: data["player1_info"],
        player2_info: data["player2_info"],
        player1_word: data["player1_word"],
        player2_word: data["player2_word"],
        guess_successful: data["guess_successful"],
        guess_count: data["guess_count"],
        match_score: data["match_score"],
        round_guess_count: data["round_guess_count"],
        total_guesses: data["total_guesses"],
        guess_duration: data["guess_duration"],
        timestamp: GameBot.Domain.Events.GameEvents.parse_timestamp(data["timestamp"]),
        metadata: data["metadata"] || %{}
      }
    end
  end

  defmodule GuessAbandoned do
    @moduledoc "Emitted when a guess attempt is abandoned due to timeout or player giving up"
    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      game_id: String.t(),
      guild_id: String.t(),
      mode: atom(),
      round_number: pos_integer(),
      team_id: String.t(),
      player1_info: GameBot.Domain.Events.GameEvents.player_info(),
      player2_info: GameBot.Domain.Events.GameEvents.player_info(),
      reason: :timeout | :player_quit | :disconnected,
      abandoning_player_id: String.t(),
      last_guess: %{
        player_id: String.t(),
        word: String.t(),
        timestamp: DateTime.t()
      } | nil,
      guess_count: pos_integer(),
      round_guess_count: pos_integer(),
      total_guesses: pos_integer(),
      guess_duration: integer() | nil,
      timestamp: DateTime.t(),
      metadata: GameBot.Domain.Events.GameEvents.metadata()
    }
    defstruct [:game_id, :guild_id, :mode, :round_number, :team_id, :player1_info, :player2_info,
               :reason, :abandoning_player_id, :last_guess, :guess_count, :round_guess_count,
               :total_guesses, :guess_duration, :timestamp, :metadata]

    def event_type(), do: "guess_abandoned"
    def event_version(), do: 1

    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event) do
        cond do
          is_nil(event.team_id) -> {:error, "team_id is required"}
          is_nil(event.player1_info) -> {:error, "player1_info is required"}
          is_nil(event.player2_info) -> {:error, "player2_info is required"}
          is_nil(event.reason) -> {:error, "reason is required"}
          is_nil(event.abandoning_player_id) -> {:error, "abandoning_player_id is required"}
          is_nil(event.guess_count) -> {:error, "guess_count is required"}
          event.guess_count < 1 -> {:error, "guess_count must be positive"}
          true -> :ok
        end
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "game_id" => event.game_id,
        "guild_id" => event.guild_id,
        "mode" => Atom.to_string(event.mode),
        "round_number" => event.round_number,
        "team_id" => event.team_id,
        "player1_info" => event.player1_info,
        "player2_info" => event.player2_info,
        "reason" => Atom.to_string(event.reason),
        "abandoning_player_id" => event.abandoning_player_id,
        "last_guess" => if(event.last_guess, do: Map.update!(event.last_guess, :timestamp, &DateTime.to_iso8601/1)),
        "guess_count" => event.guess_count,
        "round_guess_count" => event.round_guess_count,
        "total_guesses" => event.total_guesses,
        "guess_duration" => event.guess_duration,
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        game_id: data["game_id"],
        guild_id: data["guild_id"],
        mode: String.to_existing_atom(data["mode"]),
        round_number: data["round_number"],
        team_id: data["team_id"],
        player1_info: data["player1_info"],
        player2_info: data["player2_info"],
        reason: String.to_existing_atom(data["reason"]),
        abandoning_player_id: data["abandoning_player_id"],
        last_guess: if(data["last_guess"], do: Map.update!(data["last_guess"], "timestamp", &GameBot.Domain.Events.GameEvents.parse_timestamp/1)),
        guess_count: data["guess_count"],
        round_guess_count: data["round_guess_count"],
        total_guesses: data["total_guesses"],
        guess_duration: data["guess_duration"],
        timestamp: GameBot.Domain.Events.GameEvents.parse_timestamp(data["timestamp"]),
        metadata: data["metadata"] || %{}
      }
    end
  end

  defmodule TeamEliminated do
    @moduledoc "Emitted when a team is eliminated from the game"
    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      game_id: String.t(),
      mode: atom(),
      round_number: pos_integer(),
      team_id: String.t(),
      reason: :timeout | :max_guesses | :round_loss | :forfeit,
      final_state: GameBot.Domain.Events.GameEvents.team_info(),
      final_score: integer(),
      player_stats: %{String.t() => %{
        total_guesses: integer(),
        successful_matches: integer(),
        abandoned_guesses: integer(),
        average_guess_count: float()
      }},
      timestamp: DateTime.t(),
      metadata: GameBot.Domain.Events.GameEvents.metadata()
    }
    defstruct [:game_id, :mode, :round_number, :team_id, :reason, :final_state,
               :final_score, :player_stats, :timestamp, :metadata]

    def event_type(), do: "team_eliminated"
    def event_version(), do: 1

    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event) do
        cond do
          is_nil(event.team_id) -> {:error, "team_id is required"}
          is_nil(event.reason) -> {:error, "reason is required"}
          is_nil(event.final_state) -> {:error, "final_state is required"}
          is_nil(event.final_score) -> {:error, "final_score is required"}
          is_nil(event.player_stats) -> {:error, "player_stats is required"}
          true -> :ok
        end
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "game_id" => event.game_id,
        "mode" => Atom.to_string(event.mode),
        "round_number" => event.round_number,
        "team_id" => event.team_id,
        "reason" => Atom.to_string(event.reason),
        "final_state" => event.final_state,
        "final_score" => event.final_score,
        "player_stats" => event.player_stats,
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        game_id: data["game_id"],
        mode: String.to_existing_atom(data["mode"]),
        round_number: data["round_number"],
        team_id: data["team_id"],
        reason: String.to_existing_atom(data["reason"]),
        final_state: data["final_state"],
        final_score: data["final_score"],
        player_stats: data["player_stats"],
        timestamp: GameBot.Domain.Events.GameEvents.parse_timestamp(data["timestamp"]),
        metadata: data["metadata"] || %{}
      }
    end
  end

  defmodule GameCompleted do
    @moduledoc "Emitted when a game ends"
    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      game_id: String.t(),
      guild_id: String.t(),
      mode: atom(),
      round_number: pos_integer(),
      winners: [String.t()],
      final_scores: %{String.t() => %{
        score: integer(),
        matches: integer(),
        total_guesses: integer(),
        average_guesses: float(),
        player_stats: %{String.t() => %{
          total_guesses: integer(),
          successful_matches: integer(),
          abandoned_guesses: integer(),
          average_guess_count: float()
        }}
      }},
      game_duration: integer(),
      total_rounds: pos_integer(),
      timestamp: DateTime.t(),
      finished_at: DateTime.t(),
      metadata: GameBot.Domain.Events.GameEvents.metadata()
    }
    defstruct [:game_id, :guild_id, :mode, :round_number, :winners, :final_scores,
               :game_duration, :total_rounds, :timestamp, :finished_at, :metadata]

    @doc """
    Creates a new GameCompleted event with minimal parameters.

    This is a convenience function used primarily in the Session module's game_end handler.
    It takes the essential parameters needed to create a GameCompleted event and delegates
    to the full new/9 function with sensible defaults for the other parameters.

    ## Parameters
      * `game_id` - Unique identifier for the game
      * `guild_id` - Discord guild ID where the game was played
      * `mode` - Game mode (e.g., :two_player, :knockout)
      * `winners` - List of winning team IDs
      * `final_scores` - Map of team scores and statistics

    ## Returns
      * `%GameCompleted{}` - A new GameCompleted event struct

    ## Examples
        iex> GameCompleted.new(
        ...>   "game_123",
        ...>   "guild_456",
        ...>   :two_player,
        ...>   ["team_abc"],
        ...>   %{"team_abc" => %{score: 100, matches: 5, total_guesses: 20, average_guesses: 4.0,
        ...>     player_stats: %{"player1" => %{total_guesses: 10, successful_matches: 5,
        ...>     abandoned_guesses: 0, average_guess_count: 2.0}}}}
        ...> )
    """
    @spec new(String.t(), String.t(), atom(), [String.t()], map()) :: t()
    def new(game_id, guild_id, mode, winners, final_scores) do
      now = DateTime.utc_now()
      new(
        game_id,        # game_id
        guild_id,       # guild_id
        mode,          # mode
        1,             # round_number - using default since not provided
        winners,       # winners
        final_scores,  # final_scores
        0,            # game_duration - using default since not provided
        1,            # total_rounds - using default since not provided
        now,          # timestamp
        now           # finished_at
      )
    end

    @doc """
    Creates a new GameCompleted event with full parameters.

    This function creates a GameCompleted event with all possible parameters.
    It's used both directly and as a delegate from the simplified new/5 function.

    ## Parameters
      * `game_id` - Unique identifier for the game
      * `guild_id` - Discord guild ID where the game was played
      * `mode` - Game mode (e.g., :two_player, :knockout)
      * `round_number` - Final round number when the game ended
      * `winners` - List of winning team IDs
      * `final_scores` - Map of team scores and statistics
      * `game_duration` - Total duration of the game in seconds
      * `total_rounds` - Total number of rounds played
      * `timestamp` - When the event was created
      * `finished_at` - When the game actually finished
      * `metadata` - Additional metadata for the event (optional)

    ## Returns
      * `%GameCompleted{}` - A new GameCompleted event struct
    """
    @spec new(String.t(), String.t(), atom(), pos_integer(), [String.t()], map(), non_neg_integer(), pos_integer(), DateTime.t(), DateTime.t(), map()) :: t()
    def new(game_id, guild_id, mode, round_number, winners, final_scores, game_duration, total_rounds, timestamp, finished_at, metadata \\ %{}) do
      event = %__MODULE__{
        game_id: game_id,
        guild_id: guild_id,
        mode: mode,
        round_number: round_number,
        winners: winners,
        final_scores: final_scores,
        game_duration: game_duration,
        total_rounds: total_rounds,
        timestamp: timestamp,
        finished_at: finished_at,
        metadata: metadata
      }

      # Validate the event before returning
      case validate(event) do
        :ok -> event
        {:error, reason} -> raise "Invalid GameCompleted event: #{reason}"
      end
    end

    def event_type(), do: "game_completed"
    def event_version(), do: 1

    def validate(%__MODULE__{} = event) do
      with :ok <- validate_required(event, [:game_id, :guild_id, :mode, :round_number, :winners,
                                          :final_scores, :game_duration, :total_rounds,
                                          :timestamp, :finished_at, :metadata]),
           :ok <- validate_positive(event.total_rounds, "total_rounds"),
           :ok <- validate_non_negative(event.game_duration, "game_duration"),
           :ok <- validate_datetime(event.timestamp, "timestamp"),
           :ok <- validate_datetime(event.finished_at, "finished_at") do
        :ok
      end
    end

    defp validate_datetime(nil, field), do: {:error, "#{field} is required"}
    defp validate_datetime(%DateTime{}, _), do: :ok
    defp validate_datetime(_, field), do: {:error, "#{field} must be a DateTime"}

    defp validate_required(event, fields) do
      missing = Enum.filter(fields, &(is_nil(Map.get(event, &1))))
      if Enum.empty?(missing) do
        :ok
      else
        {:error, "Missing required fields: #{Enum.join(missing, ", ")}"}
      end
    end

    defp validate_positive(value, field) when is_integer(value) and value > 0, do: :ok
    defp validate_positive(_, field), do: {:error, "#{field} must be a positive integer"}

    defp validate_non_negative(value, field) when is_integer(value) and value >= 0, do: :ok
    defp validate_non_negative(_, field), do: {:error, "#{field} must be a non-negative integer"}

    def to_map(%__MODULE__{} = event) do
      %{
        "game_id" => event.game_id,
        "guild_id" => event.guild_id,
        "mode" => Atom.to_string(event.mode),
        "round_number" => event.round_number,
        "winners" => event.winners,
        "final_scores" => event.final_scores,
        "game_duration" => event.game_duration,
        "total_rounds" => event.total_rounds,
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "finished_at" => DateTime.to_iso8601(event.finished_at),
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        game_id: data["game_id"],
        guild_id: data["guild_id"],
        mode: String.to_existing_atom(data["mode"]),
        round_number: data["round_number"],
        winners: data["winners"],
        final_scores: data["final_scores"],
        game_duration: data["game_duration"],
        total_rounds: data["total_rounds"],
        timestamp: GameBot.Domain.Events.GameEvents.parse_timestamp(data["timestamp"]),
        finished_at: GameBot.Domain.Events.GameEvents.parse_timestamp(data["finished_at"]),
        metadata: data["metadata"] || %{}
      }
    end
  end

  # Mode-specific Events
  defmodule KnockoutRoundCompleted do
    @moduledoc "Emitted when a knockout round ends"
    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      game_id: String.t(),
      mode: atom(),
      round_number: pos_integer(),
      eliminated_teams: [%{
        team_id: String.t(),
        reason: :timeout | :max_guesses | :round_loss | :forfeit,
        final_score: integer(),
        player_stats: %{String.t() => map()}
      }],
      advancing_teams: [%{
        team_id: String.t(),
        score: integer(),
        matches: integer(),
        total_guesses: integer()
      }],
      round_duration: integer(),
      timestamp: DateTime.t(),
      metadata: GameBot.Domain.Events.GameEvents.metadata()
    }
    defstruct [:game_id, :mode, :round_number, :eliminated_teams, :advancing_teams,
               :round_duration, :timestamp, :metadata]

    def event_type(), do: "knockout_round_completed"
    def event_version(), do: 1

    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event) do
        cond do
          is_nil(event.eliminated_teams) -> {:error, "eliminated_teams is required"}
          is_nil(event.advancing_teams) -> {:error, "advancing_teams is required"}
          is_nil(event.round_duration) -> {:error, "round_duration is required"}
          event.round_duration < 0 -> {:error, "round_duration must be non-negative"}
          true -> :ok
        end
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "game_id" => event.game_id,
        "mode" => Atom.to_string(event.mode),
        "round_number" => event.round_number,
        "eliminated_teams" => event.eliminated_teams,
        "advancing_teams" => event.advancing_teams,
        "round_duration" => event.round_duration,
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        game_id: data["game_id"],
        mode: String.to_existing_atom(data["mode"]),
        round_number: data["round_number"],
        eliminated_teams: data["eliminated_teams"],
        advancing_teams: data["advancing_teams"],
        round_duration: data["round_duration"],
        timestamp: GameBot.Domain.Events.GameEvents.parse_timestamp(data["timestamp"]),
        metadata: data["metadata"] || %{}
      }
    end
  end

  defmodule RaceModeTimeExpired do
    @moduledoc "Emitted when time runs out in race mode"
    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      game_id: String.t(),
      mode: atom(),
      round_number: pos_integer(),
      final_matches: %{String.t() => %{
        matches: integer(),
        total_guesses: integer(),
        average_guesses: float(),
        last_match_timestamp: DateTime.t(),
        player_stats: %{String.t() => map()}
      }},
      game_duration: integer(),
      timestamp: DateTime.t(),
      metadata: GameBot.Domain.Events.GameEvents.metadata()
    }
    defstruct [:game_id, :mode, :round_number, :final_matches, :game_duration,
               :timestamp, :metadata]

    def event_type(), do: "race_mode_time_expired"
    def event_version(), do: 1

    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event) do
        cond do
          is_nil(event.final_matches) -> {:error, "final_matches is required"}
          is_nil(event.game_duration) -> {:error, "game_duration is required"}
          event.game_duration < 0 -> {:error, "game_duration must be non-negative"}
          true -> :ok
        end
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "game_id" => event.game_id,
        "mode" => Atom.to_string(event.mode),
        "round_number" => event.round_number,
        "final_matches" => Map.new(event.final_matches, fn {k, v} ->
          {k, Map.update!(v, :last_match_timestamp, &DateTime.to_iso8601/1)}
        end),
        "game_duration" => event.game_duration,
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        game_id: data["game_id"],
        mode: String.to_existing_atom(data["mode"]),
        round_number: data["round_number"],
        final_matches: Map.new(data["final_matches"], fn {k, v} ->
          {k, Map.update!(v, "last_match_timestamp", &GameBot.Domain.Events.GameEvents.parse_timestamp/1)}
        end),
        game_duration: data["game_duration"],
        timestamp: GameBot.Domain.Events.GameEvents.parse_timestamp(data["timestamp"]),
        metadata: data["metadata"] || %{}
      }
    end
  end

  defmodule LongformDayEnded do
    @moduledoc "Emitted when a day ends in longform mode"
    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      game_id: String.t(),
      mode: atom(),
      round_number: pos_integer(),
      day_number: pos_integer(),
      team_standings: %{String.t() => %{
        score: integer(),
        matches: integer(),
        total_guesses: integer(),
        average_guesses: float(),
        daily_matches: integer(),
        daily_guesses: integer(),
        player_stats: %{String.t() => map()}
      }},
      eliminated_teams: [String.t()],
      day_duration: integer(),
      timestamp: DateTime.t(),
      metadata: GameBot.Domain.Events.GameEvents.metadata()
    }
    defstruct [:game_id, :mode, :round_number, :day_number, :team_standings,
               :eliminated_teams, :day_duration, :timestamp, :metadata]

    def event_type(), do: "longform_day_ended"
    def event_version(), do: 1

    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event) do
        cond do
          is_nil(event.day_number) -> {:error, "day_number is required"}
          is_nil(event.team_standings) -> {:error, "team_standings is required"}
          is_nil(event.day_duration) -> {:error, "day_duration is required"}
          event.day_number < 1 -> {:error, "day_number must be positive"}
          event.day_duration < 0 -> {:error, "day_duration must be non-negative"}
          true -> :ok
        end
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "game_id" => event.game_id,
        "mode" => Atom.to_string(event.mode),
        "round_number" => event.round_number,
        "day_number" => event.day_number,
        "team_standings" => event.team_standings,
        "eliminated_teams" => event.eliminated_teams,
        "day_duration" => event.day_duration,
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        game_id: data["game_id"],
        mode: String.to_existing_atom(data["mode"]),
        round_number: data["round_number"],
        day_number: data["day_number"],
        team_standings: data["team_standings"],
        eliminated_teams: data["eliminated_teams"],
        day_duration: data["day_duration"],
        timestamp: GameBot.Domain.Events.GameEvents.parse_timestamp(data["timestamp"]),
        metadata: data["metadata"] || %{}
      }
    end
  end

  defmodule GameCreated do
    @moduledoc "Emitted when a new game is created"
    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      game_id: String.t(),
      guild_id: String.t(),
      mode: atom(),
      created_by: String.t(),
      created_at: DateTime.t(),
      team_ids: [String.t()],  # Added missing field
      timestamp: DateTime.t(),
      metadata: GameBot.Domain.Events.GameEvents.metadata()
    }
    defstruct [:game_id, :guild_id, :mode, :created_by, :created_at, :team_ids, :timestamp, :metadata]

    def event_type(), do: "game_created"
    def event_version(), do: 1

    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event) do
        cond do
          is_nil(event.created_by) -> {:error, "created_by is required"}
          is_nil(event.created_at) -> {:error, "created_at is required"}
          is_nil(event.team_ids) -> {:error, "team_ids is required"}
          true -> :ok
        end
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "game_id" => event.game_id,
        "guild_id" => event.guild_id,
        "mode" => Atom.to_string(event.mode),
        "created_by" => event.created_by,
        "created_at" => DateTime.to_iso8601(event.created_at),
        "team_ids" => event.team_ids,
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        game_id: data["game_id"],
        guild_id: data["guild_id"],
        mode: String.to_existing_atom(data["mode"]),
        created_by: data["created_by"],
        created_at: GameBot.Domain.Events.GameEvents.parse_timestamp(data["created_at"]),
        team_ids: data["team_ids"],
        timestamp: GameBot.Domain.Events.GameEvents.parse_timestamp(data["timestamp"]),
        metadata: data["metadata"] || %{}
      }
    end
  end

  defmodule RoundCompleted do
    @moduledoc "Emitted when a round completes"
    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      game_id: String.t(),
      guild_id: String.t(),
      mode: atom(),
      round_number: pos_integer(),
      winner_team_id: String.t(),
      round_score: integer(),
      round_stats: %{
        total_guesses: integer(),
        successful_matches: integer(),
        abandoned_guesses: integer(),
        average_guess_count: float()
      },
      timestamp: DateTime.t(),
      metadata: GameBot.Domain.Events.GameEvents.metadata()
    }
    defstruct [:game_id, :guild_id, :mode, :round_number, :winner_team_id,
               :round_score, :round_stats, :timestamp, :metadata]

    def event_type(), do: "round_completed"
    def event_version(), do: 1

    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event) do
        cond do
          is_nil(event.round_number) -> {:error, "round_number is required"}
          is_nil(event.round_stats) -> {:error, "round_stats is required"}
          true -> :ok
        end
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "game_id" => event.game_id,
        "guild_id" => event.guild_id,
        "mode" => Atom.to_string(event.mode),
        "round_number" => event.round_number,
        "winner_team_id" => event.winner_team_id,
        "round_score" => event.round_score,
        "round_stats" => event.round_stats,
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        game_id: data["game_id"],
        guild_id: data["guild_id"],
        mode: String.to_existing_atom(data["mode"]),
        round_number: data["round_number"],
        winner_team_id: data["winner_team_id"],
        round_score: data["round_score"],
        round_stats: data["round_stats"],
        timestamp: GameBot.Domain.Events.GameEvents.parse_timestamp(data["timestamp"]),
        metadata: data["metadata"] || %{}
      }
    end
  end

  defmodule RoundRestarted do
    @derive Jason.Encoder
    defstruct [:game_id, :guild_id, :team_id, :giving_up_player, :teammate_word, :guess_count, :timestamp]

    def event_type, do: "round_restarted"
  end

  defmodule GuessMatched do
    @derive Jason.Encoder
    defstruct [:game_id, :guild_id, :team_id, :player_id, :word, :timestamp]

    def event_type, do: "guess_matched"
  end
end
