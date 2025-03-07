defmodule GameBot.Domain.Events do
  @moduledoc """
  Contains event structs for the game domain.
  """

  alias GameBot.Domain.Events.{Metadata, EventStructure}

  defmodule GuessProcessed do
    @moduledoc """
    Emitted when a guess attempt is processed.
    This event represents the complete lifecycle of a guess:
    1. Both players have submitted their words
    2. The guess has been validated
    3. The match has been checked
    4. The result has been recorded
    """
    @behaviour GameBot.Domain.Events.GameEvents

    @type t :: %__MODULE__{
      game_id: String.t(),
      team_id: String.t(),
      player1_info: GameBot.Domain.Events.GameEvents.player_info(),
      player2_info: GameBot.Domain.Events.GameEvents.player_info(),
      player1_word: String.t(),
      player2_word: String.t(),
      guess_successful: boolean(),      # Whether the words matched
      match_score: integer() | nil,     # Score if matched, nil if not matched
      guess_count: pos_integer(),       # Total number of guesses made
      timestamp: DateTime.t(),
      guild_id: String.t(),
      metadata: GameBot.Domain.Events.GameEvents.metadata(),
      # History tracking fields
      round_number: pos_integer(),
      round_guess_count: pos_integer(),  # Number of guesses in this round
      total_guesses: pos_integer(),      # Total guesses across all rounds
      guess_duration: integer()          # Time taken for this guess in milliseconds
    }
    defstruct [:game_id, :team_id, :player1_info, :player2_info,
               :player1_word, :player2_word, :guess_successful, :match_score,
               :guess_count, :timestamp, :guild_id, :metadata,
               :round_number, :round_guess_count, :total_guesses,
               :guess_duration]

    def event_type(), do: "guess_processed"
    def event_version(), do: 1

    def validate(%__MODULE__{} = event) do
      with :ok <- EventStructure.validate(event) do
        cond do
          is_nil(event.game_id) -> {:error, "game_id is required"}
          is_nil(event.team_id) -> {:error, "team_id is required"}
          is_nil(event.guild_id) -> {:error, "guild_id is required"}
          is_nil(event.player1_info) -> {:error, "player1_info is required"}
          is_nil(event.player2_info) -> {:error, "player2_info is required"}
          is_nil(event.player1_word) -> {:error, "player1_word is required"}
          is_nil(event.player2_word) -> {:error, "player2_word is required"}
          is_nil(event.guess_count) -> {:error, "guess_count is required"}
          is_nil(event.round_number) -> {:error, "round_number is required"}
          is_nil(event.round_guess_count) -> {:error, "round_guess_count is required"}
          is_nil(event.total_guesses) -> {:error, "total_guesses is required"}
          is_nil(event.guess_duration) -> {:error, "guess_duration is required"}
          event.guess_count < 1 -> {:error, "guess_count must be positive"}
          event.round_guess_count < 1 -> {:error, "round_guess_count must be positive"}
          event.total_guesses < 1 -> {:error, "total_guesses must be positive"}
          event.guess_duration < 0 -> {:error, "guess_duration must be non-negative"}
          # Validate match_score is present when guess is successful
          event.guess_successful and is_nil(event.match_score) ->
            {:error, "match_score is required when guess is successful"}
          # Validate match_score is nil when guess is not successful
          not event.guess_successful and not is_nil(event.match_score) ->
            {:error, "match_score must be nil when guess is not successful"}
          true -> :ok
        end
      end
    end

    def to_map(%__MODULE__{} = event) do
      %{
        "game_id" => event.game_id,
        "team_id" => event.team_id,
        "player1_info" => event.player1_info,
        "player2_info" => event.player2_info,
        "player1_word" => event.player1_word,
        "player2_word" => event.player2_word,
        "guess_successful" => event.guess_successful,
        "match_score" => event.match_score,
        "guess_count" => event.guess_count,
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "guild_id" => event.guild_id,
        "metadata" => event.metadata || %{},
        "round_number" => event.round_number,
        "round_guess_count" => event.round_guess_count,
        "total_guesses" => event.total_guesses,
        "guess_duration" => event.guess_duration
      }
    end

    def from_map(data) do
      %__MODULE__{
        game_id: data["game_id"],
        team_id: data["team_id"],
        player1_info: data["player1_info"],
        player2_info: data["player2_info"],
        player1_word: data["player1_word"],
        player2_word: data["player2_word"],
        guess_successful: data["guess_successful"],
        match_score: data["match_score"],
        guess_count: data["guess_count"],
        timestamp: GameBot.Domain.Events.GameEvents.parse_timestamp(data["timestamp"]),
        guild_id: data["guild_id"],
        metadata: data["metadata"] || %{},
        round_number: data["round_number"],
        round_guess_count: data["round_guess_count"],
        total_guesses: data["total_guesses"],
        guess_duration: data["guess_duration"]
      }
    end
  end
end
