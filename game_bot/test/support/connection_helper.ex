defmodule GameBot.Test.ConnectionHelper do
  @moduledoc """
  Helper module for managing database connections during tests.

  This module provides functions to:
  - Close connections after each test
  - Reset the database state
  - Handle connection cleanup
  """

  @doc """
  Closes all active Postgres connections from the event store.
  This is useful to prevent connection exhaustion during tests.
  """
  def close_db_connections do
    # Attempt to reset the connection pool if it exists
    close_eventstore_connections()

    # Attempt to close any open connections for mock stores
    close_test_event_store()

    # Force database connections to close
    close_postgrex_connections()

    :ok
  end

  @doc """
  A convenience setup that ensures DB connections are closed after each test.
  Use this in your test module's setup block to prevent connection issues.
  """
  def setup_with_connection_cleanup do
    # Close connections before test
    close_db_connections()

    # Register cleanup after test
    import ExUnit.Callbacks, only: [on_exit: 1]
    on_exit(fn -> close_db_connections() end)

    :ok
  end

  # Private helpers

  defp close_eventstore_connections do
    # Handle both main EventStore and adapter
    modules = [
      GameBot.Infrastructure.EventStore,
      GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
    ]

    Enum.each(modules, fn module ->
      case Process.whereis(module) do
        nil -> :ok
        _ ->
          try do
            if function_exported?(module, :reset!, 0) do
              apply(module, :reset!, [])
            end
          rescue
            _ -> :ok
          end
      end
    end)
  end

  defp close_test_event_store do
    case Process.whereis(GameBot.TestEventStore) do
      nil -> :ok
      pid ->
        try do
          # First try to reset the state
          if function_exported?(GameBot.TestEventStore, :reset!, 0) do
            GameBot.TestEventStore.reset!()
          end

          # Then stop the process
          GenServer.stop(pid, :normal, 100)
        rescue
          _ -> :ok
        end
    end
  end

  defp close_postgrex_connections do
    Enum.each(Process.list(), fn pid ->
      info = Process.info(pid, [:dictionary])

      if info && get_in(info, [:dictionary, :"$initial_call"]) == {Postgrex.Protocol, :init, 1} do
        try do
          Process.exit(pid, :kill)
        rescue
          _ -> :ok
        end
      end
    end)
  end
end
