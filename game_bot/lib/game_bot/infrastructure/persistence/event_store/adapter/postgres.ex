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

  use GameBot.Infrastructure.Persistence.EventStore.Adapter.Base
  use Ecto.Repo,
    otp_app: :game_bot,
    adapter: Ecto.Adapters.Postgres

  alias GameBot.Infrastructure.Error

  @typep conn :: DBConnection.conn()
  @typep query :: Postgrex.Query.t()
  @typep stream_version :: non_neg_integer()

  # Fixed operational parameters
  @table_prefix "event_store"
  @max_batch_size 100

  @streams_table "#{@table_prefix}.streams"
  @events_table "#{@table_prefix}.events"
  @subscriptions_table "#{@table_prefix}.subscriptions"

  @impl Ecto.Repo
  def init(config) do
    {:ok, config}
  end

  # Private implementation functions called by Base adapter

  defp do_append_to_stream(stream_id, expected_version, events, opts) do
    if length(events) > @max_batch_size do
      {:error, Error.validation_error(__MODULE__, "Batch size exceeds maximum", %{
        max: @max_batch_size,
        actual: length(events)
      })}
    else
      transaction(fn ->
        with {:ok, actual_version} <- get_stream_version(stream_id),
             :ok <- validate_expected_version(actual_version, expected_version),
             {:ok, new_version} <- append_events(stream_id, actual_version, events) do
          {:ok, new_version}
        end
      end, opts)
    end
  end

  defp do_read_stream_forward(stream_id, start_version, count, opts) do
    count = min(count, @max_batch_size)
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

    case query(query, [stream_id, :erlang.pid_to_list(subscriber), subscription_options], opts) do
      {:ok, %{rows: [[id]]}} ->
        {:ok, id}
      {:error, %Postgrex.Error{postgres: %{code: :foreign_key_violation}}} ->
        {:error, Error.not_found_error(__MODULE__, "Stream not found", stream_id)}
      {:error, error} ->
        {:error, Error.system_error(__MODULE__, "Database error", error)}
    end
  end

  defp do_delete_stream(stream_id, expected_version, opts) do
    IO.puts("DEBUG: do_delete_stream called for stream #{stream_id} with expected version #{inspect(expected_version)}")

    transaction(fn ->
      with {:ok, actual_version} <- get_stream_version(stream_id),
           :ok <- validate_expected_version(actual_version, expected_version),
           result <- delete_stream_data(stream_id) do

        # Log the result before returning
        IO.puts("DEBUG: delete_stream_data result: #{inspect(result)}")

        case result do
          :ok -> :ok  # Return just :ok as specified in the behaviour
          {:ok, _} -> :ok  # If we get a nested OK, still return :ok
          {:error, error} -> {:error, error}
          unexpected ->
            {:error, Error.system_error(__MODULE__, "Unexpected result from delete_stream_data", unexpected)}
        end
      end
    end, opts)
  end

  # Helper functions

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

    # Debug log
    IO.puts("DEBUG: Attempting to append #{length(events)} events to stream #{stream_id}")
    IO.puts("DEBUG: First event: #{inspect(hd(events), pretty: true)}")

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
    event_params = flatten_event_params_for_insertion(events_with_version)

    # Debug log
    IO.puts("DEBUG: Flattened event params: #{inspect(event_params, pretty: true)}")

    stream_params = [stream_id, new_version]

    # Change the order: first create/update the stream, then insert events
    with {:ok, result1} <- query(update_stream_query, stream_params),
         {:ok, result2} <- query(insert_events_query, event_params) do
      IO.puts("DEBUG: Successfully inserted events. Results: #{inspect(result1)}, #{inspect(result2)}")
      {:ok, new_version}
    else
      {:error, error} ->
        IO.puts("DEBUG: Error appending events: #{inspect(error, pretty: true)}")
        error_details = case error do
          %Postgrex.Error{} = pg_error ->
            "Postgres error: #{inspect(pg_error.postgres)}"
          other ->
            "Other error: #{inspect(other)}"
        end
        IO.puts("DEBUG: Error details: #{error_details}")
        {:error, Error.system_error(__MODULE__, "Failed to append events", error)}
    end
  end

  defp delete_stream_data(stream_id) do
    delete_events_query = "DELETE FROM #{@events_table} WHERE stream_id = $1"
    delete_stream_query = "DELETE FROM #{@streams_table} WHERE id = $1"

    IO.puts("DEBUG: Deleting stream #{stream_id}")

    # No transaction wrapper here since do_delete_stream already has one
    with {:ok, events_result} <- query(delete_events_query, [stream_id]),
         deleted_events = events_result.num_rows,
         {:ok, stream_result} <- query(delete_stream_query, [stream_id]),
         deleted_streams = stream_result.num_rows do

      IO.puts("DEBUG: Delete results - Events: #{deleted_events}, Stream: #{deleted_streams}")

      if deleted_events > 0 || deleted_streams > 0 do
        :ok
      else
        IO.puts("DEBUG: No records found to delete for stream #{stream_id}")
        {:error, Error.not_found_error(__MODULE__, "Stream not found", stream_id)}
      end
    else
      {:error, error} ->
        IO.puts("DEBUG: Error deleting stream: #{inspect(error)}")
        {:error, Error.system_error(__MODULE__, "Failed to delete stream", error)}
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
      # Get event_type from available keys, checking both atoms and strings
      event_type = cond do
        # Check atom keys
        Map.has_key?(event, :event_type) -> Map.get(event, :event_type)
        Map.has_key?(event, :type) -> Map.get(event, :type)
        # Check string keys
        Map.has_key?(event, "event_type") -> Map.get(event, "event_type")
        Map.has_key?(event, "type") -> Map.get(event, "type")
        true ->
          raise "Event is missing both :event_type and :type keys: #{inspect(event)}"
      end

      # Get stream_id from available keys, checking both atoms and strings
      stream_id = cond do
        Map.has_key?(event, :stream_id) -> Map.get(event, :stream_id)
        Map.has_key?(event, "stream_id") -> Map.get(event, "stream_id")
        true -> raise "Event is missing stream_id: #{inspect(event)}"
      end

      # Get data safely, with fallbacks
      data = cond do
        Map.has_key?(event, :data) -> Map.get(event, :data)
        Map.has_key?(event, "data") -> Map.get(event, "data")
        true -> %{}
      end

      # Get metadata safely, with fallbacks
      metadata = cond do
        Map.has_key?(event, :metadata) -> Map.get(event, :metadata)
        Map.has_key?(event, "metadata") -> Map.get(event, "metadata")
        true -> %{}
      end

      # Convert data and metadata to JSON strings
      data_json = Jason.encode!(data)
      metadata_json = Jason.encode!(metadata)

      [
        stream_id,
        event_type,
        data_json,
        metadata_json,
        version
      ]
    end)
  end

  defp row_to_event([id, type, data, metadata, version], stream_id) do
    # Decode JSON data and metadata
    decoded_data = case Jason.decode(data) do
      {:ok, decoded} -> decoded
      _ -> %{}
    end

    decoded_metadata = case Jason.decode(metadata) do
      {:ok, decoded} -> decoded
      _ -> %{}
    end

    %{
      "id" => id,
      "type" => type,
      "data" => decoded_data,
      "metadata" => decoded_metadata,
      "version" => version,
      "stream_id" => stream_id
    }
  end

  # Ensure that events have a stream_id field without duplicating keys
  defp prepare_events(stream_id, events) when is_list(events) do
    prepared = Enum.map(events, fn event ->
      # For maps (including structs), ensure stream_id exists, but avoid duplicates
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

  defp serialize_events(events) do
    # This function should be implemented to serialize events to a format suitable for storage
    # For example, you can use Jason to serialize events to JSON
    {:ok, Jason.encode!(events)}
  end
end
