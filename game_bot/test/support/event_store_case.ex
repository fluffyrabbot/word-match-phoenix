defmodule GameBot.EventStoreCase do
  @moduledoc """
  This module defines the setup for tests requiring access to the event store.

  It provides:
  - Sandbox setup for database transactions
  - Helper functions for creating test data
  - Cleanup between tests
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres, as: EventStore
  alias GameBot.Infrastructure.Persistence.Repo
  require Logger

  # Set a timeout for database operations
  @db_timeout 15_000
  @checkout_timeout 30_000

  # Define the repositories we need to check out
  @repos [Repo, EventStore]

  # Share connections across tests
  @shared_setup_complete {__MODULE__, :shared_setup_complete}

  using do
    quote do
      alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres, as: EventStore
      alias GameBot.Infrastructure.Persistence.Repo

      import GameBot.EventStoreCase
    end
  end

  setup_all do
    # Only verify the event store schema exists - DO NOT start repositories
    # since they are already started in test_helper.exs
    ensure_event_store_schema_exists()

    # Register cleanup for test process termination
    ExUnit.after_suite(fn(_) ->
      cleanup_connections()
    end)

    :ok
  end

  setup tags do
    # Always check out the repositories at the beginning of each test
    # Using a plain checkout (not shared) for more explicit control
    Enum.each(@repos, fn repo ->
      :ok = Sandbox.checkout(repo, [ownership_timeout: @checkout_timeout])
    end)

    # For non-async tests, set shared mode
    unless tags[:async] do
      Enum.each(@repos, fn repo ->
        Sandbox.mode(repo, {:shared, self()})
      end)
    end

    # Clean database state before each test
    clean_database_state()

    # Register a cleanup callback for after the test
    on_exit(fn ->
      # Clear unexpected messages that might interfere with connection handling
      clear_test_mailbox()

      # Explicitly rollback any lingering transactions
      Enum.each(@repos, fn repo ->
        try do
          if Process.whereis(repo) do
            try do
              # Try to rollback any lingering transactions
              Sandbox.checkout(repo)
              repo.rollback(fn -> :ok end)
            rescue
              _ -> :ok
            end
          end
        rescue
          e -> Logger.warning("Error rolling back transactions for #{inspect(repo)}: #{inspect(e)}")
        end
      end)

      # Check in connections after each test
      Enum.each(@repos, fn repo ->
        try do
          if Process.whereis(repo) do
            Sandbox.checkin(repo)
          end
        rescue
          e -> Logger.warning("Error checking in repository #{inspect(repo)}: #{inspect(e)}")
        end
      end)
    end)

    :ok
  end

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

  # Private Functions

  # Check if a repository is running without trying to start it
  defp is_repo_running?(repo) do
    case Process.whereis(repo) do
      pid when is_pid(pid) -> Process.alive?(pid)
      nil -> false
    end
  end

  # Clean database state before each test
  defp clean_database_state do
    # Use a safer approach that handles errors gracefully
    try do
      # Add a timeout to the query to prevent hanging
      Repo.query!(
        "TRUNCATE event_store.streams, event_store.events, event_store.subscriptions CASCADE",
        [],
        timeout: @db_timeout
      )
    rescue
      e ->
        # Log and continue
        Logger.warning("Failed to clean database: #{inspect(e)}")
        :ok
    end
  end

  # Ensure the event store schema is properly set up
  defp ensure_event_store_schema_exists do
    IO.puts("\nVerifying event_store schema exists...")

    repo = GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres

    # Make sure the repository is already running
    if !Process.whereis(repo) do
      raise "EventStore repository is not running. It should be started in test_helper.exs."
    end

    # Get sandbox connection
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(repo, ownership_timeout: 60_000)

    try do
      # Create the event store schema and tables if they don't exist
      repo.query!("CREATE SCHEMA IF NOT EXISTS event_store", [])

      repo.query!("""
      CREATE TABLE IF NOT EXISTS event_store.streams (
        id TEXT PRIMARY KEY,
        version BIGINT NOT NULL DEFAULT 0
      )
      """, [])

      repo.query!("""
      CREATE TABLE IF NOT EXISTS event_store.events (
        event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        stream_id TEXT NOT NULL REFERENCES event_store.streams(id) ON DELETE CASCADE,
        event_type TEXT NOT NULL,
        event_data JSONB NOT NULL,
        event_metadata JSONB NOT NULL DEFAULT '{}',
        event_version BIGINT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )
      """, [])

      repo.query!("""
      CREATE TABLE IF NOT EXISTS event_store.subscriptions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        stream_id TEXT NOT NULL REFERENCES event_store.streams(id) ON DELETE CASCADE,
        subscriber_pid TEXT NOT NULL,
        options JSONB NOT NULL DEFAULT '{}',
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )
      """, [])

      IO.puts("  ✓ Event store schema and tables verified")
      :ok
    rescue
      e ->
        # Log the error
        IO.puts("  ✗ Error in ensure_event_store_schema_exists: #{Exception.message(e)}")
        reraise e, __STACKTRACE__
    after
      # Always check in the connection
      Ecto.Adapters.SQL.Sandbox.checkin(repo)
    end
  end

  # Don't try to start repos - verify they're already running
  defp start_all_repos do
    # Don't try to start repos - they should already be started in test_helper.exs
    Enum.each(@repos, fn repo ->
      if !is_repo_running?(repo) do
        raise "Repository #{inspect(repo)} is not running. All repositories should be started in test_helper.exs."
      end
    end)
  end

  # Cleanup connections when the test suite is done
  defp cleanup_connections do
    # Safely clean up each repo
    Enum.each(@repos, fn repo ->
      try do
        if Process.whereis(repo) do
          # First check in any checked out connections
          Sandbox.checkin(repo)
        end
      catch
        :exit, _ ->
          IO.puts("Repository #{inspect(repo)} connection was already checked in")
      end
    end)
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
