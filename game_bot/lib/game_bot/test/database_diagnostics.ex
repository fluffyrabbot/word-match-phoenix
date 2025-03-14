defmodule GameBot.Test.DatabaseDiagnostics do
  @moduledoc """
  Diagnostic tools for troubleshooting database test issues.

  This module provides functions to diagnose and fix common database-related
  test failures, particularly the "could not lookup Ecto repo" errors.
  """

  require Logger
  alias GameBot.Test.DatabaseConfig

  @repos [
    GameBot.Infrastructure.Persistence.Repo,
    GameBot.Infrastructure.Persistence.Repo.Postgres,
    GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
  ]

  @doc """
  Runs a comprehensive diagnostic check on the test database environment.

  This check:
  1. Verifies repository processes are running
  2. Validates database connectivity
  3. Checks sandbox mode status
  4. Analyzes the supervision tree

  Returns a map of diagnostic results.
  """
  def run_diagnostics do
    Logger.info("Running database test environment diagnostics")

    diagnostics = %{
      timestamp: DateTime.utc_now(),
      repos: check_repositories(),
      database_connectivity: check_database_connectivity(),
      sandbox_mode: check_sandbox_mode(),
      supervision_tree: analyze_supervision_tree(),
      process_registry: check_process_registry()
    }

    # Log a summary of findings
    log_diagnostic_summary(diagnostics)

    diagnostics
  end

  @doc """
  Attempts to repair common database test issues automatically.

  This function:
  1. Terminates stale connections
  2. Restarts unresponsive repositories
  3. Resets sandbox mode if needed

  Returns :ok if repairs were attempted, or {:error, reason} if repairs failed.
  """
  def repair_environment do
    Logger.info("Attempting to repair database test environment")

    # First run diagnostics to identify issues
    diagnostics = run_diagnostics()

    # Repair steps based on diagnostic results
    with :ok <- terminate_stale_connections(),
         :ok <- restart_unavailable_repos(diagnostics.repos),
         :ok <- reset_sandbox_mode(diagnostics.sandbox_mode) do

      # Run diagnostics again to verify repairs
      after_diagnostics = run_diagnostics()

      # Check if repairs were successful
      if environment_healthy?(after_diagnostics) do
        Logger.info("Database environment successfully repaired")
        :ok
      else
        Logger.error("Database environment still has issues after repair attempt")
        {:error, :repair_failed}
      end
    else
      {:error, stage, reason} ->
        Logger.error("Repair failed at stage '#{stage}': #{inspect(reason)}")
        {:error, {stage, reason}}
    end
  end

  @doc """
  Returns a formatted report of the current database environment status.

  This is useful for debugging test failures related to database issues.
  """
  def generate_status_report do
    diagnostics = run_diagnostics()

    report = """
    ===============================================================
    DATABASE TEST ENVIRONMENT STATUS REPORT
    Generated at: #{DateTime.to_string(diagnostics.timestamp)}
    ===============================================================

    REPOSITORY STATUS:
    #{format_repo_status(diagnostics.repos)}

    DATABASE CONNECTIVITY:
    #{format_connectivity_status(diagnostics.database_connectivity)}

    SANDBOX MODE:
    #{format_sandbox_status(diagnostics.sandbox_mode)}

    SUPERVISION TREE:
    #{format_supervision_tree(diagnostics.supervision_tree)}

    PROCESS REGISTRY:
    #{format_process_registry(diagnostics.process_registry)}

    OVERALL HEALTH: #{if environment_healthy?(diagnostics), do: "HEALTHY ✓", else: "ISSUES DETECTED ✗"}

    RECOMMENDED ACTIONS:
    #{generate_recommendations(diagnostics)}
    ===============================================================
    """

    # Log the report
    Logger.info("Database status report generated")

    # Return the report string
    report
  end

  # Private helper functions for diagnostics

  defp check_repositories do
    Enum.map(@repos, fn repo ->
      pid = Process.whereis(repo)

      status = if pid do
        # Check if the process is responsive
        try do
          # Try to get the state to check responsiveness
          case :sys.get_state(pid, 1000) do
            state when is_map(state) or is_tuple(state) ->
              # Try a simple query to check connectivity
              try do
                repo.query("SELECT 1", [], timeout: 2000)
                :responsive
              catch
                _, _ -> :unresponsive
              end
            _ -> :unresponsive
          end
        catch
          _, _ -> :unresponsive
        end
      else
        :not_running
      end

      {repo, %{pid: pid, status: status}}
    end)
    |> Enum.into(%{})
  end

  defp check_database_connectivity do
    # Get the database names, with fallbacks
    main_db_name = get_main_db_name()
    event_db_name = get_event_db_name()

    # Check connectivity to each database
    main_db = check_db_connectivity(main_db_name)
    event_db = check_db_connectivity(event_db_name)

    %{
      main_db: main_db,
      event_db: event_db
    }
  end

  # Helper functions to get database names with fallbacks
  defp get_main_db_name do
    case DatabaseConfig.main_test_db() do
      nil ->
        # Try fallback from direct config
        db_name = Application.get_env(:game_bot, GameBot.Infrastructure.Persistence.Repo)[:database]
        if is_nil(db_name), do: "game_bot_test", else: db_name
      name -> name
    end
  end

  defp get_event_db_name do
    case DatabaseConfig.event_test_db() do
      nil ->
        # Try fallback from direct config
        db_name = Application.get_env(:game_bot, GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres)[:database]
        if is_nil(db_name), do: "game_bot_eventstore_test", else: db_name
      name -> name
    end
  end

  defp check_db_connectivity(db_name) do
    # Add fallback values if db_name is nil
    effective_db_name = if is_nil(db_name) do
      Logger.warning("Database name is nil, using fallback name 'postgres'")
      "postgres"
    else
      db_name
    end

    # Try to create a direct connection to the database
    connection_info = [
      username: "postgres",
      password: "csstarahid",
      hostname: "localhost",
      database: effective_db_name,
      port: 5432
    ]

    Logger.info("Trying to connect to database: #{effective_db_name}")

    try do
      case Postgrex.start_link(connection_info) do
        {:ok, conn} ->
          # Try a simple query
          result = case Postgrex.query(conn, "SELECT 1", []) do
            {:ok, _} ->
              Logger.info("Successfully connected to database: #{effective_db_name}")
              :connected
            {:error, reason} ->
              Logger.error("Query failed on database #{effective_db_name}: #{inspect(reason)}")
              {:error, reason}
          end

          # Always close the connection
          GenServer.stop(conn)

          result

        {:error, reason} ->
          Logger.error("Failed to connect to database #{effective_db_name}: #{inspect(reason)}")
          {:error, reason}
      end
    catch
      kind, reason ->
        Logger.error("Exception when connecting to database #{effective_db_name}: #{inspect(kind)}, #{inspect(reason)}")
        {:error, {kind, reason}}
    end
  end

  defp check_sandbox_mode do
    # Check sandbox mode status for each repository
    Enum.map(@repos, fn repo ->
      case Process.whereis(repo) do
        nil -> {repo, :not_running}
        _pid ->
          try do
            # Try to access sandbox mode
            Ecto.Adapters.SQL.Sandbox.mode(repo, :manual)
            {repo, :configured}
          catch
            _, _ -> {repo, :error}
          end
      end
    end)
    |> Enum.into(%{})
  end

  defp analyze_supervision_tree do
    # This is a simplified version - in a real implementation, you would
    # walk the supervision tree to find relevant processes

    # For now, just check for key supervisor processes
    main_supervisor = Process.whereis(GameBot.Infrastructure.Supervisor)
    repo_supervisor = find_repo_supervisor()

    %{
      main_supervisor: main_supervisor,
      repo_supervisor: repo_supervisor,
      repo_supervision_path: find_repo_supervision_path()
    }
  end

  defp find_repo_supervisor do
    # This is a placeholder implementation
    nil
  end

  defp find_repo_supervision_path do
    # This is a placeholder implementation
    []
  end

  defp check_process_registry do
    # Get registered processes
    registered = Process.registered()

    # Filter for relevant processes
    db_related = Enum.filter(registered, fn name ->
      name_str = Atom.to_string(name)
      String.contains?(name_str, "Repo") or
      String.contains?(name_str, "Database") or
      String.contains?(name_str, "Postgres") or
      String.contains?(name_str, "EventStore")
    end)

    %{
      registered_count: length(registered),
      database_related: db_related
    }
  end

  # Repair functions

  defp terminate_stale_connections do
    Logger.info("Terminating stale database connections")

    try do
      # Try to connect to admin database
      {:ok, conn} = Postgrex.start_link([
        username: "postgres",
        password: "csstarahid",
        hostname: "localhost",
        database: "postgres",
        port: 5432
      ])

      # Terminate connections to our test databases
      terminate_query = """
      SELECT pg_terminate_backend(pid)
      FROM pg_stat_activity
      WHERE datname ~ '^game_bot_.*_test_'
      AND pid <> pg_backend_pid();
      """

      case Postgrex.query(conn, terminate_query, []) do
        {:ok, result} ->
          terminated_count = result.num_rows
          Logger.info("Terminated #{terminated_count} stale database connections")

        {:error, reason} ->
          Logger.error("Failed to terminate stale connections: #{inspect(reason)}")
          {:error, :terminate_connections, reason}
      end

      # Always close the connection
      GenServer.stop(conn)

      :ok
    catch
      kind, reason ->
        Logger.error("Error terminating connections: #{inspect(kind)}, #{inspect(reason)}")
        {:error, :terminate_connections, {kind, reason}}
    end
  end

  defp restart_unavailable_repos(repo_status) do
    Logger.info("Restarting unavailable repositories")

    # Filter repos that need restart
    repos_to_restart = Enum.filter(repo_status, fn {_repo, status} ->
      status.status == :not_running or status.status == :unresponsive
    end)
    |> Enum.map(fn {repo, _} -> repo end)

    # Restart each repository
    results = Enum.map(repos_to_restart, fn repo ->
      Logger.debug("Restarting repository: #{inspect(repo)}")

      # Stop the repo if it's running
      if Process.whereis(repo) do
        try do
          repo.stop()
          Process.sleep(500) # Give it time to stop
        catch
          _, _ -> :ok
        end
      end

      # Determine config based on repo type
      config = case repo do
        GameBot.Infrastructure.Persistence.Repo ->
          DatabaseConfig.main_db_config()
        GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres ->
          DatabaseConfig.event_db_config()
        GameBot.Infrastructure.Persistence.Repo.Postgres ->
          # This is specific to the test environment
          [
            username: "postgres",
            password: "csstarahid",
            hostname: "localhost",
            database: DatabaseConfig.main_test_db(),
            port: 5432,
            pool: Ecto.Adapters.SQL.Sandbox
          ]
        _ -> nil
      end

      if config do
        try do
          case repo.start_link(config) do
            {:ok, _pid} -> {:ok, repo}
            {:error, reason} -> {:error, repo, reason}
          end
        catch
          kind, reason -> {:error, repo, {kind, reason}}
        end
      else
        {:error, repo, :no_config}
      end
    end)

    # Check for any errors
    errors = Enum.filter(results, fn
      {:ok, _} -> false
      {:error, _, _} -> true
    end)

    if Enum.empty?(errors) do
      :ok
    else
      {:error, :restart_repos, errors}
    end
  end

  defp reset_sandbox_mode(sandbox_status) do
    Logger.info("Resetting sandbox mode for repositories")

    # Reset sandbox mode for each repository
    results = Enum.map(sandbox_status, fn {repo, status} ->
      if status == :error do
        try do
          # Try to reset sandbox mode
          Ecto.Adapters.SQL.Sandbox.checkout(repo)
          Ecto.Adapters.SQL.Sandbox.mode(repo, :manual)
          {:ok, repo}
        catch
          kind, reason -> {:error, repo, {kind, reason}}
        end
      else
        {:ok, repo} # No reset needed
      end
    end)

    # Check for any errors
    errors = Enum.filter(results, fn
      {:ok, _} -> false
      {:error, _, _} -> true
    end)

    if Enum.empty?(errors) do
      :ok
    else
      {:error, :reset_sandbox, errors}
    end
  end

  # Helper functions for reporting

  defp environment_healthy?(diagnostics) do
    # Check if all repositories are responsive
    repos_healthy = Enum.all?(diagnostics.repos, fn {_repo, status} ->
      status.status == :responsive
    end)

    # Check if database connectivity is good
    db_healthy = diagnostics.database_connectivity.main_db == :connected &&
                 diagnostics.database_connectivity.event_db == :connected

    # Check if sandbox mode is configured
    sandbox_healthy = Enum.all?(diagnostics.sandbox_mode, fn {_repo, status} ->
      status == :configured
    end)

    repos_healthy && db_healthy && sandbox_healthy
  end

  defp log_diagnostic_summary(diagnostics) do
    # Count repositories by status
    repo_counts = Enum.reduce(diagnostics.repos, %{responsive: 0, unresponsive: 0, not_running: 0}, fn {_repo, status}, acc ->
      Map.update(acc, status.status, 1, &(&1 + 1))
    end)

    # Format database connectivity status properly
    main_db_status = format_db_status(diagnostics.database_connectivity.main_db)
    event_db_status = format_db_status(diagnostics.database_connectivity.event_db)

    Logger.info("""
    Database Diagnostics Summary:
    - Repositories: #{repo_counts.responsive} responsive, #{repo_counts.unresponsive} unresponsive, #{repo_counts.not_running} not running
    - Main DB: #{main_db_status}
    - Event DB: #{event_db_status}
    - Overall health: #{if environment_healthy?(diagnostics), do: "HEALTHY", else: "ISSUES DETECTED"}
    """)
  end

  # Helper to properly format database status for logging
  defp format_db_status(:connected), do: "Connected"
  defp format_db_status({:error, reason}) when is_binary(reason), do: "Error: #{reason}"
  defp format_db_status({:error, reason}), do: "Error: #{inspect(reason)}"
  defp format_db_status(status), do: inspect(status)

  defp format_repo_status(repos) do
    Enum.map(repos, fn {repo, status} ->
      status_icon = case status.status do
        :responsive -> "✓"
        :unresponsive -> "⚠"
        :not_running -> "✗"
      end

      "  #{inspect(repo)}: #{status_icon} #{status.status} (PID: #{inspect(status.pid)})"
    end)
    |> Enum.join("\n")
  end

  defp format_connectivity_status(connectivity) do
    main_db_status = case connectivity.main_db do
      :connected -> "✓ Connected"
      {:error, reason} -> "✗ Error: #{inspect(reason)}"
      other -> "? #{inspect(other)}"
    end

    event_db_status = case connectivity.event_db do
      :connected -> "✓ Connected"
      {:error, reason} -> "✗ Error: #{inspect(reason)}"
      other -> "? #{inspect(other)}"
    end

    """
      Main DB: #{main_db_status}
      Event DB: #{event_db_status}
    """
  end

  defp format_sandbox_status(sandbox) do
    Enum.map(sandbox, fn {repo, status} ->
      status_icon = case status do
        :configured -> "✓"
        :error -> "✗"
        :not_running -> "?"
      end

      "  #{inspect(repo)}: #{status_icon} #{status}"
    end)
    |> Enum.join("\n")
  end

  defp format_supervision_tree(tree) do
    main_supervisor_status = if tree.main_supervisor, do: "Running (PID: #{inspect(tree.main_supervisor)})", else: "Not running"
    repo_supervisor_status = if tree.repo_supervisor, do: "Running (PID: #{inspect(tree.repo_supervisor)})", else: "Not identified"

    """
      Main Supervisor: #{main_supervisor_status}
      Repository Supervisor: #{repo_supervisor_status}
      Supervision Path: #{inspect(tree.repo_supervision_path)}
    """
  end

  defp format_process_registry(registry) do
    db_processes = Enum.join(registry.database_related, "\n  ")

    """
      Total registered processes: #{registry.registered_count}
      Database-related processes:
      #{if db_processes == "", do: "  None found", else: "  #{db_processes}"}
    """
  end

  defp generate_recommendations(diagnostics) do
    recommendations = []

    # Add recommendations based on repository status
    recommendations = Enum.reduce(diagnostics.repos, recommendations, fn {repo, status}, acc ->
      case status.status do
        :not_running ->
          ["- Restart the #{inspect(repo)} repository" | acc]
        :unresponsive ->
          ["- Check for connection issues with #{inspect(repo)}" | acc]
        _ -> acc
      end
    end)

    # Add recommendations based on database connectivity
    recommendations = case diagnostics.database_connectivity do
      %{main_db: {:error, _}, event_db: {:error, _}} ->
        ["- Check PostgreSQL server is running and accessible" | recommendations]
      %{main_db: {:error, _}} ->
        ["- Check main database configuration and permissions" | recommendations]
      %{event_db: {:error, _}} ->
        ["- Check event store database configuration and permissions" | recommendations]
      _ -> recommendations
    end

    # Add recommendations based on sandbox mode
    sandbox_errors = Enum.filter(diagnostics.sandbox_mode, fn {_repo, status} -> status == :error end)
    recommendations = if !Enum.empty?(sandbox_errors) do
      ["- Reset sandbox mode for repositories with errors" | recommendations]
    else
      recommendations
    end

    # If no specific recommendations, provide general advice
    recommendations = if Enum.empty?(recommendations) do
      ["- No specific issues detected, run full diagnostic to investigate further"]
    else
      recommendations
    end

    # Add standard recommendations
    recommendations = [
      "- Ensure repository supervision tree is correctly configured",
      "- Check for test isolation issues between test modules" | recommendations
    ]

    Enum.reverse(recommendations) |> Enum.join("\n")
  end
end
