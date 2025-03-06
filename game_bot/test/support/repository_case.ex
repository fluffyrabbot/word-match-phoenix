defmodule GameBot.RepositoryCase do
  @moduledoc """
  This module defines common utilities for testing repositories.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias GameBot.Infrastructure.Persistence.Repo
      import Ecto
      import Ecto.Query
      import GameBot.RepositoryCase
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(GameBot.Infrastructure.Persistence.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(GameBot.Infrastructure.Persistence.Repo, {:shared, self()})
    end

    # Start the test event store if not already started
    case Process.whereis(GameBot.TestEventStore) do
      nil ->
        {:ok, pid} = GameBot.TestEventStore.start_link()
        on_exit(fn ->
          if Process.alive?(pid) do
            GameBot.TestEventStore.stop(GameBot.TestEventStore)
          end
        end)
      pid ->
        # Reset state if store already exists
        GameBot.TestEventStore.set_failure_count(0)
        # Clear any existing streams
        :sys.replace_state(pid, fn _ -> %GameBot.TestEventStore.State{} end)
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
