defmodule GameBot.Test.DatabaseConnectionManager do
  @moduledoc """
  Manages database connections for test environments.

  This module provides functions to handle graceful shutdown and cleanup
  of database connections during tests.
  """

  require Logger

  # Maximum time to wait for graceful shutdown (in ms)
  @shutdown_timeout 3000
  # Maximum PostgreSQL connection attempts
  @max_connection_attempts 3
  # Delay between connection attempts (in ms)
  @connection_retry_delay 500

  @doc """
  Gracefully shuts down database connections.

  This function attempts to close all database connections in a clean way,
  giving them time to complete any in-progress operations before shutting down.
  """
  def graceful_shutdown do
    Logger.info("Performing graceful shutdown of database connections")

    try do
      # Attempt to close connections for the main repositories
      close_repository_connections()
    catch
      kind, reason ->
        Logger.error("Error during repository shutdown: #{inspect(kind)}, #{inspect(reason)}")
        # Even if we fail, continue with termination
    after
      # Always terminate any remaining connections at the PostgreSQL level
      terminate_remaining_connections()
    end

    # Small delay to allow connections to fully close
    Process.sleep(200)

    :ok
  end

  @doc """
  Forcefully terminates all database connections.

  This is a last resort method to ensure no connections remain open.
  """
  def terminate_all_connections do
    Logger.info("Forcefully terminating all database connections")

    try do
      # Kill all Postgrex and DBConnection processes
      kill_connection_processes()
    catch
      kind, reason ->
        Logger.error("Error killing connection processes: #{inspect(kind)}, #{inspect(reason)}")
    after
      # Always terminate connections at the PostgreSQL level
      terminate_remaining_connections()
    end

    :ok
  end

  @doc """
  Checks if PostgreSQL connections are available.

  Useful to verify database availability before running tests.

  Returns:
  - `:ok` - If connection is successful
  - `{:error, reason}` - If connection fails
  """
  def check_postgres_connection do
    try do
      config = [
        hostname: "localhost",
        username: "postgres",
        password: "csstarahid",
        database: "postgres",
        connect_timeout: 5000
      ]

      case Postgrex.start_link(config) do
        {:ok, conn} ->
          # Test a simple query to verify connection
          case Postgrex.query(conn, "SELECT 1", []) do
            {:ok, _} ->
              # Properly close the connection
              GenServer.stop(conn, :normal, 1000)
              :ok
            {:error, error} ->
              Logger.error("PostgreSQL connection test query failed: #{inspect(error)}")
              {:error, :query_failed}
          end
        {:error, error} ->
          Logger.error("Failed to connect to PostgreSQL: #{inspect(error)}")
          {:error, :connection_failed}
      end
    rescue
      e ->
        Logger.error("Exception during PostgreSQL connection check: #{Exception.message(e)}")
        {:error, :exception}
    catch
      kind, reason ->
        Logger.error("Unexpected error during PostgreSQL connection check: #{inspect(kind)}, #{inspect(reason)}")
        {:error, :unexpected_error}
    end
  end

  @doc """
  Monitors processes spawned for database operations.

  Helps track and clean up processes that might otherwise become orphaned.

  Returns:
  - `{:ok, ref}` - Reference to the monitor
  - `{:error, reason}` - If monitoring fails
  """
  def monitor_process(pid) when is_pid(pid) do
    try do
      ref = Process.monitor(pid)
      {:ok, ref}
    rescue
      e ->
        Logger.error("Failed to monitor process #{inspect(pid)}: #{Exception.message(e)}")
        {:error, :monitor_failed}
    end
  end

  @doc """
  Demonitors a previously monitored process.
  """
  def demonitor_process(ref) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    :ok
  end

  # Private functions

  defp close_repository_connections do
    repos = [
      GameBot.Infrastructure.Persistence.Repo,
      GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
    ]

    Enum.each(repos, fn repo ->
      try do
        # Check if the repository is running
        case Process.whereis(repo) do
          nil ->
            Logger.debug("Repository #{inspect(repo)} is not running")
          pid ->
            if Process.alive?(pid) do
              Logger.debug("Attempting to stop repository #{inspect(repo)}")
              # Try to stop the process gracefully with a reasonable timeout
              try do
                # First, use Repo.stop if available
                if function_exported?(repo, :stop, 0) do
                  repo.stop()
                else
                  GenServer.stop(pid, :normal, @shutdown_timeout)
                end
              rescue
                e -> Logger.warning("Error stopping #{inspect(repo)}: #{inspect(e)}")
              catch
                :exit, reason ->
                  Logger.warning("Exit when stopping #{inspect(repo)}: #{inspect(reason)}")
              end
            end
        end
      rescue
        e -> Logger.warning("Error during repo shutdown for #{inspect(repo)}: #{inspect(e)}")
      end
    end)
  end

  defp kill_connection_processes do
    # Find and kill all database connection processes
    Enum.each(Process.list(), fn pid ->
      try do
        # Get process dictionary to check its type
        info = Process.info(pid, [:dictionary])

        if info do
          dictionary = Keyword.get(info, :dictionary, %{})
          initial_call = Map.get(dictionary, :"$initial_call")

          cond do
            # Handle Postgrex Protocol processes
            match?({Postgrex.Protocol, :init, _}, initial_call) ->
              Logger.debug("Killing Postgrex.Protocol process: #{inspect(pid)}")
              Process.exit(pid, :kill)

            # Handle DBConnection processes
            match?({DBConnection, :init, _}, initial_call) ->
              Logger.debug("Killing DBConnection process: #{inspect(pid)}")
              Process.exit(pid, :kill)

            # Handle other database-related processes
            match?({{:gen_statem, :init}, _, [Postgrex.Connection | _]}, initial_call) ->
              Logger.debug("Killing Postgrex.Connection process: #{inspect(pid)}")
              Process.exit(pid, :kill)

            # Handle DBConnection.Connection processes
            match?({DBConnection.Connection, :init, _}, initial_call) ->
              Logger.debug("Killing DBConnection.Connection process: #{inspect(pid)}")
              Process.exit(pid, :kill)

            true ->
              :ok
          end
        end
      rescue
        _ -> :ok
      end
    end)

    # Clear any unexpected messages in the mailbox that might cause errors
    # This specifically handles the {:db_connection, ...} checkout messages
    clear_mailbox_of_db_messages()

    # Small delay to allow processes to terminate
    Process.sleep(100)
  end

  # Clear unexpected database checkout messages from the mailbox
  defp clear_mailbox_of_db_messages do
    receive do
      {:db_connection, _, {:checkout, _, _, _}} ->
        Logger.debug("Cleared unexpected db_connection checkout message from mailbox")
        clear_mailbox_of_db_messages()
      after
        0 -> :ok
    end
  end

  defp terminate_remaining_connections do
    # Use our execute_postgres_termination_query function with retry logic
    retry_with_backoff(&execute_postgres_termination_query/0, @max_connection_attempts, @connection_retry_delay)
  end

  defp execute_postgres_termination_query do
    query = """
    SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE pid <> pg_backend_pid()
    AND (datname LIKE '%_test' OR datname LIKE '%_dev')
    """

    try do
      # Connect to the postgres database (not our test database)
      {:ok, conn} = Postgrex.start_link([
        hostname: "localhost",
        username: "postgres",
        password: "csstarahid", # Using the password from run_tests.sh
        database: "postgres",
        connect_timeout: 5000
      ])

      # Execute the termination query
      result = Postgrex.query!(conn, query, [])
      Logger.debug("Connection termination result: #{inspect(result)}")

      # Close our connection
      GenServer.stop(conn, :normal, 500)

      :ok
    rescue
      e ->
        Logger.warning("Error terminating connections: #{inspect(e)}")
        {:error, e}
    catch
      kind, reason ->
        Logger.warning("Unexpected error during connection termination: #{inspect(kind)}, #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Helper function to retry operations with exponential backoff
  defp retry_with_backoff(_func, 0, _delay) do
    {:error, :max_retries_exceeded}
  end

  defp retry_with_backoff(func, attempts, delay) do
    case func.() do
      :ok -> :ok
      {:ok, result} -> {:ok, result}
      {:error, _reason} when attempts > 1 ->
        # Log each retry attempt
        Logger.warning("Database operation failed, retrying (#{attempts-1} attempts left)")
        Process.sleep(delay)
        retry_with_backoff(func, attempts - 1, delay * 2)
      error -> error
    end
  end
end
