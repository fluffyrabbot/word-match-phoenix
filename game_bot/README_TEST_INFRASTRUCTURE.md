# GameBot Test Infrastructure

This document explains the test infrastructure for the GameBot project, including the new Mix task for running tests with proper database setup.

## Overview

The GameBot test suite requires proper database setup and cleanup to run reliably. Previously, this was handled by shell scripts that needed to be run manually. Now, we've integrated this functionality into a Mix task that handles everything automatically.

## Running Tests

### Using the Mix Task

Instead of running `mix test` directly, use:

```bash
mix game_bot.test
```

This will:
1. Create unique test databases with timestamp-based names
2. Initialize database schemas
3. Run tests with proper configuration
4. Clean up resources afterward

All standard Mix test options are supported:

```bash
# Run specific tests
mix game_bot.test test/some/path.exs

# Run with tags
mix game_bot.test --exclude integration

# Run with trace
mix game_bot.test --trace
```

### Manual Database Setup (Legacy Approach)

If needed, you can still use the shell scripts directly:

```bash
# Setup test databases
./setup_test_db.sh

# Run tests
./run_tests.sh

# Reset test databases
./reset_test_db.sh
```

## Test Infrastructure Components

### Mix Task

The `Mix.Tasks.GameBot.Test` module (`lib/mix/tasks/game_bot/test.ex`) provides the `mix game_bot.test` task. This task:

- Sets appropriate environment variables
- Checks if PostgreSQL is running
- Creates and configures test databases
- Runs tests
- Cleans up resources

### Database Setup Module

The `GameBot.Test.DatabaseSetup` module (`lib/game_bot/test/database_setup.ex`) handles:

- Creating test databases with unique names
- Initializing database schemas
- Updating application configuration
- Cleaning up resources

## Common Issues and Solutions

### PostgreSQL Not Running

If PostgreSQL is not running, you'll see an error like:

```
PostgreSQL is not running: localhost:5432 - no response
Please start PostgreSQL before running tests.
```

Solution: Start PostgreSQL using your system's service manager.

### Database Connection Issues

If you're having issues with database connections, you can try:

```bash
# Reset all test databases
mix game_bot.test --reset-only

# Or use the shell script
./reset_test_db.sh
```

### Test Timeouts

If tests are timing out, it may be due to database connection issues. Try:

1. Reducing the number of concurrent tests: `mix game_bot.test --max-cases=1`
2. Increasing timeouts: `ECTO_TIMEOUT=60000 mix game_bot.test`

## Environment Variables

The following environment variables affect test behavior:

| Variable | Default | Description |
|----------|---------|-------------|
| `ECTO_POOL_SIZE` | 5 | Number of database connections in the pool |
| `ECTO_TIMEOUT` | 30000 | Timeout for database operations (ms) |
| `ECTO_CONNECT_TIMEOUT` | 30000 | Timeout for database connections (ms) |
| `ECTO_OWNERSHIP_TIMEOUT` | 60000 | Timeout for ownership (ms) |

## Adding New Tests

When adding new tests that interact with the database:

1. Use `setup` blocks to ensure proper database setup
2. Use `on_exit` callbacks to clean up resources
3. Consider using tags to categorize tests

Example:

```elixir
defmodule MyTest do
  use ExUnit.Case
  
  # Skip in CI environments
  @moduletag :skip_in_ci
  
  # For database-heavy tests
  @tag :database
  test "database operation" do
    # Test code
  end
end
```

## Continuous Integration

In CI environments, the test infrastructure automatically detects CI-specific settings and adjusts accordingly. No special configuration is needed.

## Troubleshooting

### Checking Database Status

To check the status of your test databases:

```bash
psql -U postgres -c "SELECT datname FROM pg_database WHERE datname LIKE 'game_bot%';"
```

### Manually Terminating Connections

If you're having issues with database connections:

```bash
psql -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname LIKE 'game_bot%' AND pid <> pg_backend_pid();"
```

### Viewing Test Logs

Test logs are written to `log/test.log`. You can view them with:

```bash
tail -f log/test.log
```

## Contributing

When making changes to the test infrastructure:

1. Update this documentation
2. Add tests for new functionality
3. Ensure backward compatibility with existing tests
4. Test on all supported platforms 