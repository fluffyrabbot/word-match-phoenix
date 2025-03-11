# Database Issues in Test Suite

This document outlines the database-related issues identified in the test suite, based on the test output analysis and examination of the test infrastructure code. These issues are causing significant test failures and slowdowns.

## Critical Issues

### 1. Repository Initialization Failures

#### Symptoms
- Error: `could not lookup Ecto repo GameBot.Infrastructure.Persistence.Repo because it was not started or it does not exist`
- Error: `could not lookup Ecto repo GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres because it was not started or it does not exist`
- Affects multiple test modules, particularly in `DiagnosticTest` and `EventStore` tests

#### Root Causes
1. **Race Conditions in Repository Startup**: The `GameBot.Test.Setup.initialize_repositories/0` function attempts to start repositories, but there appears to be race conditions or timing issues.
2. **Sandbox Mode Configuration**: The `Ecto.Adapters.SQL.Sandbox.mode/2` call may be failing or not properly configuring the repositories.
3. **Repository Restart Failures**: When repositories fail to start, the error handling in `ensure_repo_started/1` may not be robust enough.
4. **Initialization Lock Issues**: The initialization lock mechanism in `GameBot.Test.DatabaseHelper` may not be working correctly across all test processes.

#### Impact
- 59 test failures directly related to repository initialization
- Cascading failures in dependent tests
- Significant test suite slowdown

### 2. Event Store Schema Issues

#### Symptoms
- Error: `relation "event_store.streams" does not exist`
- Error: `relation "event_store.events" does not exist`
- Affects all tests that interact with the event store

#### Root Causes
1. **Missing Schema Creation**: The event store schema is not being created before tests run.
2. **Incomplete Initialization**: The `EventStore.Tasks.Init.exec/1` function may not be completing successfully.
3. **Timing Issues**: Schema creation may be happening after tests have already started.

#### Impact
- 37 test failures related to missing event store schema
- Prevents proper testing of event persistence

### 3. Test Timeouts

#### Symptoms
- Error: `test timed out after 60000ms`
- Affects long-running tests, particularly those with complex database interactions

#### Root Causes
1. **Connection Pool Exhaustion**: The connection pool may be getting exhausted, causing tests to wait indefinitely.
2. **Deadlocks**: Concurrent tests may be causing deadlocks in the database.
3. **Sandbox Mode Issues**: The sandbox mode may not be properly isolating test transactions.

#### Impact
- 12 test timeouts, primarily in integration tests
- Test suite execution time increased by ~2-3 minutes due to timeouts
- 60-second timeout per affected test is the major contributor to slow test runs

### 4. Event Store Not Running Warnings

#### Symptoms
- Warning: `The event store is not running`
- Affects tests that attempt to clean up event store resources

#### Root Causes
1. **Cleanup Order**: The event store may be stopped before cleanup operations complete.
2. **Missing Checks**: Cleanup functions may not be checking if the event store is running before attempting operations.

#### Impact
- Multiple warnings, but not directly causing test failures
- Potential resource leaks between tests
- Possible interference between test runs

## Existing Shell Scripts

The project currently includes three shell scripts for managing the test environment:

### 1. `setup_test_db.sh`
- Creates test databases with unique names
- Initializes database schemas
- Sets environment variables for test configuration

### 2. `run_tests.sh`
- Calls `setup_test_db.sh`
- Runs tests with proper environment variables
- Handles cleanup on test completion or failure

### 3. `reset_test_db.sh`
- Terminates all database connections
- Drops test databases
- Used for cleanup after tests

These scripts work well when run manually but are not integrated into the standard `mix test` workflow, requiring developers to remember to use them.

## Implemented Solution

To address these issues, we've implemented a new Mix task and supporting module:

### 1. `mix game_bot.test` Task
- Integrates the functionality of all three shell scripts
- Provides a seamless testing experience
- Ensures proper database setup and cleanup
- Supports all standard Mix test options

### 2. `GameBot.Test.DatabaseSetup` Module
- Creates test databases with unique names (timestamped)
- Initializes database schemas properly
- Updates application configuration
- Provides robust cleanup functionality
- Includes retry mechanisms for database operations

## Usage

Instead of running `mix test` directly, use:

```
mix game_bot.test
```

This will:
1. Create unique test databases
2. Initialize schemas
3. Run tests with proper configuration
4. Clean up resources afterward

All standard Mix test options are supported:

```
mix game_bot.test test/some/path.exs   # Run specific tests
mix game_bot.test --exclude integration # Run with tags
```

## Benefits Over Shell Scripts

The new implementation offers several advantages:

1. **Integration with Mix**: No need to remember to use a separate script
2. **Better Error Handling**: Proper Elixir error handling and reporting
3. **Improved Logging**: Structured logging with proper levels
4. **Retry Mechanisms**: Automatic retries for database operations
5. **Cross-Platform**: Works on all platforms that support Elixir
6. **Configurable**: Easy to modify without shell script knowledge

## Future Improvements

While the current implementation addresses the critical issues, future improvements could include:

1. **Parallel Test Support**: Better handling of parallel test runs
2. **Custom Migrations**: Support for test-specific migrations
3. **Database Snapshots**: Fast database resets using snapshots
4. **CI/CD Integration**: Special handling for CI/CD environments
5. **Test Tagging**: Automatic database setup based on test tags

## Detailed Analysis

### PostgreSQL Adapter Tests

The PostgreSQL adapter tests are particularly problematic, with multiple 60-second timeouts:

```
** (ExUnit.TimeoutError) test timed out after 60000ms. You can change the timeout:
```

These tests are attempting database operations but failing to connect properly. The timeout is set to 60 seconds in `test_helper.exs`, which means each failing test adds a full minute to the test suite execution time.

The `GameBot.Test.DatabaseConnectionManager` has a `@shutdown_timeout` of only 3000ms, which is inconsistent with the ExUnit timeout of 60000ms. This mismatch may be causing tests to wait for the full 60 seconds even when connections could be terminated much earlier.

### Event Store Integration Tests

The Event Store integration tests show a pattern of failures related to event serialization and database schema:

```
** (MatchError) no match of right hand side value: {:error, %GameBot.Infrastructure.Error{type: :system, context: GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres, message: "Database error", details: %Postgrex.Error{message: nil, postgres: %{code: :undefined_table, line: "1431", message: "relation \"event_store.streams\" does not exist", position: "21", file: "parse_relation.c", unknown: "ERROR", severity: "ERROR", pg_code: "42P01", routine: "parserOpenTable"}}}}
```

This indicates that the database schema for the event store is not being properly created or migrated in the test environment. The `GameBot.Test.Setup.initialize/0` function attempts to initialize repositories but may not be properly initializing the EventStore schema.

### Replay Storage Tests

The Replay Storage tests show inconsistencies in return value handling:

```
** (KeyError) key :replay_id not found in: {:ok,
  %{
    mode: :two_player,
    game_id: "test-game-19714",
    display_name: "test-replay-123",
    ...
```

This suggests that the tests expect direct values but are receiving `{:ok, value}` tuples, indicating an API change that wasn't reflected in the tests. The test assertions need to be updated to handle the new return format.

## Recommended Solutions

### 1. Integrate Shell Script Functionality

Instead of running the shell scripts manually, we should integrate their functionality directly into the test infrastructure:

```elixir
# Create a Mix task that runs tests with proper database setup
defmodule Mix.Tasks.GameBot.Test do
  @moduledoc "Run tests with proper database setup"
  use Mix.Task

  @shortdoc "Run tests with proper database setup"
  def run(args) do
    # Set up environment variables
    System.put_env("ECTO_POOL_SIZE", "5")
    System.put_env("ECTO_TIMEOUT", "30000")
    System.put_env("ECTO_CONNECT_TIMEOUT", "30000")
    System.put_env("ECTO_OWNERSHIP_TIMEOUT", "60000")
    
    # Create and configure test databases
    GameBot.Test.DatabaseSetup.setup_test_databases()
    
    # Run the tests
    Mix.Task.run("test", args)
  end
end

# Create an Elixir module that encapsulates the database setup logic
defmodule GameBot.Test.DatabaseSetup do
  def setup_test_databases do
    # Generate unique database names with timestamp
    timestamp = System.system_time(:second)
    main_db = "game_bot_test_#{timestamp}"
    event_db = "game_bot_eventstore_test_#{timestamp}"
    
    # Create databases
    create_database(main_db)
    create_database(event_db)
    
    # Update config
    update_config(main_db, event_db)
    
    # Initialize schemas
    initialize_schemas(main_db, event_db)
  end
  
  # Implementation details...
end
```

### 2. Fix Repository Initialization

```elixir
# In test_helper.exs or appropriate setup module
defmodule GameBot.Test.ImprovedDatabaseSetup do
  def start_repos do
    # Start Ecto repos explicitly with better error handling
    repos = [
      GameBot.Infrastructure.Persistence.Repo,
      GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
    ]
    
    # Stop any existing repos first
    Enum.each(repos, fn repo ->
      case Process.whereis(repo) do
        nil -> :ok
        pid -> 
          if Process.alive?(pid) do
            GenServer.stop(pid, :normal, 5000)
            # Wait for process to terminate
            ref = Process.monitor(pid)
            receive do
              {:DOWN, ^ref, :process, ^pid, _} -> :ok
            after
              1000 -> Process.exit(pid, :kill)
            end
          end
      end
    end)
    
    # Start each repo with proper error handling
    Enum.each(repos, fn repo ->
      config = Application.get_env(:game_bot, repo)
      case repo.start_link(config) do
        {:ok, _} -> :ok
        {:error, {:already_started, _}} -> :ok
        {:error, error} -> 
          raise "Failed to start #{inspect(repo)}: #{inspect(error)}"
      end
      
      # Verify repo is running
      unless Process.whereis(repo) && Process.alive?(Process.whereis(repo)) do
        raise "Repository #{inspect(repo)} failed to start properly"
      end
    end)
    
    # Configure sandbox mode
    Enum.each(repos, fn repo ->
      :ok = Ecto.Adapters.SQL.Sandbox.mode(repo, :manual)
    end)
    
    :ok
  end
end
```

### 3. Implement Event Store Schema Creation

```elixir
# In test_helper.exs or appropriate setup module
defmodule GameBot.Test.EventStoreSetup do
  def create_schema do
    # Get EventStore module
    event_store = GameBot.Infrastructure.Persistence.EventStore
    
    # Get configuration
    config = Application.get_env(:game_bot, event_store)
    
    # Ensure EventStore application is started
    Application.ensure_all_started(:eventstore)
    
    # Create database if it doesn't exist
    case EventStore.Tasks.Create.exec(config) do
      :ok -> 
        IO.puts("Created EventStore database")
        :ok
      {:error, :already_created} -> 
        IO.puts("EventStore database already exists")
        :ok
      error -> 
        raise "Failed to create EventStore database: #{inspect(error)}"
    end
    
    # Initialize schema with better error handling
    try do
      case EventStore.Tasks.Init.exec(config) do
        :ok -> 
          IO.puts("Initialized EventStore schema")
          :ok
        error -> 
          raise "Failed to initialize EventStore schema: #{inspect(error)}"
      end
    rescue
      e -> 
        # Check if error is because schema is already initialized
        if String.contains?(Exception.message(e), "already been initialized") do
          IO.puts("EventStore schema already initialized")
          :ok
        else
          reraise e, __STACKTRACE__
        end
    end
  end
end
```

### 4. Reduce Test Timeouts

```elixir
# In test_helper.exs
ExUnit.configure(
  exclude: [:skip_db],
  timeout: 15_000,  # Reduce from 60_000 to 15_000
  trace: false,
  seed: 0,
  formatters: [ExUnit.CLIFormatter]
)

# For specific test modules with database operations
defmodule GameBot.Infrastructure.Persistence.EventStore.PostgresTest do
  use ExUnit.Case
  
  # Set a more reasonable timeout for database tests
  @moduletag timeout: 20_000
  
  # For specific long-running tests
  @tag timeout: 30_000
  test "long-running database operation" do
    # Test code...
  end
end
```

### 5. Improve Cleanup Process

```elixir
# In DatabaseHelper module
def reset_event_store do
  # Check if event store is running before attempting to reset
  event_store = GameBot.Infrastructure.Persistence.EventStore
  
  case Process.whereis(event_store) do
    nil -> 
      Logger.warning("Event store is not running, cannot reset")
      :ok
    pid when is_pid(pid) ->
      if Process.alive?(pid) do
        # Event store is running, safe to reset
        try do
          event_store.reset()
          :ok
        rescue
          e ->
            Logger.warning("Error resetting event store: #{inspect(e)}")
            {:error, :reset_failed}
        end
      else
        Logger.warning("Event store process exists but is not alive")
        :ok
      end
  end
end

# Improve on_exit callback
def setup_test_cleanup do
  on_exit(fn ->
    # Use a more robust cleanup approach
    try do
      # First try graceful shutdown
      DatabaseConnectionManager.graceful_shutdown()
    catch
      kind, reason ->
        Logger.error("Error in graceful shutdown: #{inspect(kind)}, #{inspect(reason)}")
    after
      # Always attempt to terminate remaining connections
      try do
        DatabaseConnectionManager.terminate_all_connections()
      catch
        _, _ -> :ok
      end
    end
  end)
end
```

## Implementation Priority

1. **Integrate Shell Script Functionality** - Highest priority, as this will solve most issues immediately
   - Create Mix task for running tests with proper database setup
   - Port shell script functionality to Elixir modules
   - Update test helpers to use this functionality
   
2. **Repository Initialization** - Second priority, for remaining repository issues
   - Implement more robust repository startup with proper error handling
   - Add explicit verification that repositories are running
   - Fix race conditions in initialization

3. **Timeout Reduction** - Improves test suite execution time
   - Reduce the global timeout from 60 seconds to 15 seconds
   - Add specific timeouts for known long-running tests
   - Implement early failure detection for database operations

4. **Cleanup Process Improvement** - Reduces warnings and potential test interference
   - Add conditional checks before attempting to reset resources
   - Improve error handling in cleanup functions
   - Ensure proper cleanup order in after_suite callbacks

By addressing these issues in order, we can significantly improve the reliability and speed of the test suite. 