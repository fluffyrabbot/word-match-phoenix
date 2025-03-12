defmodule GameBot.Domain.Events.Serializers do
  @moduledoc """
  Protocol implementations for EventSerializer for various game events.
  """

  alias GameBot.Domain.Events.EventSerializer
  alias GameBot.Domain.Events.GameEvents
  alias GameBot.Domain.Events.GameEvents.{GuessProcessed, GameStarted}

  defimpl EventSerializer, for: GuessProcessed do
    def to_map(%GuessProcessed{} = event) do
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
        "match_score" => event.match_score,
        "guess_count" => event.guess_count,
        "round_guess_count" => event.round_guess_count,
        "total_guesses" => event.total_guesses,
        "guess_duration" => event.guess_duration,
        "player1_duration" => event.player1_duration,
        "player2_duration" => event.player2_duration,
        "timestamp" => DateTime.to_iso8601(event.timestamp),
        "metadata" => event.metadata || %{}
      }
    end

    def from_map(data) do
      %GuessProcessed{
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
        timestamp: GameEvents.parse_timestamp(data["timestamp"]),
        metadata: data["metadata"] || %{}
      }
    end
  end

  defimpl EventSerializer, for: GameStarted do
    def to_map(%GameStarted{} = event) do
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

    def from_map(data) do
      %GameStarted{
        game_id: data["game_id"],
        guild_id: data["guild_id"],
        mode: String.to_existing_atom(data["mode"]),
        round_number: data["round_number"],
        teams: data["teams"],
        team_ids: data["team_ids"],
        player_ids: data["player_ids"],
        config: data["config"],
        started_at: GameEvents.parse_timestamp(data["started_at"]),
        timestamp: GameEvents.parse_timestamp(data["timestamp"]),
        metadata: data["metadata"] || %{}
      }
    end
  end
end
