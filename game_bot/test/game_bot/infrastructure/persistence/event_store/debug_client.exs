defmodule GameBot.EventStoreDebugClient do
  @moduledoc """
  A simple debug client to directly test database operations
  """

  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres, as: EventStore
  alias GameBot.Infrastructure.Error

  def run do
    IO.puts("Starting debug client...")
    ensure_event_store_started()

    stream_id = "test-debug-#{:erlang.unique_integer([:positive])}"
    IO.puts("Using test stream ID: #{stream_id}")

    # Create a simple test event as a plain map
    event = %{
      stream_id: stream_id,
      event_type: "test_event",
      event_version: 1,
      data: %{debug: true, test_value: "hello"},
      metadata: %{source: "debug_client"}
    }

    # Try direct raw insert to debug
    IO.puts("\nAttempting direct database operations to debug...\n")
    try_direct_operations(event, stream_id)

    # Try to insert it using the adapter
    IO.puts("\nAttempting to append event to stream through adapter...\n")

    case EventStore.append_to_stream(stream_id, :no_stream, [event]) do
      {:ok, version} ->
        IO.puts("Success! Event appended. Stream version: #{version}")

        # Now try to read it back
        IO.puts("Attempting to read stream...")
        case EventStore.read_stream_forward(stream_id, 0, 100) do
          {:ok, read_events} ->
            IO.puts("Success! Read #{length(read_events)} events")
            IO.inspect(read_events, label: "Events")
          {:error, error} ->
            IO.puts("Error reading events: #{inspect(error)}")
        end

      {:error, %Error{details: details} = error} ->
        IO.puts("Error appending event through adapter: #{inspect(error)}")
        IO.puts("Error details: #{inspect(details)}")
    end
  end

  defp try_direct_operations(event, stream_id) do
    case EventStore.__adapter__() do
      adapter ->
        IO.puts("Found adapter: #{inspect(adapter)}")

        # Try a simple query to test the connection
        IO.puts("Testing connection with a simple query...")
        query_result = EventStore.query("SELECT 1 as test")
        IO.puts("Query result: #{inspect(query_result)}")

        # Try a direct transaction to see what fails
        IO.puts("Trying direct transaction...")
        tx_result = EventStore.transaction(fn ->
          # Create streams table entry first
          IO.puts("1. Inserting into streams table...")
          stream_insert_result = EventStore.query(
            "INSERT INTO event_store.streams (id, version) VALUES ($1, $2) ON CONFLICT (id) DO UPDATE SET version = EXCLUDED.version",
            [stream_id, 1]
          )
          IO.puts("Stream insert result: #{inspect(stream_insert_result)}")

          # Then try to insert the event
          IO.puts("2. Inserting into events table...")
          event_data = Poison.encode!(event.data)
          event_metadata = Poison.encode!(event.metadata)

          event_insert_result = EventStore.query(
            "INSERT INTO event_store.events (stream_id, event_type, event_data, event_metadata, event_version) VALUES ($1, $2, $3, $4, $5)",
            [stream_id, event.event_type, event_data, event_metadata, 1]
          )
          IO.puts("Event insert result: #{inspect(event_insert_result)}")

          {:ok, "Transaction completed successfully"}
        end)
        IO.puts("Transaction result: #{inspect(tx_result)}")

      error ->
        IO.puts("Could not get adapter: #{inspect(error)}")
    end
  end

  defp ensure_event_store_started do
    # Check if the EventStore is already started
    if Process.whereis(EventStore) == nil do
      IO.puts("EventStore not running, attempting to start...")

      # Configure the database connection
      config = [
        username: "postgres",
        password: "csstarahid",
        hostname: "localhost",
        database: "game_bot_eventstore_test",
        port: 5432,
        pool_size: 2,
        timeout: 5000,
        json_library: Jason
      ]

      case EventStore.start_link(config) do
        {:ok, _pid} ->
          IO.puts("EventStore started successfully")
        error ->
          IO.puts("Failed to start EventStore: #{inspect(error)}")
      end
    else
      IO.puts("EventStore already running")
    end
  end
end

GameBot.EventStoreDebugClient.run()
