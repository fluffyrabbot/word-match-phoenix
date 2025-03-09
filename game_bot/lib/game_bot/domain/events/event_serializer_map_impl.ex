defmodule GameBot.Domain.Events.EventSerializerMapImpl do
  @moduledoc """
  Implementation of the EventSerializer protocol for Map type.
  This allows maps to be used with the from_map/1 function, which is useful for tests.
  """

  alias GameBot.Domain.Events.{EventSerializer, EventStructure}

  # Implement EventSerializer for Map
  defimpl EventSerializer, for: Map do
    @doc """
    When using from_map with a Map, we need this special implementation
    to handle it properly for tests.

    This is a passthrough implementation that simply returns the original map.
    """
    def to_map(map) do
      # For to_map, we just return the map itself since it's already a map
      map
    end

    @doc """
    When dealing with maps directly in from_map, this handles conversion.
    This is primarily used in testing when we want to validate error cases
    without creating an actual struct instance first.
    """
    def from_map(data) do
      # For test purposes, construct a TestEvent struct
      # First, validate the data

      # Check timestamp format if present
      if Map.has_key?(data, "timestamp") do
        case data["timestamp"] do
          timestamp when is_binary(timestamp) ->
            case DateTime.from_iso8601(timestamp) do
              {:ok, _, _} -> :ok
              _ -> raise RuntimeError, "Invalid timestamp format: #{timestamp}"
            end
          _ -> :ok
        end
      end

      # Check mode if present
      if Map.has_key?(data, "mode") do
        case data["mode"] do
          mode when is_binary(mode) ->
            try do
              String.to_existing_atom(mode)
            rescue
              ArgumentError -> raise ArgumentError, "Invalid mode: #{mode}"
            end
          _ -> :ok
        end
      end

      # Convert the map to a TestEvent struct for test compatibility
      case Code.ensure_loaded(GameBot.Domain.Events.TestEvents.TestEvent) do
        {:module, _} ->
          %GameBot.Domain.Events.TestEvents.TestEvent{
            # Base fields
            game_id: data["game_id"],
            guild_id: data["guild_id"],
            mode: case data["mode"] do
              mode when is_binary(mode) -> String.to_existing_atom(mode)
              mode when is_atom(mode) -> mode
              _ -> nil
            end,
            timestamp: parse_timestamp(data["timestamp"]),
            metadata: data["metadata"],

            # Common test fields
            count: data["count"],
            score: data["score"],
            tags: (data["tags"] && MapSet.new(data["tags"])) || MapSet.new(),
            nested_data: process_nested_data(data["nested_data"]),
            optional_field: data["optional_field"],

            # GameStarted fields
            round_number: data["round_number"],
            teams: data["teams"],
            team_ids: data["team_ids"],
            player_ids: data["player_ids"],
            roles: data["roles"],
            config: data["config"],
            started_at: parse_timestamp(data["started_at"]),

            # GuessProcessed fields
            team_id: data["team_id"],
            player1_info: data["player1_info"],
            player2_info: data["player2_info"],
            player1_word: data["player1_word"],
            player2_word: data["player2_word"],
            guess_successful: data["guess_successful"],
            match_score: data["match_score"],
            guess_count: data["guess_count"],
            round_guess_count: data["round_guess_count"],
            total_guesses: data["total_guesses"],
            guess_duration: data["guess_duration"]
          }
        _ ->
          # If TestEvent module not available, just return the data map
          data
      end
    end

    defp parse_timestamp(nil), do: nil
    defp parse_timestamp(ts) when is_binary(ts) do
      case DateTime.from_iso8601(ts) do
        {:ok, dt, _offset} -> dt
        _ -> ts
      end
    end
    defp parse_timestamp(ts), do: ts

    defp process_nested_data(nil), do: nil
    defp process_nested_data(data) when is_map(data) do
      Enum.map(data, fn {k, v} -> {k, process_nested_data(v)} end)
      |> Map.new()
    end
    defp process_nested_data(data) when is_list(data) do
      Enum.map(data, &process_nested_data/1)
    end
    defp process_nested_data(data) when is_binary(data) do
      case DateTime.from_iso8601(data) do
        {:ok, dt, _offset} -> dt
        _ -> data
      end
    end
    defp process_nested_data(other), do: other
  end
end
