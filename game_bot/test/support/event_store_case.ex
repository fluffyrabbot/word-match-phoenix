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
      # Start sandbox session for each repo
      {:ok, repo_pid} = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
      {:ok, event_store_pid} = Ecto.Adapters.SQL.Sandbox.checkout(EventStore)

      # Allow sharing of connections for better test isolation
      unless tags[:async] do
        Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
        Ecto.Adapters.SQL.Sandbox.mode(EventStore, {:shared, self()})
      end

      # Clean the database
      clean_database()

      # Make sure connections are released properly
      on_exit(fn ->
        Ecto.Adapters.SQL.Sandbox.checkin(Repo)
        Ecto.Adapters.SQL.Sandbox.checkin(EventStore)
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
