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

  # Base fields are defined in EventStructure module and used from there directly

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
    @moduledoc """
    Emitted when a game is started. Contains information about teams, players,
    and game configuration.
    """
    use GameBot.Domain.Events.EventStructure

    @type t :: %__MODULE__{
      # Base Fields
      game_id: String.t(),
      guild_id: String.t(),
      mode: atom(),
      timestamp: DateTime.t(),
      metadata: metadata(),

      # Event-specific Fields
      round_number: pos_integer(),           # Always 1 for game start
      teams: %{String.t() => [String.t()]},  # team_id => [player_ids]
      team_ids: [String.t()],                # Ordered list of team IDs
      player_ids: [String.t()],              # Ordered list of all player IDs
      config: map(),                         # Mode-specific configuration
      started_at: DateTime.t()               # When the game actually started
    }

    defstruct [
      # Base Fields
      :game_id,
      :guild_id,
      :mode,
      :timestamp,
      :metadata,

      # Event-specific Fields
      :round_number,
      :teams,
      :team_ids,
      :player_ids,
      :config,
      :started_at
    ]

    @impl true
    def event_type(), do: "game_started"

    @impl true
    def event_version(), do: 1

    @impl true
    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event),
           :ok <- validate_round_number(event.round_number),
           :ok <- validate_teams(event),
           :ok <- validate_started_at(event.started_at) do
        :ok
      end
    end

    @impl true
    def to_map(%__MODULE__{} = event) do
      %{
        "game_id" => event.game_id,
        "guild_id" => event.guild_id,
        "mode" => Atom.to_string(event.mode),
        "round_number" => event.round_number,
        "teams" => event.teams,
        "team_ids" => event.team_ids,
        "player_ids" => event.player_ids,
        "config" => event.config,
        "started_at" => DateTime.to_iso8601(event.started_at),
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "metadata" => event.metadata || %{}
      }
    end

    @impl true
    def from_map(data) do
      %__MODULE__{
        game_id: data["game_id"],
        guild_id: data["guild_id"],
        mode: String.to_existing_atom(data["mode"]),
        round_number: data["round_number"],
        teams: data["teams"],
        team_ids: data["team_ids"],
        player_ids: data["player_ids"],
        config: data["config"],
        started_at: GameBot.Domain.Events.GameEvents.parse_timestamp(data["started_at"]),
        timestamp: GameBot.Domain.Events.GameEvents.parse_timestamp(data["timestamp"]),
        metadata: data["metadata"] || %{}
      }
    end

    # Private validation functions

    defp validate_round_number(round_number) when is_integer(round_number) and round_number == 1, do: :ok
    defp validate_round_number(_), do: {:error, "round_number must be 1 for game start"}

    # Main validation function
    defp validate_teams(%__MODULE__{teams: teams, team_ids: team_ids, player_ids: player_ids}) do
      cond do
        not is_map(teams) -> {:error, "teams must be a map"}
        not is_list(team_ids) -> {:error, "team_ids must be a list"}
        not is_list(player_ids) -> {:error, "player_ids must be a list"}
        is_list(team_ids) and Enum.empty?(team_ids) -> {:error, "team_ids cannot be empty"}
        is_list(player_ids) and Enum.empty?(player_ids) -> {:error, "player_ids cannot be empty"}
        # Check for empty team player lists - do this check before other team validations
        Enum.any?(teams, fn {_, players} ->
          is_list(players) and Enum.empty?(players)
        end) ->
          {:error, "Each team must have at least one player"}
        # Check if all team_ids have corresponding entries in the teams map
        Enum.any?(team_ids, &(!Map.has_key?(teams, &1))) ->
          # Find the first team_id that's not in the teams map
          missing_team = Enum.find(team_ids, &(!Map.has_key?(teams, &1)))
          {:error, "team_ids contains unknown team: #{missing_team}"}
        !Enum.all?(Map.keys(teams), &(&1 in team_ids)) ->
          {:error, "invalid team_id in teams map"}
        !Enum.all?(List.flatten(Map.values(teams)), &(&1 in player_ids)) ->
          {:error, "invalid player_id in teams"}
        true -> :ok
      end
    end

    # Add a new function clause to handle when teams field is missing
    defp validate_teams(%__MODULE__{teams: nil}) do
      {:error, "teams is required"}
    end

    # Handle the case when the struct is incomplete and doesn't have the teams field at all
    defp validate_teams(%__MODULE__{} = _event) do
      {:error, "teams is required"}
    end

    defp validate_started_at(%DateTime{} = started_at) do
      case DateTime.compare(started_at, DateTime.utc_now()) do
        :gt -> {:error, "started_at cannot be in the future"}
        _ -> :ok
      end
    end
    defp validate_started_at(_), do: {:error, "started_at must be a DateTime"}

    @doc """
    Creates a new GameStarted event.

    This is the most detailed version that allows specifying all parameters.
    """
    @spec new(String.t(), String.t(), atom(), map(), [String.t()], [String.t()], map(), DateTime.t(), map()) :: t()
    def new(game_id, guild_id, mode, teams, team_ids, player_ids, config, started_at, metadata) do
      now = DateTime.utc_now()
      event = %__MODULE__{
        game_id: game_id,
        guild_id: guild_id,
        mode: mode,
        round_number: 1,  # Always 1 for game start
        teams: teams,
        team_ids: team_ids,
        player_ids: player_ids,
        config: config,
        started_at: started_at || now,
        timestamp: now,
        metadata: metadata
      }

      # Validate the event before returning
      case validate(event) do
        :ok -> event
        {:error, reason} -> raise "Invalid GameStarted event: #{reason}"
      end
    end

    @doc """
    Creates a new GameStarted event with default configuration and started_at.
    """
    @spec new(String.t(), String.t(), atom(), map(), [String.t()], [String.t()]) :: t()
    def new(game_id, guild_id, mode, teams, team_ids, player_ids) do
      new(game_id, guild_id, mode, teams, team_ids, player_ids, %{}, nil, %{})
    end
  end

  defmodule RoundStarted do
    @moduledoc """
    Emitted when a new round begins. Contains initial team states and round configuration.
    """
    use GameBot.Domain.Events.EventStructure

    @type team_state :: %{
      team_id: String.t(),
      active_players: [String.t()],
      eliminated_players: [String.t()],
      score: integer(),
      matches: non_neg_integer(),
      total_guesses: pos_integer(),
      average_guesses: float(),
      remaining_guesses: pos_integer()
    }

    @type t :: %__MODULE__{
      # Base Fields
      game_id: String.t(),
      guild_id: String.t(),
      mode: atom(),
      timestamp: DateTime.t(),
      metadata: metadata(),

      # Event-specific Fields
      round_number: pos_integer(),
      team_states: %{String.t() => team_state()}  # team_id => team_state mapping
    }

    defstruct [
      # Base Fields
      :game_id,
      :guild_id,
      :mode,
      :timestamp,
      :metadata,

      # Event-specific Fields
      :round_number,
      :team_states
    ]

    @impl true
    def event_type(), do: "round_started"

    @impl true
    def event_version(), do: 1

    @impl true
    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event),
           :ok <- validate_round_number(event.round_number),
           :ok <- validate_team_states(event.team_states) do
        :ok
      end
    end

    @impl true
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

    @impl true
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

    # Private validation functions

    defp validate_round_number(round_number) when is_integer(round_number) and round_number > 0, do: :ok
    defp validate_round_number(_), do: {:error, "round_number must be a positive integer"}

    defp validate_team_states(team_states) when is_map(team_states) do
      if Enum.empty?(team_states) do
        {:error, "team_states cannot be empty"}
      else
        Enum.reduce_while(team_states, :ok, fn {team_id, state}, :ok ->
          with :ok <- validate_team_id(team_id),
               :ok <- validate_team_state(state) do
            {:cont, :ok}
          else
            error -> {:halt, error}
          end
        end)
      end
    end
    defp validate_team_states(_), do: {:error, "team_states must be a map"}

    defp validate_team_id(team_id) when is_binary(team_id), do: :ok
    defp validate_team_id(_), do: {:error, "team_id must be a string"}

    defp validate_team_state(%{
      team_id: team_id,
      active_players: active_players,
      eliminated_players: eliminated_players,
      score: score,
      matches: matches,
      total_guesses: total_guesses
    } = state) when is_map(state) do
      with :ok <- validate_team_id(team_id),
           :ok <- validate_player_list("active_players", active_players),
           :ok <- validate_player_list("eliminated_players", eliminated_players),
           :ok <- validate_integer("score", score),
           :ok <- validate_non_negative_integer("matches", matches),
           :ok <- validate_positive_integer("total_guesses", total_guesses) do
        :ok
      end
    end
    defp validate_team_state(_), do: {:error, "invalid team state structure"}

    defp validate_player_list(field, players) when is_list(players) do
      if Enum.all?(players, &is_binary/1) do
        :ok
      else
        {:error, "#{field} must be a list of strings"}
      end
    end
    defp validate_player_list(field, _), do: {:error, "#{field} must be a list"}

    defp validate_integer(_field, value) when is_integer(value), do: :ok
    defp validate_integer(field, _), do: {:error, "#{field} must be an integer"}

    defp validate_positive_integer(_field, value) when is_integer(value) and value > 0, do: :ok
    defp validate_positive_integer(field, _), do: {:error, "#{field} must be a positive integer"}

    defp validate_non_negative_integer(_field, value) when is_integer(value) and value >= 0, do: :ok
    defp validate_non_negative_integer(field, _), do: {:error, "#{field} must be a non-negative integer"}

    defp validate_float(_field, value) when is_float(value), do: :ok
    defp validate_float(field, _), do: {:error, "#{field} must be a float"}
  end

  # Gameplay Events
  defmodule GuessProcessed do
    @moduledoc """
    Event emitted when a guess is processed, whether successful or not.
    """

    use GameBot.Domain.Events.EventStructure

    @type t :: %__MODULE__{
      # Base Fields
      game_id: String.t(),
      guild_id: String.t(),
      mode: atom(),
      timestamp: DateTime.t(),
      metadata: metadata(),

      # Event-specific Fields
      round_number: pos_integer(),
      team_id: String.t(),
      player1_info: player_info(),
      player2_info: player_info(),
      player1_word: String.t(),
      player2_word: String.t(),
      guess_successful: boolean(),
      match_score: pos_integer() | nil,  # Required when guess_successful is true
      guess_count: pos_integer(),
      round_guess_count: pos_integer(),
      total_guesses: pos_integer(),
      guess_duration: non_neg_integer(),
      player1_duration: non_neg_integer(),
      player2_duration: non_neg_integer()
    }

    defstruct [
      :game_id,
      :guild_id,
      :mode,
      :round_number,
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

    @impl true
    def event_type, do: "guess_processed"

    @impl true
    def event_version, do: 1

    @impl true
    def validate(event) do
      with :ok <- validate_required_fields(event),
           :ok <- validate_positive_counts(event),
           :ok <- validate_non_negative_duration(event),
           :ok <- validate_player1_duration(event),
           :ok <- validate_player2_duration(event),
           :ok <- validate_match_score(event) do
        :ok
      end
    end

    defp validate_required_fields(event) do
      required_fields = [
        # Base Fields
        :game_id,
        :guild_id,
        :mode,
        :timestamp,
        :metadata,
        # Event-specific Fields
        :round_number,
        :team_id,
        :player1_info,
        :player2_info,
        :player1_word,
        :player2_word,
        :guess_successful,
        :guess_count,
        :round_guess_count,
        :total_guesses,
        :guess_duration,
        :player1_duration,
        :player2_duration
      ]

      case Enum.find(required_fields, &(is_nil(Map.get(event, &1)))) do
        nil -> :ok
        field -> {:error, "#{field} is required"}
      end
    end

    defp validate_positive_counts(event) do
      counts = [
        event.guess_count,
        event.round_guess_count,
        event.total_guesses
      ]

      if Enum.all?(counts, &(is_integer(&1) and &1 > 0)) do
        :ok
      else
        {:error, "guess counts must be positive integers"}
      end
    end

    defp validate_non_negative_duration(event) do
      if is_integer(event.guess_duration) and event.guess_duration >= 0 do
        :ok
      else
        {:error, "guess duration must be a non-negative integer"}
      end
    end

    defp validate_player1_duration(event) do
      if is_integer(event.player1_duration) and event.player1_duration >= 0 do
        :ok
      else
        {:error, "player1_duration must be a non-negative integer"}
      end
    end

    defp validate_player2_duration(event) do
      if is_integer(event.player2_duration) and event.player2_duration >= 0 do
        :ok
      else
        {:error, "player2_duration must be a non-negative integer"}
      end
    end

    defp validate_match_score(event) do
      case {event.guess_successful, event.match_score} do
        {true, score} when is_integer(score) and score > 0 -> :ok
        {true, _} -> {:error, "match_score must be a positive integer when guess is successful"}
        {false, nil} -> :ok
        {false, _} -> {:error, "match_score must be nil when guess is not successful"}
      end
    end

    @impl true
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
        "player1_duration" => event.player1_duration,
        "player2_duration" => event.player2_duration,
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "metadata" => event.metadata || %{}
      }
    end

    @impl true
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
        player1_duration: data["player1_duration"],
        player2_duration: data["player2_duration"],
        timestamp: GameBot.Domain.Events.GameEvents.parse_timestamp(data["timestamp"]),
        metadata: data["metadata"] || %{}
      }
    end

    @doc """
    Creates a new GuessProcessed event with a simplified signature.

    This matches the signature expected by CommandHandler.handle_guess/4.

    ## Parameters
      * `game_id` - Unique identifier for the game
      * `user_id` - User ID making the guess (will be set as guild_id too)
      * `word` - The guessed word
      * `metadata` - Additional metadata for the event

    ## Returns
      * `{:ok, %GuessProcessed{}}` - A new GuessProcessed event struct with status
    """
    @spec new(String.t(), String.t(), String.t(), map()) :: {:ok, t()}
    def new(game_id, _user_id, word, metadata) do
      # Use exact correlation_id from parent metadata
      # and set the parent correlation_id as causation_id
      parent_correlation_id = Map.get(metadata, :correlation_id) ||
                             Map.get(metadata, "correlation_id")

      enhanced_metadata = metadata
        # Keep the same correlation_id from parent
        |> Map.put(:correlation_id, parent_correlation_id)
        # Set causation_id to parent's correlation_id
        |> Map.put(:causation_id, parent_correlation_id)
        |> Map.put_new(:source_id, Map.get(metadata, :interaction_id) ||
                              Map.get(metadata, "interaction_id") ||
                              Map.get(metadata, :user_id) ||
                              Map.get(metadata, "user_id") ||
                              UUID.uuid4())

      # Create default guess data
      guess_data = %{
        round_number: 1,
        player1_word: word,
        player2_word: "",
        metadata: enhanced_metadata
      }

      # Create the event using the detailed constructor
      guild_id = Map.get(metadata, :guild_id) || Map.get(metadata, "guild_id") || ""
      event = new_detailed(game_id, guild_id, "team_temp_id", guess_data)

      {:ok, event}
    end

    @doc """
    Creates a new GuessProcessed event with the specified parameters.

    ## Parameters
      * `game_id` - Unique identifier for the game
      * `guild_id` - Discord guild ID where the game is being played
      * `team_id` - ID of the team making the guess
      * `guess_data` - Map containing detailed guess information:
        * `round_number` - Current round number
        * `mode` - Game mode (e.g., :two_player, :knockout)
        * `player1_info` - Information about the first player
        * `player2_info` - Information about the second player
        * `player1_word` - Word provided by first player
        * `player2_word` - Word provided by second player
        * `guess_successful` - Whether the guess was successful
        * `match_score` - Score for this match (if successful)
        * `guess_count` - Current guess count
        * `round_guess_count` - Guess count for this round
        * `total_guesses` - Total guesses in the game
        * `guess_duration` - Duration of the guess in seconds

    ## Returns
      * `%GuessProcessed{}` - A new GuessProcessed event struct
    """
    @spec new_detailed(String.t(), String.t(), String.t(), map()) :: t()
    def new_detailed(game_id, guild_id, team_id, guess_data) do
      now = DateTime.utc_now()

      # Ensure player info is properly set with default values if missing
      player1_info = Map.get(guess_data, :player1_info) || Map.get(guess_data, "player1_info") ||
                    %{"player_id" => "unknown", "name" => "Unknown Player"}

      player2_info = Map.get(guess_data, :player2_info) || Map.get(guess_data, "player2_info") ||
                    %{"player_id" => "unknown", "name" => "Unknown Player"}

      event = %__MODULE__{
        game_id: game_id,
        guild_id: guild_id,
        mode: Map.get(guess_data, :mode) || Map.get(guess_data, "mode", :two_player),
        round_number: Map.get(guess_data, :round_number) || Map.get(guess_data, "round_number", 1),
        team_id: team_id,
        player1_info: player1_info,
        player2_info: player2_info,
        player1_word: Map.get(guess_data, :player1_word) || Map.get(guess_data, "player1_word", ""),
        player2_word: Map.get(guess_data, :player2_word) || Map.get(guess_data, "player2_word", ""),
        guess_successful: Map.get(guess_data, :guess_successful) || Map.get(guess_data, "guess_successful", false),
        match_score: Map.get(guess_data, :match_score) || Map.get(guess_data, "match_score"),
        guess_count: Map.get(guess_data, :guess_count) || Map.get(guess_data, "guess_count", 1),
        round_guess_count: Map.get(guess_data, :round_guess_count) || Map.get(guess_data, "round_guess_count", 1),
        total_guesses: Map.get(guess_data, :total_guesses) || Map.get(guess_data, "total_guesses", 1),
        guess_duration: Map.get(guess_data, :guess_duration) || Map.get(guess_data, "guess_duration", 0),
        player1_duration: Map.get(guess_data, :player1_duration) || Map.get(guess_data, "player1_duration", 0),
        player2_duration: Map.get(guess_data, :player2_duration) || Map.get(guess_data, "player2_duration", 0),
        timestamp: now,
        metadata: Map.get(guess_data, :metadata) || Map.get(guess_data, "metadata", %{})
      }

      # Validate the event before returning
      case validate(event) do
        :ok -> event
        {:error, reason} -> raise "Invalid GuessProcessed event: #{reason}"
      end
    end
  end

  defmodule GuessAbandoned do
    @moduledoc "Emitted when a guess attempt is abandoned due to timeout or player giving up"
    use GameBot.Domain.Events.EventStructure

    @type t :: %__MODULE__{
      # Base Fields
      game_id: String.t(),
      guild_id: String.t(),
      mode: atom(),
      timestamp: DateTime.t(),
      metadata: metadata(),

      # Event-specific Fields
      round_number: pos_integer(),
      team_id: String.t(),
      player1_info: player_info(),
      player2_info: player_info(),
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
      guess_duration: non_neg_integer() | nil
    }

    defstruct [
      :game_id,
      :guild_id,
      :mode,
      :round_number,
      :team_id,
      :player1_info,
      :player2_info,
      :reason,
      :abandoning_player_id,
      :last_guess,
      :guess_count,
      :round_guess_count,
      :total_guesses,
      :guess_duration,
      :timestamp,
      :metadata
    ]

    @impl true
    def event_type, do: "guess_abandoned"

    @impl true
    def event_version, do: 1

    @impl true
    def validate(event) do
      with :ok <- validate_required_fields(event),
           :ok <- validate_positive_counts(event),
           :ok <- validate_non_negative_duration(event),
           :ok <- validate_reason(event),
           :ok <- validate_last_guess(event) do
        :ok
      end
    end

    defp validate_required_fields(event) do
      required_fields = [
        # Base Fields
        :game_id,
        :guild_id,
        :mode,
        :timestamp,
        :metadata,
        # Event-specific Fields
        :round_number,
        :team_id,
        :player1_info,
        :player2_info,
        :reason,
        :abandoning_player_id,
        :guess_count,
        :round_guess_count,
        :total_guesses
      ]

      case Enum.find(required_fields, &(is_nil(Map.get(event, &1)))) do
        nil -> :ok
        field -> {:error, "#{field} is required"}
      end
    end

    defp validate_positive_counts(event) do
      counts = [
        event.guess_count,
        event.round_guess_count,
        event.total_guesses
      ]

      if Enum.all?(counts, &(is_integer(&1) and &1 > 0)) do
        :ok
      else
        {:error, "guess counts must be positive integers"}
      end
    end

    defp validate_non_negative_duration(event) do
      case event.guess_duration do
        nil -> :ok
        duration when is_integer(duration) and duration >= 0 -> :ok
        _ -> {:error, "guess duration must be a non-negative integer or nil"}
      end
    end

    defp validate_reason(event) do
      valid_reasons = [:timeout, :player_quit, :disconnected]
      if event.reason in valid_reasons do
        :ok
      else
        {:error, "reason must be one of: #{Enum.join(valid_reasons, ", ")}"}
      end
    end

    defp validate_last_guess(nil), do: :ok
    defp validate_last_guess(%{player_id: pid, word: w, timestamp: %DateTime{}} = _last_guess)
      when is_binary(pid) and is_binary(w), do: :ok
    defp validate_last_guess(_), do: {:error, "last_guess must be nil or contain valid player_id, word, and timestamp"}

    @impl true
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

    @impl true
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
    @moduledoc """
    Emitted when a team is eliminated from the game. Contains final team state,
    reason for elimination, and player statistics.
    """
    use GameBot.Domain.Events.EventStructure

    @type elimination_reason :: :timeout | :max_guesses | :round_loss | :forfeit

    @type team_player_stats :: %{
      total_guesses: pos_integer(),
      successful_matches: non_neg_integer(),
      abandoned_guesses: non_neg_integer(),
      average_guess_count: float()
    }

    @type t :: %__MODULE__{
      # Base Fields
      game_id: String.t(),
      guild_id: String.t(),
      mode: atom(),
      timestamp: DateTime.t(),
      metadata: metadata(),

      # Event-specific Fields
      round_number: pos_integer(),
      team_id: String.t(),
      reason: elimination_reason(),
      final_state: team_info(),
      final_score: integer(),
      player_stats: %{String.t() => team_player_stats()}
    }

    defstruct [
      # Base Fields
      :game_id,
      :guild_id,
      :mode,
      :timestamp,
      :metadata,

      # Event-specific Fields
      :round_number,
      :team_id,
      :reason,
      :final_state,
      :final_score,
      :player_stats
    ]

    @impl true
    def event_type(), do: "team_eliminated"

    @impl true
    def event_version(), do: 1

    @impl true
    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event),
           :ok <- validate_round_number(event.round_number),
           :ok <- validate_team_id(event.team_id),
           :ok <- validate_reason(event.reason),
           :ok <- validate_final_state(event.final_state),
           :ok <- validate_final_score(event.final_score),
           :ok <- validate_player_stats(event.player_stats) do
        :ok
      end
    end

    @impl true
    def to_map(%__MODULE__{} = event) do
      %{
        "game_id" => event.game_id,
        "guild_id" => event.guild_id,
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

    @impl true
    def from_map(data) do
      %__MODULE__{
        game_id: data["game_id"],
        guild_id: data["guild_id"],
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

    # Private validation functions

    defp validate_round_number(round_number) when is_integer(round_number) and round_number > 0, do: :ok
    defp validate_round_number(_), do: {:error, "round_number must be a positive integer"}

    defp validate_team_id(team_id) when is_binary(team_id), do: :ok
    defp validate_team_id(_), do: {:error, "team_id must be a string"}

    defp validate_reason(reason) when reason in [:timeout, :max_guesses, :round_loss, :forfeit], do: :ok
    defp validate_reason(_), do: {:error, "reason must be one of: timeout, max_guesses, round_loss, forfeit"}

    defp validate_final_state(%{
      team_id: team_id,
      player_ids: player_ids,
      score: score,
      matches: matches,
      total_guesses: total_guesses
    } = state) when is_map(state) do
      with :ok <- validate_team_id(team_id),
           :ok <- validate_player_ids(player_ids),
           :ok <- validate_integer("score", score),
           :ok <- validate_non_negative_integer("matches", matches),
           :ok <- validate_positive_integer("total_guesses", total_guesses) do
        :ok
      end
    end
    defp validate_final_state(_), do: {:error, "invalid final_state structure"}

    defp validate_player_ids(player_ids) when is_list(player_ids) do
      if Enum.all?(player_ids, &is_binary/1) do
        :ok
      else
        {:error, "player_ids must be a list of strings"}
      end
    end
    defp validate_player_ids(_), do: {:error, "player_ids must be a list"}

    defp validate_final_score(score) when is_integer(score), do: :ok
    defp validate_final_score(_), do: {:error, "final_score must be an integer"}

    defp validate_player_stats(stats) when is_map(stats) do
      Enum.reduce_while(stats, :ok, fn {player_id, stats}, :ok ->
        with :ok <- validate_team_id(player_id),
             :ok <- validate_player_stat_values(stats) do
          {:cont, :ok}
        else
          error -> {:halt, error}
        end
      end)
    end
    defp validate_player_stats(_), do: {:error, "player_stats must be a map"}

    defp validate_player_stat_values(%{
      total_guesses: total_guesses,
      successful_matches: successful_matches,
      abandoned_guesses: abandoned_guesses,
      average_guess_count: average_guess_count
    }) do
      with :ok <- validate_positive_integer("total_guesses", total_guesses),
           :ok <- validate_non_negative_integer("successful_matches", successful_matches),
           :ok <- validate_non_negative_integer("abandoned_guesses", abandoned_guesses),
           :ok <- validate_float("average_guess_count", average_guess_count) do
        :ok
      end
    end
    defp validate_player_stat_values(_), do: {:error, "invalid player stats structure"}

    defp validate_integer(_field, value) when is_integer(value), do: :ok
    defp validate_integer(field, _), do: {:error, "#{field} must be an integer"}

    defp validate_positive_integer(_field, value) when is_integer(value) and value > 0, do: :ok
    defp validate_positive_integer(field, _), do: {:error, "#{field} must be a positive integer"}

    defp validate_non_negative_integer(_field, value) when is_integer(value) and value >= 0, do: :ok
    defp validate_non_negative_integer(field, _), do: {:error, "#{field} must be a non-negative integer"}

    defp validate_float(_field, value) when is_float(value), do: :ok
    defp validate_float(field, _), do: {:error, "#{field} must be a float"}
  end

  defmodule GameCompleted do
    @moduledoc """
    Emitted when a game ends. Contains final game state including winners, scores,
    player statistics, and timing information.
    """
    use GameBot.Domain.Events.EventStructure

    # Import validation functions
    import GameBot.Domain.Events.GameEvents.GameCompletedValidator

    @type game_player_stats :: %{
      total_guesses: pos_integer(),
      successful_matches: non_neg_integer(),
      abandoned_guesses: non_neg_integer(),
      average_guess_count: float()
    }

    @type team_score :: %{
      score: integer(),
      matches: non_neg_integer(),
      total_guesses: pos_integer(),
      average_guesses: float(),
      player_stats: %{String.t() => game_player_stats()}
    }

    @type t :: %__MODULE__{
      # Base Fields
      game_id: String.t(),
      guild_id: String.t(),
      mode: atom(),
      timestamp: DateTime.t(),
      metadata: metadata(),

      # Event-specific Fields
      round_number: pos_integer(),
      winners: [String.t()],
      final_scores: %{String.t() => team_score()},
      game_duration: non_neg_integer(),
      total_rounds: pos_integer(),
      finished_at: DateTime.t()
    }

    defstruct [
      # Base Fields
      :game_id,
      :guild_id,
      :mode,
      :timestamp,
      :metadata,

      # Event-specific Fields
      :round_number,
      :winners,
      :final_scores,
      :game_duration,
      :total_rounds,
      :finished_at
    ]

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

    @impl true
    def event_type(), do: "game_completed"

    @impl true
    def event_version(), do: 1

    @impl true
    def validate(%__MODULE__{} = event) do
      with :ok <- validate_winners(event.winners),
           :ok <- validate_final_scores(event.final_scores),
           :ok <- validate_positive_counts(event),
           :ok <- validate_non_negative_duration(event.game_duration),
           :ok <- validate_finished_at(event.finished_at, event.timestamp) do
        :ok
      end
    end

    @impl true
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

    @impl true
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

    # Private validation functions

    defp validate_winners(winners) when is_list(winners) do
      if Enum.empty?(winners) do
        {:error, "winners list cannot be empty"}
      else
        if Enum.all?(winners, &is_binary/1) do
          :ok
        else
          {:error, "winners must be a list of strings"}
        end
      end
    end
    defp validate_winners(_), do: {:error, "winners must be a list"}

    defp validate_final_scores(scores) when is_map(scores) do
      if Enum.empty?(scores) do
        {:error, "final_scores cannot be empty"}
      else
        Enum.reduce_while(scores, :ok, fn {team_id, score}, :ok ->
          with :ok <- validate_team_id(team_id),
               :ok <- validate_team_score(score) do
            {:cont, :ok}
          else
            error -> {:halt, error}
          end
        end)
      end
    end
    defp validate_final_scores(_), do: {:error, "final_scores must be a map"}

    defp validate_team_id(team_id) when is_binary(team_id), do: :ok
    defp validate_team_id(_), do: {:error, "team_id must be a string"}

    defp validate_team_score(%{
      score: score,
      matches: matches,
      total_guesses: total_guesses,
      average_guesses: average_guesses,
      player_stats: player_stats
    }) when is_map(player_stats) do
      with :ok <- validate_integer("score", score),
           :ok <- validate_non_negative_integer("matches", matches),
           :ok <- validate_positive_integer("total_guesses", total_guesses),
           :ok <- validate_float("average_guesses", average_guesses) do
        :ok
      end
    end
    defp validate_team_score(_), do: {:error, "invalid team score structure"}

    defp validate_positive_counts(%__MODULE__{round_number: round_number, total_rounds: total_rounds}) do
      with :ok <- validate_positive_integer("round_number", round_number),
           :ok <- validate_positive_integer("total_rounds", total_rounds) do
        :ok
      end
    end

    defp validate_non_negative_duration(duration) when is_integer(duration) and duration >= 0, do: :ok
    defp validate_non_negative_duration(_), do: {:error, "game_duration must be non-negative integer"}

    defp validate_finished_at(%DateTime{} = finished_at, %DateTime{} = timestamp) do
      case DateTime.compare(finished_at, timestamp) do
        :gt -> {:error, "finished_at cannot be after timestamp"}
        _ -> :ok
      end
    end
    defp validate_finished_at(_, _), do: {:error, "finished_at must be a DateTime"}
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

    @impl true
    def event_type(), do: "knockout_round_completed"
    @impl true
    def event_version(), do: 1

    @impl true
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

    @impl true
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

    @impl true
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

    @impl true
    def event_type(), do: "race_mode_time_expired"
    @impl true
    def event_version(), do: 1

    @impl true
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

    @impl true
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

    @impl true
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

    @impl true
    def event_type(), do: "longform_day_ended"
    @impl true
    def event_version(), do: 1

    @impl true
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

    @impl true
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

    @impl true
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

    @impl true
    def event_type(), do: "game_created"
    @impl true
    def event_version(), do: 1

    @impl true
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

    @impl true
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

    @impl true
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
    @moduledoc """
    Emitted when a round completes. Contains round results including winner,
    scores, and statistics.
    """
    use GameBot.Domain.Events.EventStructure

    @type round_player_stats :: %{
      total_guesses: pos_integer(),
      successful_matches: non_neg_integer(),
      abandoned_guesses: non_neg_integer(),
      average_guess_count: float()
    }

    @type t :: %__MODULE__{
      # Base Fields
      game_id: String.t(),
      guild_id: String.t(),
      mode: atom(),
      timestamp: DateTime.t(),
      metadata: metadata(),

      # Event-specific Fields
      round_number: pos_integer(),
      winner_team_id: String.t(),
      round_score: integer(),
      round_stats: round_player_stats()
    }

    defstruct [
      # Base Fields
      :game_id,
      :guild_id,
      :mode,
      :timestamp,
      :metadata,

      # Event-specific Fields
      :round_number,
      :winner_team_id,
      :round_score,
      :round_stats
    ]

    @impl true
    def event_type(), do: "round_completed"

    @impl true
    def event_version(), do: 1

    @impl true
    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event),
           :ok <- validate_round_number(event.round_number),
           :ok <- validate_winner_team_id(event.winner_team_id),
           :ok <- validate_round_score(event.round_score),
           :ok <- validate_round_stats(event.round_stats) do
        :ok
      end
    end

    @impl true
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

    @impl true
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

    # Private validation functions

    defp validate_round_number(round_number) when is_integer(round_number) and round_number > 0, do: :ok
    defp validate_round_number(_), do: {:error, "round_number must be a positive integer"}

    defp validate_winner_team_id(team_id) when is_binary(team_id), do: :ok
    defp validate_winner_team_id(_), do: {:error, "winner_team_id must be a string"}

    defp validate_round_score(score) when is_integer(score), do: :ok
    defp validate_round_score(_), do: {:error, "round_score must be an integer"}

    defp validate_round_stats(%{
      total_guesses: total_guesses,
      successful_matches: successful_matches,
      abandoned_guesses: abandoned_guesses,
      average_guess_count: average_guess_count
    }) do
      with :ok <- validate_positive_integer("total_guesses", total_guesses),
           :ok <- validate_non_negative_integer("successful_matches", successful_matches),
           :ok <- validate_non_negative_integer("abandoned_guesses", abandoned_guesses),
           :ok <- validate_float("average_guess_count", average_guess_count) do
        :ok
      end
    end
    defp validate_round_stats(_), do: {:error, "invalid round_stats structure"}

    defp validate_positive_integer(_field, value) when is_integer(value) and value > 0, do: :ok
    defp validate_positive_integer(field, _), do: {:error, "#{field} must be a positive integer"}

    defp validate_non_negative_integer(_field, value) when is_integer(value) and value >= 0, do: :ok
    defp validate_non_negative_integer(field, _), do: {:error, "#{field} must be a non-negative integer"}

    defp validate_float(_field, value) when is_float(value), do: :ok
    defp validate_float(field, _), do: {:error, "#{field} must be a float"}
  end

  defmodule RoundRestarted do
    @derive Jason.Encoder
    defstruct [:game_id, :guild_id, :team_id, :giving_up_player, :teammate_word, :guess_count, :timestamp]

    def event_type, do: "round_restarted"
  end

  defimpl GameBot.Domain.Events.EventValidator, for: GameBot.Domain.Events.GameEvents.GameStarted do
    def validate(event) do
      # Call the event's module validate function directly
      GameBot.Domain.Events.GameEvents.GameStarted.validate(event)
    end
  end
end
