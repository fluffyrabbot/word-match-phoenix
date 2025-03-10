defmodule GameBot.DiagnosticTest do
  use ExUnit.Case, async: false
  require Logger

  # Helper function to get database name for testing
  defp database_name do
    db_config = Application.get_env(:game_bot, :test_databases)
    db_config[:main_db]
  end

  # Helper function to create a PostgreSQL connection for testing
  defp pg_conn do
    pg_config = [
      hostname: "localhost",
      username: "postgres",
      password: "csstarahid",
      database: database_name(),
      pool: DBConnection.ConnectionPool,
      pool_size: 1
    ]

    case Postgrex.start_link(pg_config) do
      {:ok, conn} -> conn
      other ->
        Logger.error("Failed to connect to PostgreSQL: #{inspect(other)}")
        flunk("PostgreSQL connection failed: #{inspect(other)}")
    end
  end

  # Helper function to clear any stale TestEventStore processes
  defp clear_stale_event_store do
    # Try to stop EventStoreCore if it's running
    case Process.whereis(GameBot.Test.EventStoreCore) do
      nil ->
        Logger.info("EventStoreCore not registered, nothing to clean up")
      pid when is_pid(pid) ->
        Logger.info("Stopping existing EventStoreCore process: #{inspect(pid)}")
        try do
          GenServer.stop(pid, :normal)
          Process.sleep(100) # Give it time to terminate
        catch
          _kind, _reason ->
            Logger.info("EventStoreCore process already terminated")
        end
    end

    # Also check if TestEventStore is registered
    case Process.whereis(GameBot.TestEventStore) do
      nil ->
        Logger.info("TestEventStore not registered, nothing to clean up")
      pid when is_pid(pid) ->
        Logger.info("Stopping existing TestEventStore process: #{inspect(pid)}")
        try do
          GenServer.stop(pid, :normal)
          Process.sleep(100) # Give it time to terminate
        catch
          _kind, _reason ->
            Logger.info("TestEventStore process already terminated")
        end
    end
  end

  # First test - Basic PostgreSQL connectivity
  @tag :diagnostic
  test "diagnostic: PostgreSQL connection is working" do
    Logger.info("Testing PostgreSQL connection")
    Logger.info("Main test database: #{inspect(database_name())}")

    conn = pg_conn()
    assert {:ok, %{rows: [["1"]]}} = Postgrex.query(conn, "SELECT '1'", [])

    # Clean up
    GenServer.stop(conn)
  end

  # Test repository initialization
  @tag :diagnostic
  test "diagnostic: Repository initialization" do
    Logger.info("Testing repository initialization")

    repos = [
      GameBot.Infrastructure.Persistence.Repo,
      GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
    ]

    results = Enum.map(repos, fn repo ->
      Logger.info("Starting repository: #{inspect(repo)}")

      case Ecto.Adapters.SQL.Sandbox.checkout(repo) do
        :ok ->
          Logger.info("Repository already started: #{inspect(repo)}")
          :ok
        {:ok, _} ->
          Logger.info("Repository started successfully: #{inspect(repo)}")
          :ok
        error ->
          Logger.error("Failed to start repository #{inspect(repo)}: #{inspect(error)}")
          error
      end
    end)

    # No errors should have occurred
    refute Enum.any?(results, fn result -> result != :ok end)
  end

  # Test EventStore mock
  @tag :diagnostic
  @tag :skip_db
  test "diagnostic: EventStore mock works" do
    Logger.info("Testing EventStore mock")

    # Always ensure we start with a clean slate
    clear_stale_event_store()

    # Create a standalone EventStore instance
    # We need to handle the case where it might already be started
    Logger.info("Starting new TestEventStore instance")

    start_result = GameBot.TestEventStore.start_link([])

    pid = case start_result do
      {:ok, pid} ->
        Logger.info("TestEventStore started successfully with new PID: #{inspect(pid)}")
        pid
      {:error, {:already_started, pid}} ->
        Logger.info("TestEventStore was already started with PID: #{inspect(pid)}")
        pid
      other_error ->
        flunk("Failed to start TestEventStore: #{inspect(other_error)}")
    end

    # Verify process is running
    assert Process.alive?(pid), "TestEventStore process is not alive"

    # Test reset operation
    assert :ok = GameBot.TestEventStore.reset!()
    Logger.info("TestEventStore reset successful")

    # Test basic operations
    stream_id = "test-#{System.unique_integer([:positive])}"
    test_event = %{data: %{message: "Hello"}, metadata: %{timestamp: DateTime.utc_now()}}
    Logger.info("Using test stream: #{stream_id}")

    # Append to stream
    append_result = GameBot.TestEventStore.append_to_stream(
      pid,  # Use the PID directly instead of the module name
      stream_id,
      0,
      [test_event]
    )

    case append_result do
      :ok ->
        Logger.info("Successfully appended event to stream")

      {:ok, _count} ->
        # Also handle the case where the result is {:ok, count} where count is the number of events appended
        Logger.info("Successfully appended event to stream with count")

      error ->
        flunk("Failed to append to stream: #{inspect(error)}")
    end

    # Read from stream
    read_result = GameBot.TestEventStore.read_stream_forward(
      pid,
      stream_id,
      0,
      1000
    )

    case read_result do
      {:ok, events} when is_list(events) ->
        Logger.info("Successfully read #{length(events)} events from stream")
        assert length(events) > 0, "No events were read from the stream"

      {:ok, events, _, _} when is_list(events) ->
        # This format is used by some EventStore implementations
        Logger.info("Successfully read #{length(events)} events from stream with additional metadata")
        assert length(events) > 0, "No events were read from the stream"

      error ->
        flunk("Failed to read from stream: #{inspect(error)}")
    end

    # Stop the TestEventStore process when done
    if Process.alive?(pid) do
      GenServer.stop(pid, :normal)
      Logger.info("Stopped TestEventStore process")
    end
  end

  @tag :diagnostic
  test "diagnostic: All done" do
    Logger.info("All diagnostic tests completed successfully!")
  end
end
