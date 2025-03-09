# Test Suite Stability Improvements

## Overview

This document outlines the improvements made to the test suite to resolve inconsistent test counts during sequential test runs. The original issue was that running `./run_tests.sh` multiple times in a row would yield different numbers of executed tests.

## Root Cause Analysis

After thorough investigation, we identified multiple interconnected issues:

1. **Database Connection Management**: 
   - Database connections from previous test runs weren't being fully cleaned up
   - New test runs were using unique timestamps but suffering from connection pool limits

2. **Repository Initialization**:
   - The `GameBot.Infrastructure.Persistence.Repo.Postgres` repository was defined separately but wasn't properly initialized in all cases
   - Error handling during repository initialization was insufficient

3. **Test Discovery and Execution**:
   - Tests that depend on database connections were failing early in the first run
   - As more connections became available in subsequent runs, more tests would pass
   - The test counter only counted tests that actually ran, not total tests

4. **EventStore Configuration**:
   - There were timing issues with EventStore initialization
   - Event store registrations weren't correctly synchronized

5. **Resource Cleanup**:
   - The cleanup process wasn't thoroughly clearing PostgreSQL connections
   - Old test databases weren't being dropped, causing resource leaks

## Solution Architecture

Our fix addresses each identified issue with a comprehensive solution:

### 1. Centralized Test Setup (New `GameBot.Test.Setup` Module)

- Implemented in `test/support/test_setup.ex`
- Centralizes all test environment initialization
- Manages database connections with proper error handling
- Provides retry mechanisms for repository startup
- Verifies repository availability before test execution
- Can restart repositories when needed

### 2. Improved Test Helper

- Modified `test/test_helper.exs` to use the centralized setup
- Added max_failures limit to prevent endless failing tests
- Ensures proper initialization sequence
- Provides explicit exit

### 3. Enhanced Repository Test Case

- Improved `test/support/repository_case.ex`
- Added repository availability checks
- Implemented safe checkout mechanism that handles errors
- Proper cleanup of resources after tests

### 4. Robust Test Runner Script

- Enhanced `run_tests.sh` with several improvements:
  - Added function to clean up old test databases
  - Improved test counting to show both executed and available tests
  - Added test coverage reporting
  - More comprehensive cleanup process

### 5. Systematic Error Handling

- Added proper error handling throughout the test setup process
- Implemented retry mechanisms for transient failures
- Added detailed logging to help diagnose issues

## Technical Details

### Database Connection Management

```sql
-- Clean old test databases to prevent resource leaks
DO $$
BEGIN
  FOR db_name IN 
    SELECT datname FROM pg_database 
    WHERE datname LIKE 'game_bot_test_%' 
    AND datname != '${MAIN_DB}'
    AND datname != '${EVENT_DB}'
  LOOP
    EXECUTE 'DROP DATABASE IF EXISTS ' || quote_ident(db_name);
  END LOOP;
END $$;
```

### Repository Initialization

```elixir
def start_repo_with_retry(repo, retries \\ 3) do
  result = start_repo(repo)
  
  case result do
    :ok -> :ok
    :error ->
      if retries > 0 do
        IO.puts("Retrying start of #{inspect(repo)}, #{retries-1} attempts left")
        Process.sleep(1000)
        start_repo_with_retry(repo, retries - 1)
      else
        :error
      end
  end
end
```

### Repository Checkout

```elixir
safe_checkout = fn repo ->
  try do
    {:ok, owner} = Ecto.Adapters.SQL.Sandbox.checkout(repo)
    
    # Set sandbox mode based on async flag
    unless async? do
      Ecto.Adapters.SQL.Sandbox.mode(repo, {:shared, self()})
    end
    
    owner
  rescue
    e ->
      IO.puts("ERROR: Failed to checkout #{inspect(repo)}: #{Exception.message(e)}")
      nil
  end
end
```

### Test Counting

```bash
# Count tests by scanning for test modules and test functions directly
MODULE_COUNT=$(grep -r "^\s*use ExUnit.Case" test/ | wc -l)
AVAILABLE_TESTS=$(grep -r "^\s*test " test/ | wc -l)

# Calculate test coverage percentage
if [ "$AVAILABLE_TESTS" -gt 0 ]; then
  TEST_COVERAGE=$((TOTAL_TESTS * 100 / AVAILABLE_TESTS))
else
  TEST_COVERAGE=0
fi
```

## Usage Guide

### Running Tests

The test command remains the same:

```bash
cd game_bot && ./run_tests.sh
```

The script now includes:
- Better progress indication
- Test coverage statistics
- More robust error handling

### Sequential Test Runs

Running tests sequentially is now much more reliable:

```bash
cd game_bot && ./run_tests.sh && ./run_tests.sh && ./run_tests.sh
```

All three runs should now report consistent test counts and coverage.

### Debugging Test Setup

If you encounter test setup issues, you'll find more detailed logging throughout the process:
- Repository initialization status
- Database connection management
- Test environment setup

Look for messages prefixed with `===` for important status updates.

## Benefits

1. **Consistent Test Execution**: Tests now run consistently across multiple executions
2. **Resource Management**: Better cleanup of database connections prevents resource leaks
3. **Transparent Metrics**: You now see both executed tests and total available tests
4. **Resilience**: The setup process can recover from many types of failures
5. **Documentation**: The process is now well-documented for future maintenance

## Limitations and Next Steps

While these improvements significantly enhance the test suite stability, there are potential future improvements:

1. **Parallel Testing**: The solution currently runs tests serially (`max_cases: 1`) to avoid connection issues. Future work could focus on making parallel testing more robust.

2. **Test Classification**: Tests could be classified to separate those requiring database access from pure unit tests, allowing for faster test runs.

3. **Test Isolation**: Further improve isolation between tests to prevent side effects.

4. **Continuous Integration**: Consider adding these improvements to CI/CD pipeline configurations for consistent testing in automated environments.

## Conclusion

The implemented improvements address the core issues causing inconsistent test behavior. The solution provides a robust testing foundation with proper resource management, error handling, and transparent metrics.

---

Document Author: Claude 3.7 Sonnet  
Date: 2025-03-09 