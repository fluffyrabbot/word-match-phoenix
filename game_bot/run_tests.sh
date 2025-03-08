#!/bin/bash

echo "Running tests with clean database setup..."

# Define color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Set environment to test mode
export MIX_ENV=test

# Function to handle errors
handle_error() {
  echo -e "${RED}Error: $1${NC}"
  exit 1
}

# Check if PostgreSQL is running
echo -e "${BLUE}Checking PostgreSQL status...${NC}"
if ! pg_isready -h localhost -U postgres > /dev/null 2>&1; then
  handle_error "PostgreSQL is not running. Please start PostgreSQL before running tests."
fi

# Clean up the databases
echo -e "${BLUE}Dropping and recreating databases...${NC}"
PGPASSWORD=csstarahid psql -U postgres -h localhost -d postgres -c "DROP DATABASE IF EXISTS game_bot_test;" || handle_error "Failed to drop main database"
PGPASSWORD=csstarahid psql -U postgres -h localhost -d postgres -c "DROP DATABASE IF EXISTS game_bot_eventstore_test;" || handle_error "Failed to drop event store database"
PGPASSWORD=csstarahid psql -U postgres -h localhost -d postgres -c "CREATE DATABASE game_bot_test ENCODING 'UTF8';" || handle_error "Failed to create main database"
PGPASSWORD=csstarahid psql -U postgres -h localhost -d postgres -c "CREATE DATABASE game_bot_eventstore_test ENCODING 'UTF8';" || handle_error "Failed to create event store database"

# Run migrations
echo -e "${BLUE}Running migrations...${NC}"
mix ecto.migrate || handle_error "Failed to run migrations"

# Set up event store
echo -e "${BLUE}Setting up event store...${NC}"
mix game_bot.event_store_setup || handle_error "Failed to set up event store"

# Run the tests
echo -e "${YELLOW}Running tests...${NC}"
mix test $@ || handle_error "Tests failed"

# Display success message
echo -e "${GREEN}All tests passed successfully!${NC}" 