defmodule GameBot.EventStoreCase do
  @moduledoc """
  This module defines the setup for tests requiring access to the event store.

  It provides:
  - Sandbox setup for database transactions
  - Helper functions for creating test data
  - Cleanup between tests
  """

  use ExUnit.CaseTemplate

  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres, as: EventStore
  alias GameBot.Infrastructure.Persistence.Repo

  # Set a timeout for database operations
  @db_timeout 15_000
  @checkout_timeout 30_000

  # Define the repositories we need to check out
  @repos [Repo, EventStore]

  using do
    quote do
      alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres, as: EventStore
      alias GameBot.Infrastructure.Persistence.Repo

      import GameBot.EventStoreCase
    end
  end

  setup tags do
    # Set up sandbox using DatabaseHelper
    GameBot.Test.DatabaseHelper.reset_sandbox()

    # Register cleanup callback
    on_exit(fn ->
      # Delay slightly to ensure any in-flight operations complete
      Process.sleep(50)

      # Clear mailbox of any unexpected db_connection messages
      clear_test_mailbox()

      # Then proceed with normal cleanup
      GameBot.Test.DatabaseHelper.cleanup()
    end)

    :ok
  end

  @doc """
  Forcefully closes all database connections in the current VM.
  Useful for cleanup between tests or when a connection is stuck.
  """
  def close_db_connections do
    IO.puts("Forcefully closing database connections...")

    # Find all database connections
    connection_pids = for pid <- Process.list(),
                         info = Process.info(pid, [:dictionary]),
                         info != nil,
                         dictionary = info[:dictionary],
                         dictionary != nil,
                         initial_call = dictionary[:"$initial_call"],
                         is_database_connection(initial_call) do
      pid
    end

    # Kill each connection process
    Enum.each(connection_pids, fn pid ->
      IO.puts("Killing connection process: #{inspect(pid)}")
      Process.exit(pid, :kill)
    end)

    # Small sleep to allow processes to terminate
    Process.sleep(200)

    IO.puts("Closed #{length(connection_pids)} database connections")
  end

  # Attempt to turn off LISTEN/NOTIFY for Postgres
  # This can help prevent connection issues in tests
  defp try_turn_off_notifications do
    try do
      Enum.each(@repos, fn repo ->
        try do
          # Try to turn off LISTEN/NOTIFY if possible
          sql = "SELECT pg_listening_channels();"
          case Repo.query(sql, [], timeout: @db_timeout) do
            {:ok, %{rows: rows}} ->
              channels = List.flatten(rows)
              Enum.each(channels, fn channel ->
                Repo.query("UNLISTEN #{channel};", [], timeout: @db_timeout)
              end)
            _ -> :ok
          end
        rescue
          _ -> :ok
        catch
          _, _ -> :ok
        end
      end)
    rescue
      _ -> :ok
    catch
      _, _ -> :ok
    end
  end

  # Helper to detect database connection processes
  defp is_database_connection({Postgrex.Protocol, :init, 1}), do: true
  defp is_database_connection({DBConnection.Connection, :init, 1}), do: true
  defp is_database_connection(_), do: false

  @doc """
  Creates a test event with the given type and data.
  """
  def create_test_event(type, data \\ %{}) do
    %{
      event_type: type,
      data: data,
      metadata: %{
        correlation_id: UUID.uuid4(),
        causation_id: UUID.uuid4(),
        user_id: "test_user"
      }
    }
  end

  @doc """
  Creates a test stream with the given events.
  """
  def create_test_stream(events) when is_list(events) do
    stream_id = UUID.uuid4()
    {:ok, _} = EventStore.append_to_stream(stream_id, :any_version, events)
    stream_id
  end

  @doc """
  Reads all events from a stream.
  """
  def read_stream_events(stream_id) do
    {:ok, events} = EventStore.read_stream_forward(stream_id)
    events
  end

  @doc """
  Generates a unique stream ID for testing.
  """
  def unique_stream_id(prefix \\ "test") do
    "#{prefix}-#{:erlang.unique_integer([:positive])}"
  end

  @doc """
  Runs operations concurrently to test behavior under contention.
  """
  def test_concurrent_operations(impl, operation_fn, count \\ 5) do
    # Run the operation in multiple processes
    tasks = for i <- 1..count do
      Task.async(fn -> operation_fn.(i) end)
    end

    # Wait for all operations to complete with a timeout
    Task.await_many(tasks, @db_timeout)
  end

  @doc """
  Creates a subscription for testing, ensures cleanup.
  """
  def with_subscription(impl, stream_id, subscriber, fun) do
    # Create subscription - returns {:ok, subscription}
    {:ok, subscription} = impl.subscribe_to_stream(stream_id, subscriber, [], [timeout: @db_timeout])

    try do
      # Run the test function with the subscription
      fun.(subscription)
    after
      # Ensure subscription is cleaned up
      try do
        impl.unsubscribe_from_stream(stream_id, subscription)
      rescue
        _ -> :ok
      catch
        _, _ -> :ok
      end
    end
  end

  @doc """
  Executes operations in a transaction if available.
  """
  def with_transaction(impl, fun) do
    cond do
      function_exported?(impl, :transaction, 1) ->
        impl.transaction(fun, [timeout: @db_timeout])
      true ->
        fun.()
    end
  end

  # Private Functions

  defp clean_database do
    # Use a safer approach that handles errors gracefully
    try do
      IO.puts("Starting database cleanup...")

      # First check if the tables exist to avoid errors when tables don't exist yet
      table_check_query = """
      SELECT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_schema = 'event_store'
        AND table_name = 'events'
      )
      """

      # Check if event store tables exist
      case Repo.query(table_check_query, [], timeout: @db_timeout) do
        {:ok, %{rows: [[true]]}} ->
          # Tables exist, truncate them
          IO.puts("Event store tables found, truncating...")
          # Add a timeout to the query to prevent hanging
          Repo.query!(
            "TRUNCATE event_store.streams, event_store.events, event_store.subscriptions CASCADE",
            [],
            timeout: @db_timeout
          )
          IO.puts("Database tables cleaned successfully")

        {:ok, %{rows: [[false]]}} ->
          # Tables don't exist
          IO.puts("Event store tables don't exist yet, skipping truncate")
          :ok

        {:error, error} ->
          # Query failed, log and continue
          IO.puts("Warning: Failed to check tables: #{inspect(error)}")
          :ok
      end
    rescue
      e ->
        # Log and continue
        IO.puts("Warning: Failed to clean database: #{inspect(e)}")
        :ok
    catch
      _, e ->
        # Log and continue
        IO.puts("Warning: Exception in clean_database: #{inspect(e)}")
        :ok
    end
  end

  # Helper Functions

  # Clean up any open transactions
  defp cleanup_open_transactions do
    try do
      # Force rollback of any open transaction
      GameBot.Infrastructure.Persistence.Repo.rollback_all()
    rescue
      _ -> :ok
    end
  end

  # Ensure connection pool is properly shut down
  defp ensure_pool_shutdown(repo) do
    try do
      # Get pool size so we know how many connections to expect
      pool_size = Keyword.get(repo.config(), :pool_size, 10)

      # Force close connections in pool
      for _ <- 1..pool_size do
        try do
          DBConnection.disconnect_all(repo.config()[:pool], timeout: 500)
        rescue
          _ -> :ok
        catch
          _, _ -> :ok
        end
      end

      # Wait a bit before allowing supervisor shutdown
      Process.sleep(100)
    rescue
      _ -> :ok
    catch
      _, _ -> :ok
    end
  end

  # Helper function to clear test process mailbox of problematic messages
  defp clear_test_mailbox() do
    receive do
      {:db_connection, _, {:checkout, _, _, _}} = msg ->
        # Log that we're clearing a potentially problematic message
        Logger.debug("Cleared unexpected db_connection message from test process mailbox: #{inspect(msg)}")
        clear_test_mailbox()
      after
        0 -> :ok
    end
  end
end

# Create an alias module to satisfy the GameBot.Test.EventStoreCase reference
defmodule GameBot.Test.EventStoreCase do
  @moduledoc """
  Alias module for GameBot.EventStoreCase.
  This exists to maintain backward compatibility with existing tests.
  """

  defmacro __using__(opts) do
    quote do
      use GameBot.EventStoreCase, unquote(opts)
    end
  end
end
