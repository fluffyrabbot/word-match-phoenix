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

# Check if database setup has been done
if ! grep -q "game_bot_test_" config/test.exs || ! grep -q "game_bot_eventstore_test_" config/test.exs; then
  echo -e "${YELLOW}Database configuration not found. Running database setup first...${NC}"
  ./setup_test_db.sh || handle_error "Failed to set up test databases"
fi

# Set up event store schema and tables
echo -e "${BLUE}Setting up event store schema and tables...${NC}"
db_name=$(grep -o 'event_db_name = "[^"]*' config/test.exs | sed 's/event_db_name = "//')
echo -e "${BLUE}Cleaning up previous event store schema...${NC}"
PGPASSWORD=csstarahid psql -h localhost -U postgres -d "$db_name" -c "DROP SCHEMA IF EXISTS event_store CASCADE; CREATE SCHEMA event_store;" || handle_error "Failed to create event store schema"

# Run the tests with optimized settings and longer timeouts
echo -e "${YELLOW}Running tests...${NC}"
echo "Event store setup complete!"
mix test || handle_error "Tests failed"

# Display success message
echo -e "${GREEN}All tests passed successfully!${NC}"
cleanup_all_resources
echo -e "${GREEN}Cleanup complete.${NC}" 