#!/bin/bash

echo "Running tests..."

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

# Use consistent database names across the script
TIMESTAMP=$(date +%s)
export TEST_DB_TIMESTAMP=$TIMESTAMP
export MAIN_DB="game_bot_test_${TIMESTAMP}"
export EVENT_DB="game_bot_eventstore_test_${TIMESTAMP}"
echo -e "${BLUE}Using database names: MAIN_DB=$MAIN_DB, EVENT_DB=$EVENT_DB${NC}"

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

# Update the config file with our database names
echo -e "${BLUE}Updating test config with database names...${NC}"
cat > config/test.runtime.exs <<EOF
import Config

# Use predefined database names from environment
config :game_bot, GameBot.Infrastructure.Persistence.Repo,
  database: "${MAIN_DB}"

config :game_bot, GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres,
  database: "${EVENT_DB}"

config :game_bot, GameBot.Infrastructure.Persistence.EventStore,
  database: "${EVENT_DB}"

config :game_bot, GameBot.Infrastructure.Persistence.Repo.Postgres,
  database: "${MAIN_DB}"

# Store database names in application env for access in scripts
config :game_bot, :test_databases,
  main_db: "${MAIN_DB}",
  event_db: "${EVENT_DB}"
EOF

# Run the tests with optimized settings and longer timeouts
echo -e "${YELLOW}Running tests...${NC}"
TEST_DB_TIMESTAMP=$TIMESTAMP mix test $@ || handle_error "Tests failed"

# Display success message
echo -e "${GREEN}All tests passed successfully!${NC}"
cleanup_all_resources
echo -e "${GREEN}Cleanup complete.${NC}" 