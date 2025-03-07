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
      "player_joined" -> GameBot.Domain.Events.GameEvents.PlayerJoined
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
      timestamp: DateTime.t(),
      metadata: GameBot.Domain.Events.GameEvents.metadata()
    }
    defstruct [:game_id, :mode, :round_number, :team_id, :player1_info, :player2_info,
               :player1_word, :player2_word, :guess_successful, :guess_count, :match_score,
               :timestamp, :metadata]

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
        player1_info: data["player1_info"],
        player2_info: data["player2_info"],
        player1_word: data["player1_word"],
        player2_word: data["player2_word"],
        guess_successful: data["guess_successful"],
        guess_count: data["guess_count"],
        match_score: data["match_score"],
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
      timestamp: DateTime.t(),
      metadata: GameBot.Domain.Events.GameEvents.metadata()
    }
    defstruct [:game_id, :mode, :round_number, :team_id, :player1_info, :player2_info,
               :reason, :abandoning_player_id, :last_guess, :guess_count, :timestamp, :metadata]

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
        "mode" => Atom.to_string(event.mode),
        "round_number" => event.round_number,
        "team_id" => event.team_id,
        "player1_info" => event.player1_info,
        "player2_info" => event.player2_info,
        "reason" => Atom.to_string(event.reason),
        "abandoning_player_id" => event.abandoning_player_id,
        "last_guess" => if(event.last_guess, do: Map.update!(event.last_guess, :timestamp, &DateTime.to_iso8601/1)),
        "guess_count" => event.guess_count,
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
        player1_info: data["player1_info"],
        player2_info: data["player2_info"],
        reason: String.to_existing_atom(data["reason"]),
        abandoning_player_id: data["abandoning_player_id"],
        last_guess: if(data["last_guess"], do: Map.update!(data["last_guess"], "timestamp", &GameBot.Domain.Events.GameEvents.parse_timestamp/1)),
        guess_count: data["guess_count"],
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
      metadata: GameBot.Domain.Events.GameEvents.metadata()
    }
    defstruct [:game_id, :mode, :round_number, :winners, :final_scores,
               :game_duration, :total_rounds, :timestamp, :metadata]

    def event_type(), do: "game_completed"
    def event_version(), do: 1

    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event) do
        cond do
          is_nil(event.winners) -> {:error, "winners is required"}
          is_nil(event.final_scores) -> {:error, "final_scores is required"}
          is_nil(event.game_duration) -> {:error, "game_duration is required"}
          is_nil(event.total_rounds) -> {:error, "total_rounds is required"}
          event.total_rounds < 1 -> {:error, "total_rounds must be positive"}
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
        "winners" => event.winners,
        "final_scores" => event.final_scores,
        "game_duration" => event.game_duration,
        "total_rounds" => event.total_rounds,
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        game_id: data["game_id"],
        mode: String.to_existing_atom(data["mode"]),
        round_number: data["round_number"],
        winners: data["winners"],
        final_scores: data["final_scores"],
        game_duration: data["game_duration"],
        total_rounds: data["total_rounds"],
        timestamp: GameBot.Domain.Events.GameEvents.parse_timestamp(data["timestamp"]),
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

  defmodule GameFinished do
    @derive Jason.Encoder
    defstruct [
      :game_id,
      :guild_id,
      :mode,
      :round_number,
      :final_score,
      :winner_team_id,
      :timestamp,
      :metadata
    ]

    @type t :: %__MODULE__{
      game_id: String.t(),
      guild_id: String.t(),
      mode: atom(),
      round_number: pos_integer(),
      final_score: map(),
      winner_team_id: String.t(),
      timestamp: DateTime.t(),
      metadata: map()
    }

    @doc """
    Creates a new GameFinished event with minimal parameters.

    This is a convenience function used primarily in the Session module's game_end handler.
    It takes the essential parameters needed to create a GameFinished event and delegates
    to the full new/7 function with sensible defaults for the other parameters.

    ## Parameters
      * `game_id` - Unique identifier for the game
      * `winner_team_id` - ID of the winning team (or teams, as a list)
      * `final_score` - Map of team_id to final score
      * `guild_id` - Discord guild ID where the game was played

    ## Returns
      * `%GameFinished{}` - A new GameFinished event struct

    ## Examples
        iex> GameFinished.new("game_123", "team_abc", %{"team_abc" => 100}, "guild_456")
        %GameFinished{
          game_id: "game_123",
          guild_id: "guild_456",
          mode: :unknown,
          round_number: 1,
          final_score: %{"team_abc" => 100},
          winner_team_id: "team_abc",
          timestamp: ~U[2023-01-01 12:00:00Z],
          metadata: %{}
        }
    """
    @spec new(String.t(), String.t() | [String.t()], map(), String.t()) :: t()
    def new(game_id, winner_team_id, final_score, guild_id) do
      # Use sensible defaults for mode and round_number
      # In a production environment, these might be extracted from the game_id
      # or retrieved from a game state repository
      new(
        game_id,        # game_id
        guild_id,       # guild_id
        :unknown,       # mode - using placeholder since not provided
        1,              # round_number - using default since not provided
        final_score,    # final_score
        winner_team_id  # winner_team_id
      )
    end

    @doc """
    Creates a new GameFinished event with full parameters.

    This function creates a GameFinished event with all possible parameters.
    It's used both directly and as a delegate from the simplified new/4 function.

    ## Parameters
      * `game_id` - Unique identifier for the game
      * `guild_id` - Discord guild ID where the game was played
      * `mode` - Game mode (e.g., :two_player, :knockout)
      * `round_number` - Final round number when the game ended
      * `final_score` - Map of team_id to final score
      * `winner_team_id` - ID of the winning team (or teams, as a list)
      * `metadata` - Additional metadata for the event (optional)

    ## Returns
      * `%GameFinished{}` - A new GameFinished event struct
    """
    @spec new(String.t(), String.t(), atom(), pos_integer(), map(), String.t() | [String.t()], map()) :: t()
    def new(game_id, guild_id, mode, round_number, final_score, winner_team_id, metadata \\ %{}) do
      %__MODULE__{
        game_id: game_id,
        guild_id: guild_id,
        mode: mode,
        round_number: round_number,
        final_score: final_score,
        winner_team_id: winner_team_id,
        timestamp: DateTime.utc_now(),
        metadata: metadata
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

  defmodule RoundEnded do
    @derive Jason.Encoder
    defstruct [:game_id, :round_number, :winners, :timestamp]

    def event_type, do: "game.round_ended"
  end

  defmodule RoundFinished do
    @derive Jason.Encoder
    defstruct [:game_id, :guild_id, :round_number, :finished_at, :winner_team_id, :round_score, :round_stats]

    def event_type, do: "game.round_finished"
  end

  defmodule RoundRestarted do
    @derive Jason.Encoder
    defstruct [:game_id, :guild_id, :team_id, :giving_up_player, :teammate_word, :guess_count, :timestamp]

    def event_type, do: "game.round_restarted"
  end

  defmodule GuessMatched do
    @derive Jason.Encoder
    defstruct [:game_id, :team_id, :player1_info, :player2_info, :player1_word,
               :player2_word, :guess_successful, :match_score, :guess_count]

    def event_type, do: "game.guess_matched"
  end

  defmodule TeamInvitationCreated do
    @derive Jason.Encoder
    defstruct [:guild_id, :team_id, :invitation_id, :created_at, :created_by]

    def event_type, do: "team.invitation_created"
  end

  defmodule TeamEvents.TeamInvitationCreated do
    @derive Jason.Encoder
    defstruct [:guild_id, :team_id, :invitation_id, :created_at, :created_by]

    def event_type, do: "team.invitation_created"
  end

  defmodule Commands.TeamCommands.CreateTeamInvitation do
    @derive Jason.Encoder
    defstruct [:guild_id, :team_id, :invitation_id, :created_at, :created_by]

    def event_type, do: "team.invitation_created"
  end

  defmodule PlayerJoined do
    @moduledoc "Emitted when a player joins a game"
    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      game_id: String.t(),
      guild_id: String.t(),
      player_id: String.t(),
      username: String.t(),
      joined_at: DateTime.t(),
      metadata: GameBot.Domain.Events.GameEvents.metadata()
    }
    defstruct [:game_id, :guild_id, :player_id, :username, :joined_at, :metadata]

    def event_type(), do: "player_joined"
    def event_version(), do: 1

    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event) do
        cond do
          is_nil(event.player_id) -> {:error, "player_id is required"}
          is_nil(event.username) -> {:error, "username is required"}
          is_nil(event.joined_at) -> {:error, "joined_at is required"}
          true -> :ok
        end
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "game_id" => event.game_id,
        "guild_id" => event.guild_id,
        "player_id" => event.player_id,
        "username" => event.username,
        "joined_at" => DateTime.to_iso8601(event.joined_at),
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        game_id: data["game_id"],
        guild_id: data["guild_id"],
        player_id: data["player_id"],
        username: data["username"],
        joined_at: GameBot.Domain.Events.GameEvents.parse_timestamp(data["joined_at"]),
        metadata: data["metadata"] || %{}
      }
    end
  end
end
