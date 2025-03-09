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
    # Skip database setup if the test doesn't need it
    if tags[:skip_db] do
      :ok
    else
      pid = self()
      # First, make sure we kill any lingering connections
      # This is necessary to ensure we have a clean state
      close_db_connections()

      # Clear sandbox to ensure we're starting fresh
      Enum.each(@repos, fn repo ->
        try do
          Ecto.Adapters.SQL.Sandbox.checkin(repo)
        rescue
          _ -> :ok
        catch
          _, _ -> :ok
        end
      end)

      # Ensure PG notifications are turned off
      try_turn_off_notifications()

      # Wait a bit to allow connections to fully close
      Process.sleep(100)

      # Explicitly checkout the repositories for the test process
      # This ensures we have isolated database access for this test
      Enum.each(@repos, fn repo ->
        try do
          case Ecto.Adapters.SQL.Sandbox.checkout(repo, [ownership_timeout: @checkout_timeout]) do
            :ok ->
              IO.puts("Successfully checked out #{inspect(repo)} for test process #{inspect(pid)}")
            {:ok, _} ->
              IO.puts("Successfully checked out #{inspect(repo)} for test process #{inspect(pid)}")
            {:error, error} ->
              raise "Failed to checkout #{inspect(repo)}: #{inspect(error)}"
          end

          # Allow shared connections if test is not async
          unless tags[:async] do
            Ecto.Adapters.SQL.Sandbox.mode(repo, {:shared, pid})
            IO.puts("Enabled shared sandbox mode for #{inspect(repo)}")
          end
        rescue
          e ->
            IO.puts("Error during checkout for #{inspect(repo)}: #{inspect(e)}")
            # Don't reraise - try to continue with other repos
        end
      end)

      # Clean the database tables to ensure a fresh state for this test
      clean_database()

      # Make sure connections are explicitly released after test
      on_exit(fn ->
        IO.puts("Running on_exit cleanup for test process #{inspect(pid)}")

        # First try to clean the database again
        try do
          clean_database()
        rescue
          e ->
            IO.puts("Warning: Failed to clean database: #{inspect(e)}")
        end

        # Check in repositories
        Enum.each(@repos, fn repo ->
          try do
            Ecto.Adapters.SQL.Sandbox.checkin(repo)
            IO.puts("Checked in #{inspect(repo)} for test process #{inspect(pid)}")
          rescue
            e ->
              IO.puts("Warning: Failed to checkin connection for #{inspect(repo)}: #{inspect(e)}")
          end
        end)

        # Force close any lingering connections
        close_db_connections()
      end)
    end

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
  Creates a test stream with the given ID and optional events.
  """
  def create_test_stream(stream_id, events \\ []) do
    try do
      case EventStore.append_to_stream(stream_id, :no_stream, events, [timeout: @db_timeout]) do
        {:ok, version} -> {:ok, version}
        error -> error
      end
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Creates a test event with given fields.
  """
  def create_test_event(id, data \\ %{}) do
    %{
      stream_id: "test-#{id}",
      event_type: "test_event",
      data: data,
      metadata: %{}
    }
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
