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

  using do
    quote do
      alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres, as: EventStore
      alias GameBot.Infrastructure.Persistence.Repo

      import GameBot.EventStoreCase
    end
  end

  setup tags do
    # Always clean up connections before starting a new test
    ConnectionHelper.close_db_connections()

    # Skip database setup if the test doesn't need it
    if tags[:skip_db] do
      :ok
    else
      # Use parent process as owner for explicit checkout pattern
      parent = self()

      # Start sandbox session for each repo with explicit owner
      Ecto.Adapters.SQL.Sandbox.checkout(Repo, caller: parent)
      Ecto.Adapters.SQL.Sandbox.checkout(EventStore, caller: parent)

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
        clean_database()

        # Return connections to the pool
        Ecto.Adapters.SQL.Sandbox.checkin(Repo)
        Ecto.Adapters.SQL.Sandbox.checkin(EventStore)

        # Close any lingering connections
        ConnectionHelper.close_db_connections()
      end)
    end

    :ok
  end

  @doc """
  Creates a test stream with the given ID and optional events.
  """
  def create_test_stream(stream_id, events \\ []) do
    case EventStore.append_to_stream(stream_id, :no_stream, events, []) do
      {:ok, version} -> {:ok, version}
      error -> error
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

  # Private Functions

  defp clean_database do
    # Use a safer approach that handles errors gracefully
    try do
      Repo.query!("TRUNCATE event_store.streams, event_store.events, event_store.subscriptions CASCADE")
    rescue
      _ -> :ok
    end
  end
end
