defmodule GameBot.Test.RepositoryCase do
  @moduledoc """
  This module defines common utilities for testing repositories.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias GameBot.Infrastructure.Persistence.Error
      alias GameBot.Infrastructure.Persistence.{Repo, EventStore}
      alias GameBot.Infrastructure.Persistence.EventStore.{Adapter, Serializer}

      import GameBot.Test.RepositoryCase
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(GameBot.Infrastructure.Persistence.Repo.Postgres)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(GameBot.Infrastructure.Persistence.Repo.Postgres, {:shared, self()})
    end

    # Start the mock EventStore if it's not running
    unless Process.whereis(GameBot.Test.Mocks.EventStore) do
      start_supervised!(GameBot.Test.Mocks.EventStore)
    end

    # Reset the mock state for each test
    if Process.whereis(GameBot.Test.Mocks.EventStore) do
      GameBot.Test.Mocks.EventStore.reset_state()
    end

    :ok
  end

  @doc """
  Creates a test event for serialization testing.
  """
  def build_test_event(attrs \\ %{}) do
    Map.merge(%{
      event_type: "test_event",
      event_version: 1,
      data: %{
        game_id: "game-#{System.unique_integer([:positive])}",
        mode: :test,
        round_number: 1,
        timestamp: DateTime.utc_now()
      }
    }, attrs)
  end

  @doc """
  Creates a unique stream ID for testing.
  """
  def unique_stream_id do
    "test-stream-#{System.unique_integer([:positive])}"
  end
end
