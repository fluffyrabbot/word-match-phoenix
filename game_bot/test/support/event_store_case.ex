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
  alias GameBot.Test.ConnectionHelper

  # Set a shorter timeout for database operations to fail faster in tests
  @db_timeout 5_000

  using do
    quote do
      alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres, as: EventStore
      alias GameBot.Infrastructure.Persistence.Repo

      import GameBot.EventStoreCase
    end
  end

  setup tags do
    # Always clean up connections before starting a new test
    # Use a more aggressive connection cleanup strategy
    ConnectionHelper.close_db_connections()

    # Skip database setup if the test doesn't need it
    if tags[:skip_db] do
      :ok
    else
      # Use parent process as owner for explicit checkout pattern
      parent = self()

      # Start sandbox session for each repo with explicit owner and shorter timeout
      sandbox_opts = [
        caller: parent,
        ownership_timeout: @db_timeout
      ]

      Ecto.Adapters.SQL.Sandbox.checkout(Repo, sandbox_opts)
      Ecto.Adapters.SQL.Sandbox.checkout(EventStore, sandbox_opts)

      # Allow sharing of connections for better test isolation
      unless tags[:async] do
        Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, parent})
        Ecto.Adapters.SQL.Sandbox.mode(EventStore, {:shared, parent})
      end

      # Clean the database as the explicitly checked out owner
      clean_database()

      # Make sure connections are explicitly released after test
      on_exit(fn ->
        # Clean the database again before checking in
        # Use try/rescue to ensure we continue even if this fails
        try do
          clean_database()
        rescue
          e ->
            IO.puts("Warning: Failed to clean database: #{inspect(e)}")
        end

        # Return connections to the pool with a timeout
        try do
          Ecto.Adapters.SQL.Sandbox.checkin(Repo)
          Ecto.Adapters.SQL.Sandbox.checkin(EventStore)
        rescue
          e ->
            IO.puts("Warning: Failed to checkin connection: #{inspect(e)}")
        end

        # Close any lingering connections regardless of previous steps
        ConnectionHelper.close_db_connections()
      end)
    end

    :ok
  end

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

  @doc """
  Tests various error handling cases.
  """
  def verify_error_handling(impl) do
    # Verify non-existent stream handling
    {:error, _} = impl.read_stream_forward(
      "nonexistent-#{:erlang.unique_integer([:positive])}",
      0,
      1000,
      [timeout: @db_timeout]
    )

    # Add more error verifications as needed
    :ok
  end

  # Private Functions

  defp clean_database do
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
        IO.puts("Warning: Failed to truncate tables: #{inspect(e)}")
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
