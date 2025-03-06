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
    case Process.whereis(GameBot.Infrastructure.EventStore) do
      nil -> :ok
      _ ->
        try do
          :ok = GameBot.Infrastructure.EventStore.reset!()
        rescue
          _ -> :ok
        end
    end

    # Attempt to close any open connections for mock stores
    case Process.whereis(GameBot.TestEventStore) do
      nil -> :ok
      pid ->
        try do
          GenServer.stop(pid, :normal, 100)
        rescue
          _ -> :ok
        end
    end

    # Force database connections to close
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
end
