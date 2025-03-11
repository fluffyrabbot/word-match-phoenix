defmodule GameBot.Test.DatabaseSetupTest do
  use ExUnit.Case, async: false

  alias GameBot.Test.DatabaseSetup

  # Skip these tests in CI environments or when explicitly excluded
  @moduletag :database_setup
  @moduletag :skip_in_ci

  setup do
    # Store original database configuration
    original_repo_config = Application.get_env(:game_bot, GameBot.Infrastructure.Persistence.Repo)
    original_event_store_config = Application.get_env(:game_bot, GameBot.Infrastructure.Persistence.EventStore)

    on_exit(fn ->
      # Restore original configuration
      Application.put_env(:game_bot, GameBot.Infrastructure.Persistence.Repo, original_repo_config)
      Application.put_env(:game_bot, GameBot.Infrastructure.Persistence.EventStore, original_event_store_config)

      # Clean up any test databases that were created
      main_db = System.get_env("TEST_DB_MAIN")
      event_db = System.get_env("TEST_DB_EVENT")

      if main_db, do: DatabaseSetup.drop_database(main_db)
      if event_db, do: DatabaseSetup.drop_database(event_db)
    end)

    :ok
  end

  describe "setup_test_databases/0" do
    @tag :skip_in_ci
    test "creates databases with unique names" do
      # Run the setup function
      {:ok, db_names} = DatabaseSetup.setup_test_databases()

      # Verify the database names are returned
      assert is_binary(db_names.main_db)
      assert is_binary(db_names.event_db)
      assert String.starts_with?(db_names.main_db, "game_bot_test_")
      assert String.starts_with?(db_names.event_db, "game_bot_eventstore_test_")

      # Verify the databases exist
      assert database_exists?(db_names.main_db)
      assert database_exists?(db_names.event_db)

      # Verify the event store schema exists
      assert schema_exists?(db_names.event_db, "event_store")

      # Verify the application configuration was updated
      repo_config = Application.get_env(:game_bot, GameBot.Infrastructure.Persistence.Repo)
      event_store_config = Application.get_env(:game_bot, GameBot.Infrastructure.Persistence.EventStore)

      assert Keyword.get(repo_config, :database) == db_names.main_db
      assert Keyword.get(event_store_config, :database) == db_names.event_db
    end
  end

  describe "cleanup_resources/0" do
    @tag :skip_in_ci
    test "cleans up test databases" do
      # First set up the databases
      {:ok, db_names} = DatabaseSetup.setup_test_databases()

      # Set environment variables
      System.put_env("TEST_DB_MAIN", db_names.main_db)
      System.put_env("TEST_DB_EVENT", db_names.event_db)

      # Verify the databases exist
      assert database_exists?(db_names.main_db)
      assert database_exists?(db_names.event_db)

      # Run the cleanup function
      :ok = DatabaseSetup.cleanup_resources()

      # Verify the databases no longer exist
      refute database_exists?(db_names.main_db)
      refute database_exists?(db_names.event_db)
    end
  end

  # Helper functions for testing database operations

  defp database_exists?(db_name) do
    sql = "SELECT 1 FROM pg_database WHERE datname = '#{db_name}';"
    {output, 0} = System.cmd("psql", [
      "-h", "localhost",
      "-U", "postgres",
      "-d", "postgres",
      "-t", # Tuple output
      "-c", sql
    ], env: [{"PGPASSWORD", "csstarahid"}], stderr_to_stdout: true)

    String.trim(output) != ""
  end

  defp schema_exists?(db_name, schema_name) do
    sql = "SELECT 1 FROM information_schema.schemata WHERE schema_name = '#{schema_name}';"
    {output, 0} = System.cmd("psql", [
      "-h", "localhost",
      "-U", "postgres",
      "-d", db_name,
      "-t", # Tuple output
      "-c", sql
    ], env: [{"PGPASSWORD", "csstarahid"}], stderr_to_stdout: true)

    String.trim(output) != ""
  end
end
