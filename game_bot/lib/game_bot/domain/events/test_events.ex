defmodule GameBot.Domain.Events.TestEvents do
  @moduledoc """
  Test event implementations for use in tests.
  These ensure consistent event structures for testing serialization and other event functionality.
  """

  alias GameBot.Domain.Events.{EventSerializer, EventStructure, Metadata}

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
      :optional_field
    ]
  end

  # Implement the EventSerializer protocol for TestEvent
  defimpl EventSerializer, for: TestEvent do
    def to_map(event) do
      %{
        "game_id" => event.game_id,
        "guild_id" => event.guild_id,
        "mode" => Atom.to_string(event.mode),
        "timestamp" => EventStructure.to_iso8601(event.timestamp),
        "metadata" => event.metadata,
        "count" => event.count,
        "score" => event.score,
        "tags" => tags_to_list(event.tags),
        "nested_data" => serialize_nested(event.nested_data),
        "optional_field" => event.optional_field
      }
    end

    def from_map(data) do
      %TestEvent{
        game_id: data["game_id"],
        guild_id: data["guild_id"],
        mode: String.to_existing_atom(data["mode"]),
        timestamp: EventStructure.parse_timestamp(data["timestamp"]),
        metadata: data["metadata"],
        count: data["count"],
        score: data["score"],
        tags: MapSet.new(data["tags"] || []),
        nested_data: deserialize_nested(data["nested_data"]),
        optional_field: data["optional_field"]
      }
    end

    defp serialize_nested(nil), do: nil
    defp serialize_nested(%DateTime{} = dt), do: EventStructure.to_iso8601(dt)
    defp serialize_nested(data) when is_map(data) do
      data
      |> Enum.map(fn {k, v} -> {to_string(k), serialize_nested(v)} end)
      |> Map.new()
    end
    defp serialize_nested(data) when is_list(data) do
      Enum.map(data, &serialize_nested/1)
    end
    defp serialize_nested(other), do: other

    defp deserialize_nested(nil), do: nil
    defp deserialize_nested(data) when is_map(data) do
      Enum.map(data, fn {k, v} -> {k, deserialize_nested(v)} end)
      |> Map.new()
    end
    defp deserialize_nested(data) when is_list(data) do
      Enum.map(data, &deserialize_nested/1)
    end
    defp deserialize_nested(data) when is_binary(data) do
      case DateTime.from_iso8601(data) do
        {:ok, dt, _} -> dt
        _ -> data
      end
    end
    defp deserialize_nested(other), do: other

    defp tags_to_list(nil), do: []
    defp tags_to_list(tags), do: MapSet.to_list(tags)
  end

  @doc """
  Creates a test event with the given options.

  ## Parameters
    * `opts` - Keyword list of options to override defaults

  ## Returns
    * `%TestEvent{}` - A test event with the specified options
  """
  def create_test_event(opts \\ []) do
    # Default timestamp to ensure consistency
    timestamp = Keyword.get(opts, :timestamp, ~U[2023-01-01 12:00:00Z])

    # Create a basic metadata structure if none provided
    metadata = Keyword.get(opts, :metadata, %{
      server_version: "0.1.0",
      guild_id: "guild_id",
      correlation_id: "correlation_id",
      source_id: "1234",
      actor_id: "1234"
    })

    %TestEvent{
      game_id: Keyword.get(opts, :game_id, "game-123"),
      guild_id: Keyword.get(opts, :guild_id, "guild-123"),
      mode: Keyword.get(opts, :mode, :knockout),
      timestamp: timestamp,
      metadata: metadata,
      count: Keyword.get(opts, :count, 42),
      score: Keyword.get(opts, :score, -10),
      tags: Keyword.get(opts, :tags, MapSet.new(["tag1", "tag2"])),
      nested_data: Keyword.get(opts, :nested_data, %{
        "key" => "value",
        "list" => [1, 2, 3],
        "nested" => %{"inner" => "value"},
        "time" => ~U[2023-01-01 12:00:00Z]
      }),
      optional_field: Keyword.get(opts, :optional_field, nil)
    }
  end
end
