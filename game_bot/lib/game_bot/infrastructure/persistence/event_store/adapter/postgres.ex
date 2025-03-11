defmodule GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres do
  @moduledoc """
  PostgreSQL implementation of the event store adapter.

  This module provides a concrete implementation of the event store adapter
  using PostgreSQL as the storage backend. It includes:
  - Event stream operations
  - Optimistic concurrency control
  - Subscription management
  - Error handling
  - Telemetry integration
  """

  use GameBot.Infrastructure.Persistence.EventStore.Adapter.Base,
    serializer: GameBot.Infrastructure.Persistence.EventStore.Serialization.JsonSerializer

  use Ecto.Repo,
    otp_app: :game_bot,
    adapter: Ecto.Adapters.Postgres

  alias GameBot.Infrastructure.Error
  alias GameBot.Infrastructure.Persistence.EventStore.Serialization.JsonSerializer

  # Fixed operational parameters
  @table_prefix "event_store"
  @max_batch_size 100

  @streams_table "#{@table_prefix}.streams"
  @events_table "#{@table_prefix}.events"
  @subscriptions_table "#{@table_prefix}.subscriptions"

  @impl Ecto.Repo
  def init(_type, config) do
    {:ok, config}
  end

  # Private implementation functions called by Base adapter

  defp do_append_to_stream(stream_id, expected_version, events, opts) do
    require Logger
    Logger.debug("do_append_to_stream called with stream_id: #{inspect(stream_id)}, expected_version: #{inspect(expected_version)}, events: #{inspect(events)}")

    if length(events) > @max_batch_size do
      {:error, Error.validation_error(__MODULE__, "Batch size exceeds maximum", %{
        max: @max_batch_size,
        actual: length(events)
      })}
    else
      case transaction(fn ->
        Logger.debug("Inside transaction for stream_id: #{inspect(stream_id)}")
        with {:ok, actual_version} <- get_stream_version(stream_id),
             _ = Logger.debug("Got stream version: #{inspect(actual_version)}"),
             :ok <- validate_expected_version(actual_version, expected_version),
             _ = Logger.debug("Validated expected version"),
             {:ok, new_version} <- append_events(stream_id, actual_version, events) do
          Logger.debug("Successfully appended events, new version: #{inspect(new_version)}")
          {:ok, new_version}
        else
          error ->
            Logger.error("Error in do_append_to_stream transaction: #{inspect(error)}")
            error
        end
      end, opts) do
        {:ok, result} -> result
        {:error, error} -> {:error, error}
      end
    end
  end

  defp do_read_stream_forward(stream_id, start_version, count, opts) do
    count = min(count, @max_batch_size)
    case get_stream_version(stream_id) do
      {:ok, 0} ->
        {:error, Error.not_found_error(__MODULE__, "Stream not found", stream_id)}
      {:ok, _version} ->
        query = """
        SELECT event_id, event_type, event_data, event_metadata, event_version
        FROM #{@events_table}
        WHERE stream_id = $1 AND event_version >= $2
        ORDER BY event_version ASC
        LIMIT $3
        """
        case query(query, [stream_id, start_version, count], opts) do
          {:ok, %{rows: rows}} ->
            {:ok, Enum.map(rows, &(row_to_event(&1, stream_id)))}
          {:error, %Postgrex.Error{postgres: %{code: :undefined_table}}} ->
            {:error, Error.not_found_error(__MODULE__, "Stream not found", stream_id)}
          {:error, error} ->
            {:error, Error.system_error(__MODULE__, "Database error", error)}
        end
    end
  end

  defp do_stream_version(stream_id, opts) do
    query = "SELECT version FROM #{@streams_table} WHERE id = $1"

    case query(query, [stream_id], opts) do
      {:ok, %{rows: [[version]]}} ->
        {:ok, version}
      {:ok, %{rows: []}} ->
        {:ok, 0}
      {:error, error} ->
        {:error, Error.system_error(__MODULE__, "Database error", error)}
    end
  end

  defp do_subscribe_to_stream(stream_id, subscriber, subscription_options, opts) do
    query = """
    INSERT INTO #{@subscriptions_table} (stream_id, subscriber_pid, options)
    VALUES ($1, $2, $3)
    RETURNING id
    """

    subscription_options = if is_list(subscription_options), do: Map.new(subscription_options), else: subscription_options
    subscriber_value = if is_pid(subscriber), do: :erlang.pid_to_list(subscriber), else: subscriber
    case query(query, [stream_id, subscriber_value, subscription_options], opts) do
      {:ok, %{rows: [[id]]}} ->
        if is_pid(subscriber) do
          {:ok, id}
        else
          {:ok, make_ref()}
        end
      {:error, %Postgrex.Error{postgres: %{code: :foreign_key_violation}}} ->
        {:error, Error.not_found_error(__MODULE__, "Stream not found", stream_id)}
      {:error, error} ->
        {:error, Error.system_error(__MODULE__, "Database error", error)}
    end
  end

  defp do_delete_stream(stream_id, expected_version, opts \\ []) do
    # The Base adapter's with_telemetry function expects either {:ok, result} or {:error, reason}
    # But the delete_stream function in the Behaviour expects :ok or {:error, reason}
    # So we need to handle this conversion carefully

    # First check if the stream exists
    case get_stream_version(stream_id, opts) do
      # Stream doesn't exist
      {:ok, 0} ->
        # For non-existent streams, we should always return a not_found error
        # This matches the test expectation
        {:error, Error.not_found_error(__MODULE__, "Stream not found", stream_id)}

      # Stream exists
      {:ok, actual_version} ->
        # Validate expected version
        case validate_expected_version(actual_version, expected_version) do
          :ok ->
            # Delete the stream data
            case delete_stream_data(stream_id, opts) do
              :ok -> {:ok, :ok}  # Wrap :ok in {:ok, :ok} for the Base adapter
              {:error, reason} -> {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end

      # Error getting stream version
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Helper functions

  defp prepare_events(stream_id, events) when is_list(events) do
    prepared = Enum.map(events, fn event ->
      case event do
        %{stream_id: _} ->
          # Already has atom stream_id, remove any string version to avoid duplicates
          Map.delete(event, "stream_id")
        %{"stream_id" => _} ->
          # Already has string stream_id, convert to atom version
          event
          |> Map.delete("stream_id")
          |> Map.put(:stream_id, stream_id)
        _ when is_map(event) ->
          # No stream_id, add it
          Map.put(event, :stream_id, stream_id)
        _ ->
          # Not a map, can't add stream_id
          event
      end
    end)
    {:ok, prepared}
  end

  defp prepare_events(_stream_id, events) do
    {:error, Error.validation_error(__MODULE__, "Events must be a list", events)}
  end

  defp serialize_events(events) when is_list(events) do
    events
    |> Enum.reduce_while({:ok, []}, fn event, {:ok, acc} ->
      case JsonSerializer.serialize(event) do
        {:ok, serialized} -> {:cont, {:ok, [serialized | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, serialized} -> {:ok, Enum.reverse(serialized)}
      error -> error
    end
  end

  defp get_stream_version(stream_id) do
    query = "SELECT version FROM #{@streams_table} WHERE id = $1"

    case query(query, [stream_id]) do
      {:ok, %{rows: [[version]]}} ->
        {:ok, version}
      {:ok, %{rows: []}} ->
        {:ok, 0}
      {:error, error} ->
        {:error, Error.system_error(__MODULE__, "Database error", error)}
    end
  end

  defp validate_expected_version(actual_version, expected_version) do
    # Convert tuple form to actual value if necessary
    expected = case expected_version do
      {:ok, version} when is_integer(version) -> version
      _ -> expected_version
    end

    cond do
      expected == :any ->
        :ok
      expected == :no_stream and actual_version == 0 ->
        :ok
      expected == :stream_exists and actual_version > 0 ->
        :ok
      expected == actual_version ->
        :ok
      true ->
        {:error, Error.concurrency_error(__MODULE__, "Wrong expected version", %{
          expected: expected,
          actual: actual_version
        })}
    end
  end

  defp append_events(stream_id, current_version, events) do
    events_with_version = Enum.with_index(events, current_version + 1)

    insert_events_query = """
    INSERT INTO #{@events_table}
    (stream_id, event_type, event_data, event_metadata, event_version)
    VALUES
    #{build_events_values(length(events))}
    """

    update_stream_query = """
    INSERT INTO #{@streams_table} (id, version)
    VALUES ($1, $2)
    ON CONFLICT (id) DO UPDATE
    SET version = EXCLUDED.version
    """

    new_version = current_version + length(events)
    try do
      event_params = flatten_event_params_for_insertion(events_with_version)
      stream_params = [stream_id, new_version]

      # Change the order: first create/update the stream, then insert events
      with {:ok, _} <- query(update_stream_query, stream_params),
           {:ok, _} <- query(insert_events_query, event_params) do
        {:ok, new_version}
      else
        {:error, error} ->
          # Log the error for debugging
          require Logger
          Logger.error("Error in append_events: #{inspect(error)}")
          Logger.error("Stream ID: #{inspect(stream_id)}")
          Logger.error("Events: #{inspect(events)}")

          # Return a more specific error
          {:error, Error.system_error(__MODULE__, "Failed to append events", error)}
      end
    rescue
      e ->
        # Log the error for debugging
        require Logger
        Logger.error("Error in append_events: #{inspect(e)}")
        Logger.error("Stream ID: #{inspect(stream_id)}")
        Logger.error("Events: #{inspect(events)}")

        # Return a more specific error
        {:error, Error.system_error(__MODULE__, "Unexpected exception: #{Exception.message(e)}", e)}
    end
  end

  defp delete_stream_data(stream_id) do
    # Simple implementation that directly executes the DELETE statements
    delete_events_query = "DELETE FROM #{@events_table} WHERE stream_id = $1"
    delete_stream_query = "DELETE FROM #{@streams_table} WHERE id = $1"

    # Use a transaction to ensure both operations succeed or fail together
    try do
      case transaction(fn ->
        # Delete events first
        case query(delete_events_query, [stream_id]) do
          {:ok, _} ->
            # Then delete the stream
            case query(delete_stream_query, [stream_id]) do
              {:ok, _} -> :ok
              {:error, error} -> {:error, Error.system_error(__MODULE__, "Failed to delete stream", error)}
            end
          {:error, error} -> {:error, Error.system_error(__MODULE__, "Failed to delete events", error)}
        end
      end) do
        {:ok, :ok} -> :ok
        {:ok, {:error, reason}} -> {:error, reason}
        :ok -> :ok
        {:error, reason} -> {:error, reason}
      end
    rescue
      e ->
        require Logger
        Logger.error("Unexpected error in delete_stream_data: #{inspect(e)}")
        {:error, Error.system_error(__MODULE__, "Unexpected exception in delete_stream_data", e)}
    end
  end

  defp build_events_values(count) do
    1..count
    |> Enum.map(fn i ->
      index = (i - 1) * 5
      "($#{index + 1}, $#{index + 2}, $#{index + 3}, $#{index + 4}, $#{index + 5})"
    end)
    |> Enum.join(",\n")
  end

  defp flatten_event_params_for_insertion(events_with_version) do
    Enum.flat_map(events_with_version, fn {event, version} ->
      [
        Map.get(event, :stream_id) || Map.get(event, "stream_id"),
        Map.get(event, :event_type) || Map.get(event, "event_type") || Map.get(event, :type) || Map.get(event, "type"),
        Map.get(event, :data) || Map.get(event, "data"),
        Map.get(event, :metadata) || Map.get(event, "metadata"),
        version
      ]
    end)
  end

  defp row_to_event([event_id, event_type, event_data, event_metadata, event_version], stream_id) do
    # Create a map with atom keys for dot notation access
    atom_map = %{
      event_id: event_id,
      stream_id: stream_id,
      event_type: event_type,
      type: event_type,
      data: event_data,
      metadata: event_metadata,
      version: event_version
    }

    # Create a map with string keys for JSON serializer
    string_map = %{
      "event_id" => event_id,
      "stream_id" => stream_id,
      "event_type" => event_type,
      "type" => event_type,
      "data" => event_data,
      "metadata" => event_metadata,
      "version" => event_version
    }

    # Merge both maps to support both access patterns
    Map.merge(atom_map, string_map)
  end
end
