defmodule Mix.Tasks.GameBot.Test do
  @moduledoc """
  Runs tests with proper database setup and cleanup.

  This task ensures that test databases are properly created, initialized,
  and cleaned up before and after tests run. It uses the centralized
  DatabaseManager to handle all database operations.

  ## Usage

  ```
  mix game_bot.test                      # Run all tests
  mix game_bot.test test/some/path.exs   # Run specific tests
  mix game_bot.test --exclude integration # Run with tags
  mix game_bot.test --reset-only         # Just reset databases without running tests
  ```

  ## Environment Variables

  The following environment variables are set automatically:
  - `ECTO_POOL_SIZE`: Limits the number of pooled connections
  - `ECTO_TIMEOUT`: Timeout for database operations
  - `ECTO_CONNECT_TIMEOUT`: Timeout for database connections
  - `ECTO_OWNERSHIP_TIMEOUT`: Timeout for ownership
  """
  use Mix.Task

  alias GameBot.Test.{DatabaseManager, DatabaseConfig}

  @shortdoc "Run tests with proper database setup"
  def run(args) do
    # Parse arguments to check for --reset-only flag
    {opts, remaining_args} = parse_args(args)

    Mix.shell().info("Setting up test environment...")

    # Set environment variables for database connections
    System.put_env("MIX_ENV", "test")
    System.put_env("ECTO_POOL_SIZE", "5")
    System.put_env("ECTO_TIMEOUT", "30000")
    System.put_env("ECTO_CONNECT_TIMEOUT", "30000")
    System.put_env("ECTO_OWNERSHIP_TIMEOUT", "60000")

    # Disable PostgreSQL paging to prevent interactive prompts
    System.put_env("PAGER", "cat")
    System.put_env("PGSTYLEPAGER", "cat")

    # Check if PostgreSQL is running
    Mix.shell().info("Checking PostgreSQL status...")
    check_postgres_status()

    if opts[:reset_only] do
      # Just reset databases without running tests
      case DatabaseManager.initialize() do
        :ok -> :ok
        error ->
          Mix.shell().error("Failed to reset databases: #{inspect(error)}")
          exit({:shutdown, 1})
      end
    else
      # Setup test databases and run tests
      run_tests_with_setup(remaining_args)
    end
  end

  defp parse_args(args) do
    {opts, remaining_args, _} = OptionParser.parse(
      args,
      strict: [reset_only: :boolean],
      aliases: [r: :reset_only]
    )
    {opts, remaining_args}
  end

  defp run_tests_with_setup(args) do
    # Initialize database manager
    case DatabaseManager.initialize() do
      :ok ->
        Mix.shell().info("Test databases initialized successfully")

        # Run the tests
        Mix.shell().info("Running tests with proper database configuration...")
        try do
          result = Mix.Task.run("test", args)
          if result == 0, do: :ok, else: exit({:shutdown, 1})
        after
          # Always clean up resources
          Mix.shell().info("Cleaning up test environment...")
          DatabaseManager.cleanup()
        end

      error ->
        Mix.shell().error("Failed to initialize test databases: #{inspect(error)}")
        exit({:shutdown, 1})
    end
  end

  defp check_postgres_status do
    # Run a simple check to see if Postgres is running
    config = DatabaseConfig.admin_config()
    case Postgrex.start_link(config) do
      {:ok, conn} ->
        case Postgrex.query(conn, "SELECT version()", [], []) do
          {:ok, result} ->
            Mix.shell().info("PostgreSQL is running: #{result.rows |> List.first() |> List.first()}")
            GenServer.stop(conn)
            :ok
          {:error, error} ->
            Mix.shell().error("PostgreSQL query failed: #{inspect(error)}")
            Mix.shell().error("Please check your PostgreSQL configuration.")
            exit({:shutdown, 1})
        end
      {:error, error} ->
        Mix.shell().error("PostgreSQL connection failed: #{inspect(error)}")
        Mix.shell().error("Please start PostgreSQL before running tests.")
        exit({:shutdown, 1})
    end
  end
end
