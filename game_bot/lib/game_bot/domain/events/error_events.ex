defmodule GameBot.Domain.Events.ErrorEvents do
  @moduledoc """
  Defines error events that can occur during game play.
  """

  alias GameBot.Domain.Events.Metadata

  @type metadata :: Metadata.t()

  defmodule GuessError do
    @moduledoc "Emitted when there is an error processing a guess"
    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      game_id: String.t(),
      team_id: String.t(),
      player_id: String.t(),
      word: String.t(),
      reason: atom(),
      timestamp: DateTime.t(),
      metadata: GameBot.Domain.Events.GameEvents.metadata()
    }
    defstruct [:game_id, :team_id, :player_id, :word, :reason, :timestamp, :metadata]

    def event_type(), do: "guess_error"
    def event_version(), do: 1

    def validate(%__MODULE__{} = event) do
      cond do
        is_nil(event.game_id) -> {:error, "game_id is required"}
        is_nil(event.team_id) -> {:error, "team_id is required"}
        is_nil(event.player_id) -> {:error, "player_id is required"}
        is_nil(event.word) -> {:error, "word is required"}
        is_nil(event.reason) -> {:error, "reason is required"}
        true -> :ok
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "game_id" => event.game_id,
        "team_id" => event.team_id,
        "player_id" => event.player_id,
        "word" => event.word,
        "reason" => Atom.to_string(event.reason),
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        game_id: data["game_id"],
        team_id: data["team_id"],
        player_id: data["player_id"],
        word: data["word"],
        reason: String.to_existing_atom(data["reason"]),
        timestamp: GameBot.Domain.Events.GameEvents.parse_timestamp(data["timestamp"]),
        metadata: data["metadata"] || %{}
      }
    end

    def new(game_id, team_id, player_id, word, reason) do
      %__MODULE__{
        game_id: game_id,
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
    @moduledoc "Emitted when there is an error processing a guess pair"
    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      game_id: String.t(),
      team_id: String.t(),
      word1: String.t(),
      word2: String.t(),
      reason: atom(),
      timestamp: DateTime.t(),
      metadata: GameBot.Domain.Events.GameEvents.metadata()
    }
    defstruct [:game_id, :team_id, :word1, :word2, :reason, :timestamp, :metadata]

    def event_type(), do: "guess_pair_error"
    def event_version(), do: 1

    def validate(%__MODULE__{} = event) do
      cond do
        is_nil(event.game_id) -> {:error, "game_id is required"}
        is_nil(event.team_id) -> {:error, "team_id is required"}
        is_nil(event.word1) -> {:error, "word1 is required"}
        is_nil(event.word2) -> {:error, "word2 is required"}
        is_nil(event.reason) -> {:error, "reason is required"}
        true -> :ok
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "game_id" => event.game_id,
        "team_id" => event.team_id,
        "word1" => event.word1,
        "word2" => event.word2,
        "reason" => Atom.to_string(event.reason),
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        game_id: data["game_id"],
        team_id: data["team_id"],
        word1: data["word1"],
        word2: data["word2"],
        reason: String.to_existing_atom(data["reason"]),
        timestamp: GameBot.Domain.Events.GameEvents.parse_timestamp(data["timestamp"]),
        metadata: data["metadata"] || %{}
      }
    end

    def new(game_id, team_id, word1, word2, reason) do
      %__MODULE__{
        game_id: game_id,
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
    @moduledoc "Emitted when there is an error checking round status"
    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      game_id: String.t(),
      reason: atom(),
      timestamp: DateTime.t(),
      metadata: GameBot.Domain.Events.GameEvents.metadata()
    }
    defstruct [:game_id, :reason, :timestamp, :metadata]

    def event_type(), do: "round_check_error"
    def event_version(), do: 1

    def validate(%__MODULE__{} = event) do
      cond do
        is_nil(event.game_id) -> {:error, "game_id is required"}
        is_nil(event.reason) -> {:error, "reason is required"}
        true -> :ok
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "game_id" => event.game_id,
        "reason" => Atom.to_string(event.reason),
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %__MODULE__{
        game_id: data["game_id"],
        reason: String.to_existing_atom(data["reason"]),
        timestamp: GameBot.Domain.Events.GameEvents.parse_timestamp(data["timestamp"]),
        metadata: data["metadata"] || %{}
      }
    end

    def new(game_id, reason) do
      %__MODULE__{
        game_id: game_id,
        reason: reason,
        timestamp: DateTime.utc_now(),
        metadata: %{}
      }
    end
  end
end
