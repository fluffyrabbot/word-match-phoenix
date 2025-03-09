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
  
  # Terminate all connections to test databases
  echo "Terminating all test database connections..."
  PGPASSWORD=csstarahid psql -P pager=off -U postgres -h localhost -d postgres -c "
    SELECT pg_terminate_backend(pid) 
    FROM pg_stat_activity 
    WHERE datname LIKE 'game_bot_test_%' 
    AND pid <> pg_backend_pid();" || true
  
  # Drop test databases older than 1 hour
  echo "Dropping old test databases..."
  PGPASSWORD=csstarahid psql -P pager=off -U postgres -h localhost -d postgres -c "
    DO \$\$
    DECLARE
      db_name text;
      current_db_ts bigint;
      db_ts bigint;
    BEGIN
      FOR db_name IN 
        SELECT datname 
        FROM pg_database 
        WHERE datname LIKE 'game_bot_test_%'
        AND datname NOT IN ('${MAIN_DB}', '${EVENT_DB}')
      LOOP
        -- Extract timestamp from database name
        db_ts := (regexp_matches(db_name, '_(\d+)$'))[1]::bigint;
        current_db_ts := extract(epoch from now())::bigint;
        
        -- Drop if older than 1 hour
        IF (current_db_ts - db_ts) > 3600 THEN
          EXECUTE 'DROP DATABASE IF EXISTS ' || quote_ident(db_name);
        END IF;
      END LOOP;
    END \$\$;" || true
  
  echo -e "${BLUE}Comprehensive cleanup complete${NC}"
}

# Register cleanup function to run on exit
trap cleanup_all_resources EXIT INT TERM

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
  database: "${MAIN_DB}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5,
  ownership_timeout: 60_000

config :game_bot, GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres,
  database: "${EVENT_DB}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5,
  ownership_timeout: 60_000

config :game_bot, GameBot.Infrastructure.Persistence.EventStore,
  database: "${EVENT_DB}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5,
  ownership_timeout: 60_000

config :game_bot, GameBot.Infrastructure.Persistence.Repo.Postgres,
  database: "${MAIN_DB}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5,
  ownership_timeout: 60_000

# Store database names in application env for access in scripts
config :game_bot, :test_databases,
  main_db: "${MAIN_DB}",
  event_db: "${EVENT_DB}"
EOF

# Count tests by scanning for test modules and test functions directly
echo -e "${BLUE}Counting total tests available...${NC}"
# This counts test modules
MODULE_COUNT=$(grep -r "^\s*use ExUnit.Case" test/ | wc -l)
# This counts test functions
AVAILABLE_TESTS=$(grep -r "^\s*test " test/ | wc -l)

echo -e "${BLUE}Found ${MODULE_COUNT} test modules with approximately ${AVAILABLE_TESTS} test functions${NC}"

# Run the tests with optimized settings and longer timeouts
echo -e "${YELLOW}Running tests...${NC}"

# Create a temporary file to capture test output
TEST_OUTPUT_FILE=$(mktemp)

# Run tests and capture output
if mix test --trace --seed 0 --max-cases 1 | tee "$TEST_OUTPUT_FILE"; then
  # Extract test statistics more reliably
  STATS_LINE=$(grep -o "[0-9]\\+ tests, [0-9]\\+ failures" "$TEST_OUTPUT_FILE" | tail -1)
  if [ -n "$STATS_LINE" ]; then
    TOTAL_TESTS=$(echo "$STATS_LINE" | grep -o "^[0-9]\\+")
    FAILED_TESTS=$(echo "$STATS_LINE" | grep -o "[0-9]\\+ failures" | grep -o "^[0-9]\\+")
  else
    TOTAL_TESTS=0
    FAILED_TESTS=0
  fi
  
  # Calculate passed tests and success rate safely
  PASSED_TESTS=$((TOTAL_TESTS - FAILED_TESTS))
  if [ "$TOTAL_TESTS" -gt 0 ]; then
    SUCCESS_RATE=$(echo "scale=1; ($PASSED_TESTS * 100) / $TOTAL_TESTS" | bc)
  else
    SUCCESS_RATE="0.0"
  fi
  
  # Extract coverage if available
  COVERAGE=$(grep -oP '\d+\.\d+%' "$TEST_OUTPUT_FILE" | head -n 1 || echo "N/A")
  
  # Print summary
  echo -e "\n${BLUE}=== TEST SUMMARY ===${NC}"
  echo -e "Total Tests:    ${TOTAL_TESTS}"
  echo -e "Passed Tests:   ${PASSED_TESTS}"
  echo -e "Failed Tests:   ${FAILED_TESTS}"
  echo -e "Success Rate:   ${SUCCESS_RATE}%"
  echo -e "Test Coverage:  ${COVERAGE}"
  
  # Clean up
  rm -f "$TEST_OUTPUT_FILE"
  
  # Exit with appropriate status
  if [ "$FAILED_TESTS" -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
  else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
  fi
else
  # Tests failed to run
  rm -f "$TEST_OUTPUT_FILE"
  handle_error "Tests failed to run properly"
fi 