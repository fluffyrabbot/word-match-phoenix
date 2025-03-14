defmodule Mix.Tasks.GameBot.DbTestDiagnose do
  @moduledoc """
  Tests database connectivity and diagnoses issues with the test environment.

  This task will:
  1. Check if the main database and event store database are accessible
  2. Verify that all required repositories are running
  3. Provide detailed diagnostics about the test database environment
  4. Optionally attempt repairs for common issues

  ## Usage

  ```
  # Run diagnostics only
  mix game_bot.db_test_diagnose

  # Run diagnostics and attempt automatic repairs
  mix game_bot.db_test_diagnose --repair
  ```
  """

  use Mix.Task
  require Logger

  @shortdoc "Diagnoses and fixes database issues in the test environment"

  # List of all repositories to check
  @repos [
    GameBot.Infrastructure.Persistence.Repo,
    GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
  ]

  @doc false
  def run(args) do
    # Parse command line arguments
    {opts, _, _} = OptionParser.parse(args,
      switches: [repair: :boolean, debug: :boolean],
      aliases: [r: :repair, d: :debug]
    )

    # Start required applications
    Application.ensure_all_started(:postgrex)
    Application.ensure_all_started(:ecto_sql)
    Application.ensure_all_started(:ecto)

    # Turn on debug logging if requested
    if opts[:debug] do
      Logger.configure(level: :debug)
    end

    IO.puts("=== GameBot Test Database Diagnostics ===\n")

    # Run diagnostics
    diagnostics = run_diagnostics()
    print_diagnostics(diagnostics)

    # Attempt repairs if requested
    if opts[:repair] do
      IO.puts("\n=== Attempting repairs ===\n")
      repair_result = attempt_repairs(diagnostics)

      # Run diagnostics again after repairs to show the new state
      IO.puts("\n=== Final Diagnostics After Repairs ===\n")
      final_diagnostics = run_diagnostics()
      print_diagnostics(final_diagnostics)

      IO.puts("\n=== Repair Process Complete ===")
      if repair_result == :ok do
        IO.puts("Repairs completed successfully!")
      else
        IO.puts("Some repairs could not be completed. Please check the output above.")
      end
    else
      # Show repair recommendations
      print_repair_recommendations(diagnostics)
    end
  end

  defp run_diagnostics do
    # Check database connections
    main_db_status = check_main_database()
    event_db_status = check_event_database()

    # Check repositories
    repo_statuses = check_repositories()

    # Check event store schema
    event_schema_status = check_event_store_schema()

    # Calculate overall health
    overall_health = calculate_overall_health(main_db_status, event_db_status, repo_statuses, event_schema_status)

    # Build diagnostics map
    %{
      main_db: main_db_status,
      event_db: event_db_status,
      repositories: repo_statuses,
      event_schema: event_schema_status,
      overall_health: overall_health,
      timestamp: DateTime.utc_now()
    }
  end

  defp check_main_database do
    db_name = get_main_db_name()
    IO.puts("Checking main database: #{db_name}")

    conn_info = [
      hostname: "localhost",
      username: "postgres",
      password: "csstarahid",
      database: db_name,
      connect_timeout: 5000
    ]

    case Postgrex.start_link(conn_info) do
      {:ok, conn} ->
        # Try a test query
        case Postgrex.query(conn, "SELECT 1 as test", [], []) do
          {:ok, %{rows: [[1]]}} ->
            GenServer.stop(conn)
            %{status: :connected, message: "Connection successful"}
          {:error, error} ->
            GenServer.stop(conn)
            %{status: :error, message: "Query failed: #{inspect(error)}"}
        end
      {:error, error} ->
        %{status: :error, message: "Connection failed: #{inspect(error)}"}
    end
  end

  defp check_event_database do
    db_name = get_event_db_name()
    IO.puts("Checking event database: #{db_name}")

    conn_info = [
      hostname: "localhost",
      username: "postgres",
      password: "csstarahid",
      database: db_name,
      connect_timeout: 5000
    ]

    case Postgrex.start_link(conn_info) do
      {:ok, conn} ->
        # Try a test query
        case Postgrex.query(conn, "SELECT 1 as test", [], []) do
          {:ok, %{rows: [[1]]}} ->
            GenServer.stop(conn)
            %{status: :connected, message: "Connection successful"}
          {:error, error} ->
            GenServer.stop(conn)
            %{status: :error, message: "Query failed: #{inspect(error)}"}
        end
      {:error, error} ->
        %{status: :error, message: "Connection failed: #{inspect(error)}"}
    end
  end

  defp check_repositories do
    IO.puts("Checking repository status:")

    Enum.map(@repos, fn repo ->
      repo_name = repo |> Module.split() |> List.last()
      IO.puts("  - #{repo_name}...")

      if Process.whereis(repo) do
        pid = Process.whereis(repo)

        # Check if the process is alive
        if Process.alive?(pid) do
          # Try to run a simple query to verify connection
          try do
            case repo.query("SELECT 1 as test", [], timeout: 5000) do
              {:ok, _} ->
                %{name: repo, status: :running, message: "Repository is running and responsive"}
              {:error, error} ->
                %{name: repo, status: :error, message: "Repository is running but query failed: #{inspect(error)}"}
            end
          rescue
            e ->
              %{name: repo, status: :error, message: "Repository is running but query raised exception: #{Exception.message(e)}"}
          end
        else
          %{name: repo, status: :error, message: "Repository process exists but is not alive"}
        end
      else
        %{name: repo, status: :not_running, message: "Repository is not running"}
      end
    end)
  end

  defp check_event_store_schema do
    db_name = get_event_db_name()
    IO.puts("Checking event store schema in #{db_name}")

    conn_info = [
      hostname: "localhost",
      username: "postgres",
      password: "csstarahid",
      database: db_name,
      connect_timeout: 5000
    ]

    case Postgrex.start_link(conn_info) do
      {:ok, conn} ->
        # Check if the event_store schema exists
        schema_query = """
        SELECT EXISTS(
          SELECT 1 FROM information_schema.schemata
          WHERE schema_name = 'event_store'
        )
        """

        schema_exists = case Postgrex.query(conn, schema_query, [], []) do
          {:ok, %{rows: [[true]]}} -> true
          _ -> false
        end

        # Check if the events table exists within the schema
        tables_query = """
        SELECT EXISTS(
          SELECT 1 FROM information_schema.tables
          WHERE table_schema = 'event_store'
          AND table_name = 'events'
        )
        """

        events_table_exists = if schema_exists do
          case Postgrex.query(conn, tables_query, [], []) do
            {:ok, %{rows: [[true]]}} -> true
            _ -> false
          end
        else
          false
        end

        GenServer.stop(conn)

        cond do
          schema_exists && events_table_exists ->
            %{status: :ok, message: "Event store schema and tables exist"}
          schema_exists && !events_table_exists ->
            %{status: :incomplete, message: "Event store schema exists but tables are missing"}
          true ->
            %{status: :missing, message: "Event store schema does not exist"}
        end

      {:error, error} ->
        %{status: :error, message: "Connection failed: #{inspect(error)}"}
    end
  end

  defp calculate_overall_health(main_db, event_db, repos, event_schema) do
    # Check if main database is connected
    main_db_ok = main_db.status == :connected

    # Check if event database is connected
    event_db_ok = event_db.status == :connected

    # Check if all repos are running
    all_repos_ok = Enum.all?(repos, fn repo -> repo.status == :running end)

    # Check if event schema is OK
    event_schema_ok = event_schema.status == :ok

    # Calculate overall status
    cond do
      main_db_ok && event_db_ok && all_repos_ok && event_schema_ok ->
        %{status: :healthy, message: "All systems operational"}
      main_db_ok && event_db_ok && !all_repos_ok ->
        %{status: :issues_detected, message: "Databases connected but repositories not running"}
      main_db_ok && !event_db_ok ->
        %{status: :critical, message: "Main database OK but event database unavailable"}
      !main_db_ok ->
        %{status: :critical, message: "Main database unavailable"}
      true ->
        %{status: :issues_detected, message: "Various issues detected"}
    end
  end

  defp print_diagnostics(diagnostics) do
    # Print database statuses
    IO.puts("Database Connectivity:")
    IO.puts("  Main Database:  #{status_to_string(diagnostics.main_db.status)} - #{diagnostics.main_db.message}")
    IO.puts("  Event Database: #{status_to_string(diagnostics.event_db.status)} - #{diagnostics.event_db.message}")

    # Print repository statuses
    IO.puts("\nRepository Status:")
    Enum.each(diagnostics.repositories, fn repo ->
      repo_name = repo.name |> Module.split() |> List.last()
      IO.puts("  #{repo_name}: #{status_to_string(repo.status)} - #{repo.message}")
    end)

    # Print event store schema status
    IO.puts("\nEvent Store Schema:")
    IO.puts("  #{status_to_string(diagnostics.event_schema.status)} - #{diagnostics.event_schema.message}")

    # Print overall health
    IO.puts("\nOverall Health: #{status_to_string(diagnostics.overall_health.status)} - #{diagnostics.overall_health.message}")
  end

  defp status_to_string(:connected), do: IO.ANSI.green() <> "CONNECTED" <> IO.ANSI.reset()
  defp status_to_string(:running), do: IO.ANSI.green() <> "RUNNING" <> IO.ANSI.reset()
  defp status_to_string(:ok), do: IO.ANSI.green() <> "OK" <> IO.ANSI.reset()
  defp status_to_string(:healthy), do: IO.ANSI.green() <> "HEALTHY" <> IO.ANSI.reset()
  defp status_to_string(:not_running), do: IO.ANSI.red() <> "NOT RUNNING" <> IO.ANSI.reset()
  defp status_to_string(:error), do: IO.ANSI.red() <> "ERROR" <> IO.ANSI.reset()
  defp status_to_string(:missing), do: IO.ANSI.red() <> "MISSING" <> IO.ANSI.reset()
  defp status_to_string(:critical), do: IO.ANSI.red() <> "CRITICAL" <> IO.ANSI.reset()
  defp status_to_string(:issues_detected), do: IO.ANSI.yellow() <> "ISSUES DETECTED" <> IO.ANSI.reset()
  defp status_to_string(:incomplete), do: IO.ANSI.yellow() <> "INCOMPLETE" <> IO.ANSI.reset()
  defp status_to_string(other), do: "#{other}"

  defp print_repair_recommendations(diagnostics) do
    IO.puts("\n=== Recommended Actions ===")

    # Check main database
    if diagnostics.main_db.status != :connected do
      IO.puts("- Create main database: mix ecto.create")
    end

    # Check event database
    if diagnostics.event_db.status != :connected do
      IO.puts("- Create event database: mix game_bot.create_event_store_db")
    end

    # Check event schema
    if diagnostics.event_schema.status != :ok && diagnostics.event_db.status == :connected do
      IO.puts("- Create event store schema: mix game_bot.create_event_store_db")
    end

    # Check repositories
    not_running_repos = Enum.filter(diagnostics.repositories, fn repo -> repo.status != :running end)
    if length(not_running_repos) > 0 do
      IO.puts("- Restart repositories: GameBot.Test.DatabaseManager.initialize()")
      IO.puts("- Check for test isolation issues")
    end

    # Overall recommendation
    if diagnostics.overall_health.status != :healthy do
      IO.puts("\nRun automatic repairs with: mix game_bot.db_test_diagnose --repair")
    end
  end

  defp attempt_repairs(diagnostics) do
    # Track success of each repair
    results = []

    # Step 1: Terminate any stale connections
    IO.puts("Terminating stale database connections...")
    results = [terminate_connections() | results]

    # Step 2: Start repositories that aren't running
    if Enum.any?(diagnostics.repositories, fn repo -> repo.status != :running end) do
      IO.puts("Restarting unavailable repositories...")
      results = [restart_repositories(diagnostics.repositories) | results]
    end

    # Check for any failures
    if Enum.any?(results, fn result -> result != :ok end) do
      IO.puts("Some repairs could not be completed.")
      {:error, :repair_incomplete}
    else
      :ok
    end
  end

  defp terminate_connections do
    # Connect to postgres admin database
    conn_info = [
      hostname: "localhost",
      username: "postgres",
      password: "csstarahid",
      database: "postgres",
      connect_timeout: 5000
    ]

    case Postgrex.start_link(conn_info) do
      {:ok, conn} ->
        # Terminate connections to both databases
        query = """
        SELECT pg_terminate_backend(pid)
        FROM pg_stat_activity
        WHERE pid <> pg_backend_pid()
        AND datname IN ($1, $2)
        """

        main_db = get_main_db_name()
        event_db = get_event_db_name()

        case Postgrex.query(conn, query, [main_db, event_db], []) do
          {:ok, _} ->
            GenServer.stop(conn)
            IO.puts("Successfully terminated existing connections")
            :ok
          {:error, error} ->
            GenServer.stop(conn)
            IO.puts("Error terminating connections: #{inspect(error)}")
            {:error, :termination_failed}
        end

      {:error, error} ->
        IO.puts("Failed to connect to PostgreSQL: #{inspect(error)}")
        {:error, :connection_failed}
    end
  end

  defp restart_repositories(repo_statuses) do
    # Get list of repositories that need restarting
    repos_to_restart = Enum.filter(repo_statuses, fn repo ->
      repo.status != :running
    end)
    |> Enum.map(fn repo -> repo.name end)

    # Try to start each repository
    Enum.each(repos_to_restart, fn repo ->
      repo_name = repo |> Module.split() |> List.last()
      IO.puts("Restarting #{repo_name}...")

      # First stop the repo if it has a process
      if Process.whereis(repo) do
        try do
          GenServer.stop(Process.whereis(repo), :normal, 5000)
          Process.sleep(500) # Give it time to stop
        rescue
          _ -> :ok
        end
      end

      # Configure the repository if needed
      config = Application.get_env(:game_bot, repo)
      if is_nil(config) do
        if repo == GameBot.Infrastructure.Persistence.Repo do
          Application.put_env(:game_bot, repo, [
            database: get_main_db_name(),
            username: "postgres",
            password: "csstarahid",
            hostname: "localhost",
            pool: Ecto.Adapters.SQL.Sandbox,
            pool_size: 10
          ])
        else
          Application.put_env(:game_bot, repo, [
            database: get_event_db_name(),
            username: "postgres",
            password: "csstarahid",
            hostname: "localhost",
            pool: Ecto.Adapters.SQL.Sandbox,
            pool_size: 10,
            schema_prefix: "event_store"
          ])
        end
      end

      # Try to start the repository
      attempt_count = 3
      Enum.reduce_while(1..attempt_count, {:error, :not_started}, fn attempt, _acc ->
        IO.puts("  Attempt #{attempt}/#{attempt_count}...")

        try do
          # Start the repository
          case repo.start_link(Application.get_env(:game_bot, repo)) do
            {:ok, _pid} ->
              IO.puts("  Repository started successfully")
              {:halt, :ok}
            {:error, {:already_started, _pid}} ->
              IO.puts("  Repository already started")
              {:halt, :ok}
            {:error, error} ->
              if attempt == attempt_count do
                IO.puts("  Failed to start repository: #{inspect(error)}")
                {:halt, {:error, error}}
              else
                Process.sleep(500 * attempt)
                {:cont, {:error, error}}
              end
          end
        rescue
          e ->
            IO.puts("  Error starting repository: #{Exception.message(e)}")
            if attempt == attempt_count do
              {:halt, {:error, e}}
            else
              Process.sleep(500 * attempt)
              {:cont, {:error, e}}
            end
        end
      end)
    end)

    # Check if all repositories are now running
    all_running = Enum.all?(@repos, fn repo ->
      Process.whereis(repo) && Process.alive?(Process.whereis(repo))
    end)

    if all_running do
      :ok
    else
      {:error, :repositories_not_started}
    end
  end

  defp get_main_db_name do
    Application.get_env(:game_bot, :test_databases)[:main_db] || "game_bot_test"
  end

  defp get_event_db_name do
    Application.get_env(:game_bot, :test_databases)[:event_db] || "game_bot_eventstore_dev"
  end
end
