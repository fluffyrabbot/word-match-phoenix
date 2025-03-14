#!/bin/bash
# Script to run tests with improved repository verification

set -e  # Exit on error

echo "=== Running tests with improved repository verification ==="

# Ensure PostgreSQL is running
echo "Checking if PostgreSQL is running..."
if ! PGPASSWORD=csstarahid pg_isready -h localhost -U postgres > /dev/null 2>&1; then
  echo "❌ PostgreSQL is not running or not accessible!"
  echo "Please start PostgreSQL before running tests."
  exit 1
else
  echo "✓ PostgreSQL is running and accessible."
fi

# Terminate any lingering database connections
echo "Terminating existing database connections..."
PGPASSWORD=csstarahid psql -h localhost -U postgres -d postgres -c "
  SELECT pg_terminate_backend(pid) 
  FROM pg_stat_activity 
  WHERE datname LIKE 'game_bot_%' 
  AND pid <> pg_backend_pid();" || true

# Run a specific test to verify the fix
echo "Testing: adapter_test.exs"
mix test test/game_bot/infrastructure/persistence/event_store/adapter_test.exs

# If the above test passes, run integration tests
if [ $? -eq 0 ]; then
  echo "Testing: integration_test.exs"
  mix test test/game_bot/infrastructure/persistence/event_store/integration_test.exs
fi

# If all specific tests pass, run the full test suite
if [ $? -eq 0 ]; then
  echo "Running all tests..."
  mix test
fi

echo "=== Test run complete ===" 