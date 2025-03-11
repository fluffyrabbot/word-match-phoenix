defmodule GameBot.Domain.Events.TestEvents do
  @moduledoc """
  Test event implementations for use in tests.
  """

  defmodule TestEvent do
    @moduledoc "Test event struct for serialization tests"
    defstruct [
      :game_id,
      :guild_id,
      :mode,
      :timestamp,
      :metadata,
      :count,
      :score,
      :tags,
      :nested_data,
      :optional_field,
      :round_number,
      :teams,
      :team_ids,
      :player_ids,
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
      :config,
      :started_at,
      :roles,
      :team_id
    ]
  end

  # Basic create_test_event function
  def create_test_event(opts \\ []) do
    %TestEvent{
      game_id: Keyword.get(opts, :game_id, "game-123"),
      guild_id: Keyword.get(opts, :guild_id, "guild-123"),
      mode: Keyword.get(opts, :mode, :knockout),
      timestamp: Keyword.get(opts, :timestamp, ~U[2023-01-01 12:00:00Z]),
      metadata: Keyword.get(opts, :metadata, %{}),
      count: Keyword.get(opts, :count, 42),
      score: Keyword.get(opts, :score, -10),
      tags: Keyword.get(opts, :tags, MapSet.new(["tag1", "tag2"])),
      nested_data: Keyword.get(opts, :nested_data, %{}),
      optional_field: Keyword.get(opts, :optional_field),
      round_number: Keyword.get(opts, :round_number, 1),
      teams: Keyword.get(opts, :teams, %{"team1" => ["player1", "player2"], "team2" => ["player3", "player4"]}),
      team_ids: Keyword.get(opts, :team_ids, ["team1", "team2"]),
      player_ids: Keyword.get(opts, :player_ids, ["player1", "player2", "player3", "player4"]),
      player1_info: Keyword.get(opts, :player1_info, %{player_id: "player1", team_id: "team1"}),
      player2_info: Keyword.get(opts, :player2_info, %{player_id: "player2", team_id: "team1"}),
      player1_word: Keyword.get(opts, :player1_word, "word1"),
      player2_word: Keyword.get(opts, :player2_word, "word2"),
      guess_successful: Keyword.get(opts, :guess_successful, true),
      match_score: Keyword.get(opts, :match_score, 10),
      guess_count: Keyword.get(opts, :guess_count, 1),
      round_guess_count: Keyword.get(opts, :round_guess_count, 1),
      total_guesses: Keyword.get(opts, :total_guesses, 1),
      guess_duration: Keyword.get(opts, :guess_duration, 1000),
      config: Keyword.get(opts, :config, %{round_limit: 10, time_limit: 300, score_limit: 100}),
      started_at: Keyword.get(opts, :started_at, DateTime.utc_now()),
      roles: Keyword.get(opts, :roles, %{}),
      team_id: Keyword.get(opts, :team_id, "team1")
    }
  end
end

# Implement EventValidator for TestEvent
defimpl GameBot.Domain.Events.EventValidator, for: GameBot.Domain.Events.TestEvents.TestEvent do
  def validate(event) do
    with :ok <- validate_base_fields(event),
         :ok <- validate_event_specific_fields(event) do
      :ok
    end
  end

  # Validate base fields that all events should have
  defp validate_base_fields(event) do
    cond do
      is_nil(event.game_id) -> {:error, "game_id is required"}
      is_nil(event.guild_id) -> {:error, "guild_id is required"}
      is_nil(event.mode) -> {:error, "mode is required"}
      is_nil(event.timestamp) -> {:error, "timestamp is required"}
      is_nil(event.metadata) -> {:error, "metadata is required"}
      !is_map(event.metadata) -> {:error, "metadata must be a map"}
      true -> :ok
    end
  end

  # Validate fields specific to the event type (based on what fields are set)
  defp validate_event_specific_fields(event) do
    cond do
      # If it has teams, team_ids, player_ids - treat it like a GameStarted event
      event.teams != nil and event.team_ids != nil and event.player_ids != nil ->
        validate_game_started_fields(event)

      # If it has player1_info, player2_info, player1_word - treat it like a GuessProcessed event
      event.player1_info != nil and event.player2_info != nil and event.player1_word != nil ->
        validate_guess_processed_fields(event)

      # Generic validation for any other case
      true -> :ok
    end
  end

  # GameStarted validation
  defp validate_game_started_fields(event) do
    with :ok <- validate_teams_structure(event),
         :ok <- validate_team_ids(event),
         :ok <- validate_player_ids(event) do
      :ok
    end
  end

  defp validate_teams_structure(event) do
    cond do
      !is_map(event.teams) ->
        {:error, "teams must be a map"}

      # Check for any team with empty player list
      Enum.any?(event.teams, fn {_, players} ->
        is_list(players) and Enum.empty?(players)
      end) ->
        {:error, "Each team must have at least one player"}

      # Check that all player IDs are strings
      Enum.any?(event.teams, fn {_, players} ->
        is_list(players) and Enum.any?(players, fn p -> !is_binary(p) end)
      end) ->
        {:error, "Player IDs must be strings"}

      true -> :ok
    end
  end

  defp validate_team_ids(event) do
    cond do
      !is_list(event.team_ids) -> {:error, "team_ids must be a list"}
      Enum.empty?(event.team_ids) -> {:error, "team_ids cannot be empty"}
      true -> :ok
    end
  end

  defp validate_player_ids(event) do
    cond do
      !is_list(event.player_ids) -> {:error, "player_ids must be a list"}
      Enum.empty?(event.player_ids) -> {:error, "player_ids cannot be empty"}
      true -> :ok
    end
  end

  # GuessProcessed validation
  defp validate_guess_processed_fields(event) do
    with :ok <- validate_player_info(event),
         :ok <- validate_word_fields(event),
         :ok <- validate_guess_metrics(event),
         :ok <- validate_match_score(event) do
      :ok
    end
  end

  defp validate_player_info(event) do
    cond do
      !is_map(event.player1_info) -> {:error, "player1_info must be a map"}
      !is_map(event.player2_info) -> {:error, "player2_info must be a map"}
      is_nil(event.player1_info[:player_id]) -> {:error, "player1_info must contain player_id"}
      is_nil(event.player2_info[:player_id]) -> {:error, "player2_info must contain player_id"}
      true -> :ok
    end
  end

  defp validate_word_fields(event) do
    cond do
      !is_binary(event.player1_word) -> {:error, "player1_word must be a string"}
      !is_binary(event.player2_word) -> {:error, "player2_word must be a string"}
      true -> :ok
    end
  end

  defp validate_guess_metrics(event) do
    cond do
      !is_integer(event.guess_count) or event.guess_count <= 0 ->
        {:error, "guess_count must be a positive integer"}
      !is_integer(event.round_guess_count) or event.round_guess_count <= 0 ->
        {:error, "round_guess_count must be a positive integer"}
      !is_integer(event.total_guesses) or event.total_guesses <= 0 ->
        {:error, "total_guesses must be a positive integer"}
      !is_integer(event.guess_duration) or event.guess_duration < 0 ->
        {:error, "guess_duration must be a non-negative integer"}
      true -> :ok
    end
  end

  defp validate_match_score(event) do
    cond do
      event.guess_successful == true and (is_nil(event.match_score) or event.match_score <= 0) ->
        {:error, "match_score must be positive for successful guesses"}
      event.guess_successful == false and !is_nil(event.match_score) ->
        {:error, "match_score must be nil for unsuccessful guesses"}
      true -> :ok
    end
  end
end

# Implement EventSerializer for TestEvent
defimpl GameBot.Domain.Events.EventSerializer, for: GameBot.Domain.Events.TestEvents.TestEvent do
  def to_map(event) do
    %{
      "game_id" => event.game_id,
      "guild_id" => event.guild_id,
      "mode" => if(is_atom(event.mode), do: Atom.to_string(event.mode), else: event.mode),
      "timestamp" => DateTime.to_iso8601(event.timestamp),
      "metadata" => event.metadata,
      "count" => event.count,
      "score" => event.score,
      "tags" => if(is_nil(event.tags), do: [], else: MapSet.to_list(event.tags)),
      "nested_data" => serialize_nested(event.nested_data),
      "optional_field" => event.optional_field,
      "round_number" => event.round_number,
      "teams" => event.teams,
      "team_ids" => event.team_ids,
      "player_ids" => event.player_ids,
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
      "config" => event.config,
      "started_at" => if(is_nil(event.started_at), do: nil, else: DateTime.to_iso8601(event.started_at)),
      "roles" => event.roles,
      "team_id" => event.team_id
    }
  end

  def from_map(data) do
    %GameBot.Domain.Events.TestEvents.TestEvent{
      game_id: data["game_id"],
      guild_id: data["guild_id"],
      mode: parse_mode(data["mode"]),
      timestamp: parse_timestamp(data["timestamp"]),
      metadata: data["metadata"],
      count: data["count"],
      score: data["score"],
      tags: if(is_nil(data["tags"]) or Enum.empty?(data["tags"]), do: MapSet.new([]), else: MapSet.new(data["tags"])),
      nested_data: deserialize_nested(data["nested_data"]),
      optional_field: data["optional_field"],
      round_number: data["round_number"],
      teams: data["teams"],
      team_ids: data["team_ids"],
      player_ids: data["player_ids"],
      player1_info: data["player1_info"],
      player2_info: data["player2_info"],
      player1_word: data["player1_word"],
      player2_word: data["player2_word"],
      guess_successful: data["guess_successful"],
      match_score: data["match_score"],
      guess_count: data["guess_count"],
      round_guess_count: data["round_guess_count"],
      total_guesses: data["total_guesses"],
      guess_duration: data["guess_duration"],
      config: data["config"],
      started_at: parse_timestamp(data["started_at"]),
      roles: data["roles"],
      team_id: data["team_id"]
    }
  end

  # Helper for serializing nested data structures
  defp serialize_nested(nil), do: nil
  defp serialize_nested(data) when is_map(data) do
    Enum.reduce(data, %{}, fn {k, v}, acc ->
      Map.put(acc, k, serialize_value(v))
    end)
  end
  defp serialize_nested(data), do: data

  defp serialize_value(value) when is_struct(value) and value.__struct__ == DateTime do
    DateTime.to_iso8601(value)
  end
  defp serialize_value(value) when is_list(value) do
    Enum.map(value, &serialize_value/1)
  end
  defp serialize_value(value) when is_map(value) do
    serialize_nested(value)
  end
  defp serialize_value(value), do: value

  # Helper for deserializing nested data structures
  defp deserialize_nested(nil), do: nil
  defp deserialize_nested(data) when is_map(data) do
    Enum.reduce(data, %{}, fn {k, v}, acc ->
      Map.put(acc, k, deserialize_value(v))
    end)
  end
  defp deserialize_nested(data), do: data

  defp deserialize_value(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> datetime
      _ -> value
    end
  end
  defp deserialize_value(value) when is_list(value) do
    Enum.map(value, &deserialize_value/1)
  end
  defp deserialize_value(value) when is_map(value) do
    deserialize_nested(value)
  end
  defp deserialize_value(value), do: value

  # Helper for parsing mode string to atom
  defp parse_mode(nil), do: nil
  defp parse_mode(mode) when is_atom(mode), do: mode
  defp parse_mode(mode) when is_binary(mode) do
    String.to_existing_atom(mode)
  end

  # Helper for parsing timestamp
  defp parse_timestamp(nil), do: nil
  defp parse_timestamp(timestamp) when is_struct(timestamp, DateTime), do: timestamp
  defp parse_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, datetime, _} -> datetime
      _ -> raise "Invalid timestamp format: #{timestamp}"
    end
  end
end
