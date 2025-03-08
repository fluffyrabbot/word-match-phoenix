defmodule Mix.Tasks.GameBot.TestDb do
  @moduledoc """
  Tests database access and EventStore functionality directly.

  ## Examples

      mix game_bot.test_db

  """
  use Mix.Task

  @shortdoc "Tests database access"
  def run(_) do
    # Start required applications
    IO.puts("Starting applications...")
    {:ok, _} = Application.ensure_all_started(:postgrex)
    {:ok, _} = Application.ensure_all_started(:ecto_sql)

    # Define the repo configuration
    repo_config = [
      username: "postgres",
      password: "csstarahid",
      hostname: "localhost",
      database: "game_bot_test",
      port: 5432,
      pool_size: 2,
      timeout: 5000,
      connect_timeout: 5000
    ]

    # Start the database connection
    IO.puts("Starting database connection...")
    {:ok, conn} = Postgrex.start_link(repo_config)

    # Test basic query
    IO.puts("Testing basic query...")
    case Postgrex.query(conn, "SELECT 1 as one", []) do
      {:ok, result} ->
        IO.puts("Query successful! Result: #{inspect(result)}")

      {:error, error} ->
        IO.puts("Query failed: #{inspect(error)}")
    end

    # Test EventStore tables
    IO.puts("\nTesting event_store schema...")
    case Postgrex.query(conn, "SELECT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'event_store')", []) do
      {:ok, %{rows: [[true]]}} ->
        IO.puts("event_store schema exists!")

        # Check tables
        check_table(conn, "event_store.streams")
        check_table(conn, "event_store.events")
        check_table(conn, "event_store.subscriptions")

      {:ok, %{rows: [[false]]}} ->
        IO.puts("event_store schema does not exist!")

      {:error, error} ->
        IO.puts("Schema check failed: #{inspect(error)}")
    end

    # Test access through the proper interfaces if EventStore module is available
    IO.puts("\nTesting EventStore functionality...")
    test_event_store()

    # Clean up
    IO.puts("\nTest complete.")
  end

  defp check_table(conn, table) do
    # Extract schema and table name
    [schema, table_name] = String.split(table, ".")

    case Postgrex.query(conn,
      "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = $1 AND table_name = $2)",
      [schema, table_name]) do

      {:ok, %{rows: [[true]]}} ->
        IO.puts("Table #{table} exists!")

        # Count rows
        case Postgrex.query(conn, "SELECT COUNT(*) FROM #{table}", []) do
          {:ok, %{rows: [[count]]}} ->
            IO.puts("  #{count} rows in table")

          {:error, error} ->
            IO.puts("  Failed to count rows: #{inspect(error)}")
        end

      {:ok, %{rows: [[false]]}} ->
        IO.puts("Table #{table} does not exist!")

      {:error, error} ->
        IO.puts("Table check failed: #{inspect(error)}")
    end
  end

  defp test_event_store do
    # Try to access the EventStore module
    event_store_module = GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres

    if Code.ensure_loaded?(event_store_module) do
      IO.puts("EventStore module is available.")

      # Try to start the EventStore
      IO.puts("Starting EventStore...")
      config = [
        username: "postgres",
        password: "csstarahid",
        hostname: "localhost",
        database: "game_bot_eventstore_test",
        port: 5432,
        pool_size: 2,
        timeout: 5000
      ]

      case event_store_module.start_link(config) do
        {:ok, pid} ->
          IO.puts("EventStore started with pid: #{inspect(pid)}")

          # Try a test event stream
          stream_id = "test-stream-#{:erlang.unique_integer([:positive])}"

          # Create a test event
          event = %{
            stream_id: stream_id,
            event_type: "test_event",
            data: %{test: "data"},
            metadata: %{test: "metadata"}
          }

          # Try append
          IO.puts("Testing append_to_stream...")
          case event_store_module.append_to_stream(stream_id, :no_stream, [event]) do
            {:ok, version} ->
              IO.puts("Successfully appended event. Stream version: #{version}")

              # Try read
              IO.puts("Testing read_stream_forward...")
              case event_store_module.read_stream_forward(stream_id) do
                {:ok, events} ->
                  IO.puts("Successfully read events. Count: #{length(events)}")
                  IO.puts("Event data: #{inspect(hd(events).data)}")

                {:error, reason} ->
                  IO.puts("Failed to read stream: #{inspect(reason)}")
              end

            {:error, reason} ->
              IO.puts("Failed to append to stream: #{inspect(reason)}")
          end

        {:error, reason} ->
          IO.puts("Failed to start EventStore: #{inspect(reason)}")
      end
    else
      IO.puts("EventStore module is not available.")
    end
  end
end
