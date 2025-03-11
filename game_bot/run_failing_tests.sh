#!/bin/bash

echo "Running only failing tests..."

# Define color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Set environment to test mode
export MIX_ENV=test

# Limit the number of pooled connections
export ECTO_POOL_SIZE=5
export ECTO_TIMEOUT=60000
export ECTO_CONNECT_TIMEOUT=60000
export ECTO_OWNERSHIP_TIMEOUT=120000

# Disable PostgreSQL paging to prevent interactive prompts
export PAGER=cat
export PGSTYLEPAGER=cat

# Function to handle errors
handle_error() {
  echo -e "${RED}Error: $1${NC}"
  cleanup_all_resources
  exit 1
}

# Function to clean up resources on exit
cleanup_all_resources() {
  echo -e "${BLUE}Performing comprehensive cleanup...${NC}"
  
  # Kill any beam processes related to our app
  if command -v pkill > /dev/null; then
    echo "Terminating any beam processes..."
    pkill -f "iex.*game_bot" || true
    pkill -f "mix.*game_bot" || true
    pkill -9 -f "beam.*game_bot" || true
  fi
  
  # Terminate all connections to non-postgres databases
  echo "Terminating all test database connections..."
  PGPASSWORD=csstarahid psql -P pager=off -U postgres -h localhost -d postgres -c "
    SELECT pg_terminate_backend(pid) 
    FROM pg_stat_activity 
    WHERE datname != 'postgres' 
    AND pid <> pg_backend_pid();" || true
  
  echo -e "${BLUE}Comprehensive cleanup complete${NC}"
}

# Register cleanup function to run on exit
trap cleanup_all_resources EXIT SIGINT SIGTERM

# Check if PostgreSQL is running
echo -e "${BLUE}Checking PostgreSQL status...${NC}"
if ! PGPASSWORD=csstarahid pg_isready -h localhost -U postgres > /dev/null 2>&1; then
  handle_error "PostgreSQL is not running. Please start PostgreSQL before running tests."
fi

# List of failing test files and patterns
echo -e "${YELLOW}Running only failing tests...${NC}"
mix test \
  test/game_bot/bot/command_handler_test.exs:103 \
  test/game_bot/infrastructure/persistence/event_store/postgres_test.exs:55 \
  test/game_bot/infrastructure/persistence/event_store/postgres_test.exs:62 \
  test/game_bot/infrastructure/persistence/event_store/postgres_test.exs:72 \
  test/game_bot/infrastructure/persistence/event_store/postgres_test.exs:81 \
  test/game_bot/infrastructure/persistence/event_store/postgres_test.exs:95 \
  test/game_bot/infrastructure/persistence/event_store/postgres_test.exs:110 \
  test/game_bot/infrastructure/persistence/event_store/postgres_test.exs:116 \
  test/game_bot/infrastructure/persistence/event_store/postgres_test.exs:129 \
  test/game_bot/infrastructure/persistence/event_store/postgres_test.exs:134 \
  test/game_bot/infrastructure/persistence/event_store/postgres_test.exs:143 \
  test/game_bot/infrastructure/persistence/event_store/postgres_test.exs:157 \
  test/game_bot/infrastructure/persistence/event_store/postgres_test.exs:165 \
  test/game_bot/infrastructure/persistence/event_store/adapter/postgres_test.exs:23 \
  --trace || handle_error "Tests failed"

# Display success message
echo -e "${GREEN}All tests ran (still may have failures)!${NC}"
cleanup_all_resources
echo -e "${GREEN}Cleanup complete.${NC}" 