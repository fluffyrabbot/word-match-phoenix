#!/bin/bash

echo "Resetting test databases for game_bot..."

# Database parameters
PG_USER="postgres"
PG_PASSWORD="csstarahid"
PG_HOST="localhost"

# Use PGPASSWORD environment variable to avoid password prompt
export PGPASSWORD=$PG_PASSWORD

# Disable paging to prevent interactive prompts
export PAGER=cat
export PGSTYLEPAGER=cat

# Define a function to run psql with paging disabled
run_psql() {
  psql -P pager=off -U $PG_USER -h $PG_HOST "$@"
}

# Determine the database names from mix config or environment
echo "Reading database names..."

if [ -n "$TEST_DB_TIMESTAMP" ]; then
  # Use timestamp from environment
  TIMESTAMP=$TEST_DB_TIMESTAMP
  MAIN_DB="game_bot_test_${TIMESTAMP}"
  EVENT_DB="game_bot_eventstore_test_${TIMESTAMP}"
  echo "Using database names from environment variable: MAIN_DB=$MAIN_DB, EVENT_DB=$EVENT_DB"
else
  # Use grep to extract just the database name from the output
  MAIN_DB=$(cd $(dirname $0) && MIX_ENV=test mix run -e "IO.puts Application.get_env(:game_bot, :test_databases)[:main_db]" 2>/dev/null | grep -o "game_bot_test_[0-9]*")
  EVENT_DB=$(cd $(dirname $0) && MIX_ENV=test mix run -e "IO.puts Application.get_env(:game_bot, :test_databases)[:event_db]" 2>/dev/null | grep -o "game_bot_eventstore_test_[0-9]*")

  # Check if we got valid database names, otherwise use defaults with timestamp
  if [ -z "$MAIN_DB" ]; then
    TIMESTAMP=$(date +%s)
    MAIN_DB="game_bot_test_${TIMESTAMP}"
    EVENT_DB="game_bot_eventstore_test_${TIMESTAMP}"
    echo "WARNING: Could not determine database names from config, using generated names"
  fi
fi

echo "Using database names: MAIN_DB=$MAIN_DB, EVENT_DB=$EVENT_DB"

# Function to forcefully terminate all connections to a database
terminate_connections() {
  local db_name=$1
  echo "Forcefully terminating all connections to $db_name..."
  
  # First approach: Try pg_terminate_backend for specific database
  run_psql -d postgres -c "
    SELECT pg_terminate_backend(pid) 
    FROM pg_stat_activity 
    WHERE datname = '$db_name' 
    AND pid <> pg_backend_pid();"
    
  # Second approach: Use DO block for more aggressive termination
  run_psql -d postgres -c "
    DO \$\$
    DECLARE
      db_connections RECORD;
    BEGIN
      FOR db_connections IN
        SELECT pid FROM pg_stat_activity WHERE datname = '$db_name' AND pid <> pg_backend_pid()
      LOOP
        PERFORM pg_terminate_backend(db_connections.pid);
      END LOOP;
    END \$\$;"
    
  # Wait a moment to allow connections to terminate
  sleep 2
}

# Terminate ALL PostgreSQL connections except those to 'postgres' database
terminate_all_connections() {
  echo "Terminating ALL database connections..."
  run_psql -d postgres -c "
    SELECT pg_terminate_backend(pid) 
    FROM pg_stat_activity 
    WHERE datname != 'postgres' 
    AND pid <> pg_backend_pid();"
    
  # Sleep to allow connections to terminate
  sleep 3
}

# If possible, find and kill any Elixir processes that might be connected to the database
echo "Stopping any connected processes..."
if command -v pkill > /dev/null; then
  pkill -f "iex.*game_bot" || true
  pkill -f "mix.*game_bot" || true
  pkill -9 -f "beam.*game_bot" || true
else
  echo "pkill not available, skipping process termination"
fi

# First, terminate all connections to all databases
terminate_all_connections

# Then specifically target our test databases
if [ -n "$MAIN_DB" ]; then
  terminate_connections "$MAIN_DB"
else
  echo "WARNING: Main database name not available, using default"
  MAIN_DB="game_bot_test"
  terminate_connections "$MAIN_DB"
fi

if [ -n "$EVENT_DB" ]; then
  terminate_connections "$EVENT_DB"
else
  echo "WARNING: Event store database name not available, using default"
  EVENT_DB="game_bot_eventstore_test"
  terminate_connections "$EVENT_DB"
fi

# Check if any connections remain to the databases
check_connections() {
  local db_name=$1
  local conn_count=$(run_psql -d postgres -t -c "
    SELECT COUNT(*) FROM pg_stat_activity 
    WHERE datname = '$db_name' 
    AND pid <> pg_backend_pid();" | tr -d ' ')
  
  echo "Remaining connections to $db_name: $conn_count"
  return $conn_count
}

# Force drop by terminating all connections repeatedly if necessary
force_drop() {
  local db_name=$1
  local max_attempts=5
  local attempt=1
  
  while [ $attempt -le $max_attempts ]; do
    echo "Attempt $attempt to drop $db_name..."
    
    # Try to drop with FORCE option if available
    run_psql -d postgres -v ON_ERROR_STOP=0 -c "DROP DATABASE IF EXISTS \"$db_name\" WITH (FORCE);" 2>/dev/null || \
    run_psql -d postgres -v ON_ERROR_STOP=0 -c "DROP DATABASE IF EXISTS \"$db_name\";" 2>/dev/null
    
    # Check if database still exists
    local exists=$(run_psql -d postgres -t -c "
      SELECT COUNT(*) FROM pg_database WHERE datname = '$db_name';" | tr -d ' ')
    
    if [ "$exists" -eq "0" ]; then
      echo "Successfully dropped $db_name"
      return 0
    fi
    
    echo "Database $db_name still exists, terminating connections again..."
    terminate_connections "$db_name"
    terminate_all_connections
    
    sleep 2
    attempt=$((attempt + 1))
  done
  
  echo "WARNING: Failed to drop $db_name after $max_attempts attempts"
  return 1
}

# Try to drop main database with retries
echo "Dropping and recreating main test database ($MAIN_DB)..."
force_drop "$MAIN_DB" && \
run_psql -d postgres -c "CREATE DATABASE \"$MAIN_DB\" ENCODING 'UTF8';"

# Try to drop event store database with retries
echo "Dropping and recreating event store test database ($EVENT_DB)..."
force_drop "$EVENT_DB" && \
run_psql -d postgres -c "CREATE DATABASE \"$EVENT_DB\" ENCODING 'UTF8';"

# Set environment variable to ensure we use the test environment
export MIX_ENV=test

echo "Running migration for the main database..."
# Run migration for the main database
if [ -f ./priv/repo/squshed_migration.sql ]; then
  echo "Using squashed migration file..."
  run_psql -d "$MAIN_DB" -f ./priv/repo/squshed_migration.sql
else
  echo "No squashed migration file found, running Ecto migrations..."
  cd $(dirname $0) && mix ecto.migrate
fi

# Initialize event store schema in the test database
echo "Creating event store schema in event store database..."
run_psql -d "$EVENT_DB" -c "CREATE SCHEMA IF NOT EXISTS event_store;"

# Create EventStore tables
echo "Creating event store tables..."
cat <<EOT | run_psql -d "$EVENT_DB"
CREATE SCHEMA IF NOT EXISTS event_store;

CREATE TABLE IF NOT EXISTS event_store.streams (
  id text PRIMARY KEY,
  version bigint NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS event_store.events (
  event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stream_id text NOT NULL REFERENCES event_store.streams(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  event_data jsonb NOT NULL,
  event_metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  event_version bigint NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE (stream_id, event_version)
);

CREATE TABLE IF NOT EXISTS event_store.subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stream_id text NOT NULL REFERENCES event_store.streams(id) ON DELETE CASCADE,
  subscriber_pid text NOT NULL,
  options jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);
EOT

# Explicitly trigger garbage collection
echo "Cleaning up and clearing memory..."
if command -v sync > /dev/null; then
  sync
fi

# Final verification of no remaining connections
check_connections "$MAIN_DB"
check_connections "$EVENT_DB"

echo "Test database reset complete!" 