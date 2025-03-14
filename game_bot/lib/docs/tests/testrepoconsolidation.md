# Test Repository Consolidation Checklist

## Current Problems

- [x] Multiple places attempt to start repositories (test_helper.exs and EventStoreCase)
- [x] Repository startup verification is insufficient
- [x] Process termination timing issues between stop/restart
- [x] Missing explicit transaction handling
- [x] Missing test schema tables needed by tests

## Key Principles

1. **Single Source of Truth**: Only one module should be responsible for starting repositories
2. **Verify Before Testing**: Ensure repositories are fully operational before any tests run
3. **Clean State**: Each test should start with a clean database state
4. **Explicit Cleanup**: Always clean up connections and transactions
5. **Fail Fast**: Halt the test run if repositories fail to initialize properly

## Implementation Checklist

### 1. Repository Initialization

- [ ] Designate test_helper.exs as the ONLY place that starts repositories
- [ ] Remove repository startup logic from EventStoreCase
- [ ] Add explicit verification that triggers each repository with a test query
- [ ] Halt test run with clear error message if repos fail to start

```elixir
# Sample verification code
defp verify_repository(repo) do
  try
    # Try an actual query to verify the connection works
    repo.query!("SELECT 1")
    IO.puts("  ✓ Repository #{inspect(repo)} is fully operational")
    :ok
  rescue
    e ->
      IO.puts("\n❌ ERROR: Repository #{inspect(repo)} failed connection test: #{inspect(e)}")
      {:error, e}
  end
end
```

### 2. Process Management

- [ ] Add sufficient delays between stopping/starting repositories
- [ ] Clear ETS tables explicitly before repository restart
- [ ] Clean up Application environment settings between test runs
- [ ] Add process monitoring to detect unexpected repository crashes

```elixir
# Sample robust stop/start sequence
repos |> Enum.each(fn repo ->
  # Stop properly
  if Process.whereis(repo) do
    GenServer.stop(repo)
    # Wait longer for process termination
    Process.sleep(500)
  end
  
  # Verify process is really gone
  if Process.whereis(repo), do: Process.exit(Process.whereis(repo), :kill)
  Process.sleep(100)
end)
```

### 3. Transaction Management

- [ ] Add explicit transaction rollback in test cleanup
- [ ] Always check connections back in after tests
- [ ] Handle unexpected process messages that might lock connections
- [ ] Add timeout detection and recovery for long-running tests

```elixir
# Sample on_exit handler
on_exit(fn ->
  Enum.each(repos, fn repo ->
    try
      # First check if there are any active transactions and roll them back
      if Process.whereis(repo) do
        try
          # Try to rollback any lingering transactions
          Sandbox.checkout(repo)
          :ok = repo.rollback(fn -> :ok end)
        rescue
          _ -> :ok
        end

        # Then check in the connection
        Sandbox.checkin(repo)
      end
    rescue
      e -> Logger.warning("Error in test cleanup: #{inspect(e)}")
    end
  end)
end)
```

### 4. Database Schema Management

- [x] Create test_schema migration (already done)
- [ ] Add explicit migration runner in test_helper.exs
- [ ] Verify all required schemas and tables exist
- [ ] Add table cleanup between tests

```elixir
# Sample migration runner
defp run_migrations(repo) do
  # Get migration path
  migrations_path = Path.join(["priv", "repo", "migrations"])
  
  # Run migrations
  Ecto.Migrator.run(repo, migrations_path, :up, all: true)
end
```

### 5. Integration with EventStoreCase

- [ ] Update EventStoreCase to use repositories started by test_helper.exs
- [ ] Remove duplicate setup logic in EventStoreCase
- [ ] Add clear error handling for integration tests
- [ ] Ensure setup_all properly runs only once

## Testing the Fixes

- [ ] Run individual problematic test files in isolation
- [ ] Verify repository processes remain stable throughout test run
- [ ] Run full test suite with increased verbosity
- [ ] Verify no repository errors appear in the logs

## Maintainability Guidelines

1. Never start repositories in multiple places
2. Always verify repository connections with actual queries
3. Use long timeouts for database operations in tests
4. Add explicit logging for repository lifecycle events
5. Isolate test schemas from production schemas
6. Fail fast when repository initialization has problems 