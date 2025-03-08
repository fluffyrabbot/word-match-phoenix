defmodule Mix.Tasks.GameBot.TestDbSetup do
  @moduledoc """
  Mix task to set up all databases needed for testing.
  Properly cleans and recreates databases to ensure a clean test environment.

  ## Examples

      mix game_bot.test_db_setup
  """

  use Mix.Task

  @shortdoc "Recreates test databases from scratch for testing"

  @doc false
  def run(_args) do
    # Start PostgreSQL adapter
    {:ok, _} = Application.ensure_all_started(:postgrex)

    # Start Ecto
    {:ok, _} = Application.ensure_all_started(:ecto_sql)

    # Configure the repositories
    repos = Application.get_env(:game_bot, :ecto_repos, [])
    event_store = Application.get_env(:game_bot, :event_stores, [])

    # Execute SQL commands directly
    # This is much more reliable than using Ecto's functions
    # which have complex dependencies

    # Drop and create the test database
    execute_sql("DROP DATABASE IF EXISTS game_bot_test;")
    execute_sql("DROP DATABASE IF EXISTS game_bot_eventstore_test;")
    execute_sql("CREATE DATABASE game_bot_test ENCODING UTF8;")
    execute_sql("CREATE DATABASE game_bot_eventstore_test ENCODING UTF8;")

    # Now run the migrations
    run_migrations(repos)

    # Initialize event store
    run_event_store_setup(event_store)

    :ok
  end

  defp execute_sql(sql) do
    # Connect to postgres database to execute system commands
    {:ok, conn} = Postgrex.start_link(
      hostname: "localhost",
      username: "postgres",
      password: "csstarahid",
      database: "postgres"
    )

    case Postgrex.query(conn, sql, []) do
      {:ok, _} -> :ok
      {:error, %{postgres: %{code: :duplicate_database}}} -> :ok
      {:error, error} ->
        Mix.shell().error("SQL Error: #{inspect(error)}")
        :error
    end

    GenServer.stop(conn)
  end

  defp run_migrations(repos) do
    Enum.each(repos, fn repo ->
      Mix.shell().info("Running migrations for #{inspect(repo)}...")

      # Start the repository
      {:ok, _pid} = start_repo(repo)

      # Run migrations
      path = Path.join(["priv", "repo", "migrations"])
      Ecto.Migrator.run(repo, path, :up, all: true, log_migrations: :info)
    end)
  end

  defp run_event_store_setup(event_stores) do
    Enum.each(event_stores, fn event_store ->
      Mix.shell().info("Initializing event store #{inspect(event_store)}...")
      Code.eval_string("#{event_store}.initialize!()")
    end)
  end

  defp start_repo(repo) do
    repo.start_link(pool_size: 2, log: :info)
  end
end
