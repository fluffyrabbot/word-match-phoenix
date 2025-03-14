# Actual database setup logic
defp do_setup_databases(state) do
  Logger.info("Setting up test databases...")

  # First ensure any existing repos are stopped
  stop_existing_repos()

  # Then try to create and start each database with proper error handling
  with :ok <- ensure_no_existing_connections(state),
       {:ok, _} <- create_or_reset_database(DatabaseConfig.main_test_db(), state),
       :ok <- wait_for_database_availability(DatabaseConfig.main_test_db(), state),
       {:ok, main_pid} <- start_repo(GameBot.Infrastructure.Persistence.Repo, DatabaseConfig.main_db_config()),
       {:ok, _} <- create_or_reset_database(DatabaseConfig.event_test_db(), state),
       :ok <- wait_for_database_availability(DatabaseConfig.event_test_db(), state),
       {:ok, event_pid} <- start_repo(GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres, DatabaseConfig.event_db_config()),
       {:ok, event_store_pid} <- start_event_store()
  do
    Logger.info("Successfully set up test databases")
    # Preserve all existing state fields while updating only the PIDs
    {:ok, %State{state |
      main_db_pid: main_pid,
      event_db_pid: event_pid,
      event_store_pid: event_store_pid
    }}
  else
    {:error, reason} ->
      Logger.error("Failed to set up test databases: #{inspect(reason)}")
      {:error, reason}
  end
end
