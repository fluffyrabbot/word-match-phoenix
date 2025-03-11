defmodule Mix.Tasks.GameBot.MigrateTestSetup do
  @moduledoc """
  Mix task to help migrate test files to use the new database management system.

  This task will:
  1. Detect and clean up old test databases
  2. Update configuration files
  3. Remove deprecated shell scripts
  4. Scan test files for required updates
  5. Provide guidance for manual updates needed

  ## Usage

      mix game_bot.migrate_test_setup [--dry-run]

  ## Options
    * `--dry-run` - Show what would be changed without making changes
  """

  use Mix.Task
  require Logger

  @shortdoc "Migrates test files to use the new database management system"

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: [dry_run: :boolean])
    dry_run = Keyword.get(opts, :dry_run, false)

    Logger.info("Starting test setup migration#{if dry_run, do: " (dry run)", else: ""}")

    # Load the application config
    Mix.Task.run("loadconfig")

    # Start only the Repo with postgres database
    {:ok, _} = Application.ensure_all_started(:postgrex)
    {:ok, _} = Application.ensure_all_started(:ecto)

    # Get the database configuration from the application config
    repo_config = [
      username: "postgres",
      password: "csstarahid",
      hostname: "localhost",
      database: "postgres",
      pool_size: 10
    ]

    {:ok, _} = GameBot.Infrastructure.Persistence.Repo.start_link(repo_config)

    with :ok <- cleanup_old_databases(dry_run),
         :ok <- update_config_files(dry_run),
         :ok <- remove_deprecated_files(dry_run),
         {:ok, files} <- scan_test_files(dry_run) do
      print_summary(files)
      print_next_steps()
    else
      {:error, step, reason} ->
        Logger.error("Migration failed during #{step}: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  # Step 1: Clean up old test databases
  defp cleanup_old_databases(dry_run) do
    Logger.info("Cleaning up old test databases...")

    # Find old test databases (those with timestamps)
    databases = find_old_databases()

    if dry_run do
      Logger.info("Would drop these databases: #{inspect(databases)}")
      :ok
    else
      drop_databases(databases)
    end
  end

  defp find_old_databases do
    # Query postgres to find databases matching old naming pattern
    {:ok, result} = Ecto.Adapters.SQL.query(
      GameBot.Infrastructure.Persistence.Repo,
      """
      SELECT datname FROM pg_database
      WHERE datname LIKE 'game_bot_test_%'
      OR datname LIKE 'game_bot_eventstore_test_%'
      """,
      []
    )

    result.rows |> List.flatten()
  end

  defp drop_databases(databases) do
    Enum.each(databases, fn db ->
      Logger.info("Dropping database #{db}")

      # Force disconnect all connections first
      {:ok, _} = Ecto.Adapters.SQL.query(
        GameBot.Infrastructure.Persistence.Repo,
        """
        SELECT pg_terminate_backend(pid)
        FROM pg_stat_activity
        WHERE datname = $1
        """,
        [db]
      )

      # Drop the database
      {:ok, _} = Ecto.Adapters.SQL.query(
        GameBot.Infrastructure.Persistence.Repo,
        "DROP DATABASE IF EXISTS #{db}",
        []
      )
    end)
    :ok
  end

  # Step 2: Update configuration files
  defp update_config_files(dry_run) do
    Logger.info("Updating configuration files...")

    files = [
      {"config/test.exs", &update_test_config/1},
      {"config/test.secret.exs", &update_test_config/1}
    ]

    Enum.reduce_while(files, :ok, fn {file, updater}, _acc ->
      case update_file(file, updater, dry_run) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, :config_update, reason}}
      end
    end)
  end

  defp update_file(file, updater, dry_run) do
    case File.read(file) do
      {:ok, content} ->
        updated = updater.(content)
        if dry_run do
          Logger.info("Would update #{file} with:\n#{updated}")
          :ok
        else
          case File.write(file, updated) do
            :ok ->
              Logger.info("Updated #{file}")
              :ok
            {:error, reason} ->
              {:error, "Failed to write #{file}: #{inspect(reason)}"}
          end
        end
      {:error, :enoent} ->
        Logger.info("File not found: #{file}")
        :ok
      {:error, reason} ->
        {:error, "Failed to read #{file}: #{inspect(reason)}"}
    end
  end

  defp update_test_config(content) do
    content
    |> String.replace(
      ~r/database: "game_bot_test_[^"]*"/,
      "database: \"game_bot_test\""
    )
    |> String.replace(
      ~r/database: "game_bot_eventstore_test_[^"]*"/,
      "database: \"game_bot_eventstore_test\""
    )
    |> String.replace(
      ~r/pool_size: \d+/,
      "pool_size: {:system, \"POOL_SIZE\", 10}"
    )
  end

  # Step 3: Remove deprecated files
  defp remove_deprecated_files(dry_run) do
    Logger.info("Removing deprecated files...")

    files = [
      "scripts/setup_test_db.sh",
      "lib/game_bot/test/database_setup.ex"
    ]

    if dry_run do
      Logger.info("Would remove these files: #{inspect(files)}")
      :ok
    else
      Enum.each(files, fn file ->
        case File.rm(file) do
          :ok -> Logger.info("Removed #{file}")
          {:error, :enoent} -> Logger.info("File already removed: #{file}")
          {:error, reason} -> Logger.warn("Failed to remove #{file}: #{inspect(reason)}")
        end
      end)
      :ok
    end
  end

  # Step 4: Scan test files
  defp scan_test_files(dry_run) do
    Logger.info("Scanning test files...")

    files =
      Path.wildcard("test/**/*_test.exs")
      |> Enum.map(&analyze_test_file/1)
      |> Enum.reject(&is_nil/1)

    if dry_run do
      Logger.info("Found #{length(files)} files needing updates")
      {:ok, files}
    else
      update_test_files(files)
    end
  end

  defp analyze_test_file(file) do
    content = File.read!(file)

    cond do
      String.contains?(content, "setup_test_db") or
      String.contains?(content, "DatabaseSetup") ->
        %{
          file: file,
          needs_setup: true,
          needs_sandbox: not String.contains?(content, "setup_sandbox")
        }

      String.contains?(content, "Repo.") and
      not String.contains?(content, "setup_sandbox") ->
        %{
          file: file,
          needs_setup: false,
          needs_sandbox: true
        }

      true ->
        nil
    end
  end

  defp update_test_files(files) do
    Enum.reduce_while(files, {:ok, []}, fn file, {:ok, updated} ->
      case update_test_file(file) do
        :ok -> {:cont, {:ok, [file | updated]}}
        {:error, reason} -> {:halt, {:error, :test_update, reason}}
      end
    end)
  end

  defp update_test_file(%{file: file} = info) do
    content = File.read!(file)

    updated =
      content
      |> remove_old_setup()
      |> add_new_setup(info)

    File.write!(file, updated)
    :ok
  end

  defp remove_old_setup(content) do
    content
    |> String.replace(~r/setup do.*?setup_test_db.*?end\n/s, "")
    |> String.replace(~r/alias.*?DatabaseSetup.*?\n/, "")
  end

  defp add_new_setup(content, %{needs_setup: needs_setup, needs_sandbox: needs_sandbox}) do
    setup = """
    setup tags do
      #{if needs_setup or needs_sandbox, do: "GameBot.Test.DatabaseManager.setup_sandbox(tags)"}
      :ok
    end

    """

    # Add after ExUnit.Case line
    String.replace(content, ~r/(use ExUnit\.Case.*?\n)/, "\\1\n#{setup}")
  end

  # Print summary and next steps
  defp print_summary(files) do
    Logger.info("""

    Migration Summary:
    ==================
    Files updated: #{length(files)}
    #{for f <- files, do: "  * #{f.file}"}
    """)
  end

  defp print_next_steps do
    Logger.info("""

    Next Steps:
    ===========
    1. Review the changes in your test files
    2. Update any custom test helpers to use DatabaseManager
    3. Remove any remaining direct database setup code
    4. Run your test suite to verify everything works

    For more information, see:
    * docs/test_patterns.md - Examples of common test patterns
    * docs/database_test_improvements.md - Overview of changes

    If you encounter any issues, please check the troubleshooting
    section in docs/test_patterns.md
    """)
  end
end
