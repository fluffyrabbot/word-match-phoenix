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
    # Only run the shared setup once across all tests
    unless Process.get(@shared_setup_complete) do
      # Ensure event store schema and tables exist
      ensure_event_store_schema()

      # Start repositories if they're not already running
      start_all_repos()

      # Configure shared sandbox mode for all repositories
      configure_shared_sandbox()

      # Mark shared setup as complete
      Process.put(@shared_setup_complete, true)

      # Register cleanup for test process termination
      ExUnit.after_suite(fn(_) ->
        cleanup_connections()
      end)
    end

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

      # Check in connections after each test
      Enum.each(@repos, fn repo ->
        try do
          Sandbox.checkin(repo)
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

  # Start all repositories if not already running
  defp start_all_repos do
    Enum.each(@repos, fn repo ->
      if not is_repo_running?(repo) do
        Logger.info("Starting #{inspect(repo)} for test suite")
        {:ok, _} = repo.start_link([pool: Ecto.Adapters.SQL.Sandbox, pool_size: 5])
      end
    end)
  end

  # Configure shared sandbox mode for all repositories
  defp configure_shared_sandbox do
    Enum.each(@repos, fn repo ->
      # Set manual mode for the repository
      Ecto.Adapters.SQL.Sandbox.mode(repo, :manual)

      # Checkout a connection with a long timeout
      Ecto.Adapters.SQL.Sandbox.checkout(repo, [ownership_timeout: 60_000])
    end)
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

  # Check if a repository is running
  defp is_repo_running?(repo) do
    case Process.whereis(repo) do
      pid when is_pid(pid) -> Process.alive?(pid)
      nil -> false
    end
  end

  # Helper function to ensure event_store schema and tables exist
  defp ensure_event_store_schema do
    Logger.info("Ensuring event_store schema and tables exist...")

    # First checkout a connection for this operation
    :ok = Sandbox.checkout(Repo, [ownership_timeout: @checkout_timeout])

    # Check if schema exists
    schema_exists? = case Repo.query("SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'event_store'", []) do
      {:ok, %{rows: []}} -> false
      {:ok, _} -> true
      _ -> false
    end

    unless schema_exists? do
      Logger.info("Creating event_store schema and tables...")

      # Create schema
      Repo.query!("CREATE SCHEMA IF NOT EXISTS event_store", [])

      # Create streams table
      Repo.query!("""
        CREATE TABLE IF NOT EXISTS event_store.streams (
          id text NOT NULL,
          version bigint NOT NULL,
          created_at timestamp without time zone DEFAULT now() NOT NULL,
          PRIMARY KEY(id)
        );
      """, [])

      # Create events table
      Repo.query!("""
        CREATE TABLE IF NOT EXISTS event_store.events (
          event_id bigserial NOT NULL,
          stream_id text NOT NULL,
          event_type text NOT NULL,
          event_data jsonb NOT NULL,
          event_metadata jsonb NOT NULL,
          event_version bigint NOT NULL,
          created_at timestamp without time zone DEFAULT now() NOT NULL,
          PRIMARY KEY(event_id),
          FOREIGN KEY(stream_id) REFERENCES event_store.streams(id)
        );
      """, [])

      # Create subscriptions table
      Repo.query!("""
        CREATE TABLE IF NOT EXISTS event_store.subscriptions (
          id bigserial NOT NULL,
          stream_id text NOT NULL,
          subscriber_pid text NOT NULL,
          options jsonb,
          created_at timestamp without time zone DEFAULT now() NOT NULL,
          PRIMARY KEY(id),
          FOREIGN KEY(stream_id) REFERENCES event_store.streams(id)
        );
      """, [])

      Logger.info("Event store schema and tables created successfully")
    end

    # Check in the connection when done
    Sandbox.checkin(Repo)
  end

  # Cleanup connections when the test suite is done
  defp cleanup_connections do
    Logger.info("Cleaning up database connections...")

    # First try to check in connections
    Enum.each(@repos, fn repo ->
      try do
        Ecto.Adapters.SQL.Sandbox.checkin(repo)
      rescue
        _ -> :ok
      end
    end)

    # Then stop repositories
    Enum.each(@repos, fn repo ->
      try do
        repo.stop()
      rescue
        _ -> :ok
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
