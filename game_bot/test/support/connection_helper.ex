defmodule GameBot.Test.ConnectionHelper do
  @moduledoc """
  Helper module for managing database connections during tests.

  This module provides functions to:
  - Close connections after each test
  - Reset the database state
  - Handle connection cleanup
  """

  # Short timeout for operations to fail fast
  @cleanup_timeout 1_000

  @doc """
  Closes all active Postgres connections from the event store.
  This is useful to prevent connection exhaustion during tests.
  """
  def close_db_connections do
    # Force close all connections first to prevent hanging
    close_postgrex_connections()

    # Attempt to reset the connection pool if it exists
    close_eventstore_connections()

    # Attempt to close any open connections for mock stores
    close_test_event_store()
    close_mock_event_store()

    # Sleep briefly to allow connections to be properly closed
    Process.sleep(100)

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

    on_exit(fn ->
      # Try an aggressive cleanup with multiple attempts
      for _ <- 1..3 do
        close_db_connections()
      end
    end)

    :ok
  end

  # Private helpers

  defp close_eventstore_connections do
    # Handle all possible EventStore adapters
    modules = [
      GameBot.Infrastructure.Persistence.EventStore,
      GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
    ]

    Enum.each(modules, fn module ->
      try do
        case Process.whereis(module) do
          nil -> :ok
          pid ->
            try do
              # Try reset function if available
              if function_exported?(module, :reset!, 0) do
                apply(module, :reset!, [])
              end

              # Try to stop the process directly
              if Process.alive?(pid) do
                try do
                  GenServer.stop(pid, :normal, @cleanup_timeout)
                rescue
                  _ -> :ok
                catch
                  :exit, _ -> :ok
                end
              end
            rescue
              _ -> :ok
            end
        end
      rescue
        _ -> :ok
      end
    end)
  end

  defp close_test_event_store do
    try do
      case Process.whereis(GameBot.TestEventStore) do
        nil -> :ok
        pid ->
          # Try multiple cleanup methods to ensure it's stopped
          try do
            # First try to reset the state
            if function_exported?(GameBot.TestEventStore, :reset!, 0) do
              try do
                GameBot.TestEventStore.reset!()
              rescue
                _ -> :ok
              end
            end

            # Then try to stop the process
            if Process.alive?(pid) do
              GenServer.stop(pid, :normal, @cleanup_timeout)
            end
          rescue
            _ -> :ok
          catch
            :exit, _ -> :ok
          end
      end
    rescue
      _ -> :ok
    end
  end

  defp close_mock_event_store do
    try do
      case Process.whereis(GameBot.Test.Mocks.EventStore) do
        nil -> :ok
        pid ->
          # Try multiple cleanup methods to ensure it's stopped
          try do
            # First try to reset the state
            if function_exported?(GameBot.Test.Mocks.EventStore, :reset_state, 0) do
              try do
                GameBot.Test.Mocks.EventStore.reset_state()
              rescue
                _ -> :ok
              end
            end

            # Then try to stop the process
            if Process.alive?(pid) do
              GenServer.stop(pid, :normal, @cleanup_timeout)
            end
          rescue
            _ -> :ok
          catch
            :exit, _ -> :ok
          end
      end
    rescue
      _ -> :ok
    end
  end

  defp close_postgrex_connections do
    # Kill all Postgrex protocol processes to free up database connections
    Enum.each(Process.list(), fn pid ->
      try do
        info = Process.info(pid, [:dictionary])

        cond do
          # Check for Postgrex Protocol processes
          info && get_in(info, [:dictionary, :"$initial_call"]) == {Postgrex.Protocol, :init, 1} ->
            try do
              Process.exit(pid, :kill)
            rescue
              _ -> :ok
            end

          # Also check for DBConnection processes that might be stuck
          info && get_in(info, [:dictionary, :"$initial_call"]) == {DBConnection, :init, 1} ->
            try do
              Process.exit(pid, :kill)
            rescue
              _ -> :ok
            end

          true ->
            :ok
        end
      rescue
        _ -> :ok
      end
    end)

    # Small sleep to allow process exits to complete
    Process.sleep(50)
  end
end
