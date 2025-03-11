#!/bin/bash

echo "Setting up test database environment..."

# Define color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Set environment to test mode
export MIX_ENV=test

# Database credentials
DB_USER="postgres"
DB_PASSWORD="csstarahid"
DB_HOST="localhost"

# Get current timestamp for unique database names
TIMESTAMP=$(date +%s)
MAIN_DB="game_bot_test_${TIMESTAMP}"
EVENT_DB="game_bot_eventstore_test_${TIMESTAMP}"

echo -e "${BLUE}Creating test databases: ${MAIN_DB} and ${EVENT_DB}${NC}"

# Create the databases
PGPASSWORD=${DB_PASSWORD} psql -h ${DB_HOST} -U ${DB_USER} -d postgres -c "DROP DATABASE IF EXISTS ${MAIN_DB};" || exit 1
PGPASSWORD=${DB_PASSWORD} psql -h ${DB_HOST} -U ${DB_USER} -d postgres -c "DROP DATABASE IF EXISTS ${EVENT_DB};" || exit 1
PGPASSWORD=${DB_PASSWORD} psql -h ${DB_HOST} -U ${DB_USER} -d postgres -c "CREATE DATABASE ${MAIN_DB};" || exit 1
PGPASSWORD=${DB_PASSWORD} psql -h ${DB_HOST} -U ${DB_USER} -d postgres -c "CREATE DATABASE ${EVENT_DB};" || exit 1

echo -e "${GREEN}Databases created successfully${NC}"

# Update the config/test.exs file with the new database names
echo -e "${BLUE}Updating test configuration with new database names${NC}"

# Search and replace the database names in the test.exs file
if [ -f "config/test.exs" ]; then
  # Back up the original file
  cp config/test.exs config/test.exs.bak
  
  # Update the main database name
  sed -i "s/main_db_name = .*/main_db_name = \"$MAIN_DB\"/" config/test.exs
  
  # Update the event store database name
  sed -i "s/event_db_name = .*/event_db_name = \"$EVENT_DB\"/" config/test.exs
  
  echo -e "${GREEN}Test configuration updated successfully${NC}"
else
  echo -e "${RED}Error: config/test.exs file not found${NC}"
  exit 1
fi

echo -e "${BLUE}Running migrations for main database${NC}"

# Run the migrations for the main database
PGPASSWORD=${DB_PASSWORD} psql -h ${DB_HOST} -U ${DB_USER} -d ${MAIN_DB} -f priv/repo/squshed_migration.sql || exit 1

echo -e "${BLUE}Initializing event store schema${NC}"

# Create event store schema
PGPASSWORD=${DB_PASSWORD} psql -h ${DB_HOST} -U ${DB_USER} -d ${EVENT_DB} -c "CREATE SCHEMA IF NOT EXISTS event_store;" || exit 1

# Create event store tables - basic structure
PGPASSWORD=${DB_PASSWORD} psql -h ${DB_HOST} -U ${DB_USER} -d ${EVENT_DB} -c "
CREATE TABLE IF NOT EXISTS event_store.streams (
  id text NOT NULL,
  version bigint NOT NULL,
  PRIMARY KEY (id)
);" || exit 1

PGPASSWORD=${DB_PASSWORD} psql -h ${DB_HOST} -U ${DB_USER} -d ${EVENT_DB} -c "
CREATE TABLE IF NOT EXISTS event_store.events (
  event_id uuid NOT NULL,
  stream_id text NOT NULL,
  event_type text NOT NULL,
  event_version integer NOT NULL,
  event_data jsonb NOT NULL,
  event_metadata jsonb NOT NULL,
  created_at timestamp without time zone DEFAULT now() NOT NULL,
  PRIMARY KEY (event_id),
  FOREIGN KEY (stream_id) REFERENCES event_store.streams(id) ON DELETE CASCADE
);" || exit 1

PGPASSWORD=${DB_PASSWORD} psql -h ${DB_HOST} -U ${DB_USER} -d ${EVENT_DB} -c "
CREATE TABLE IF NOT EXISTS event_store.subscriptions (
  id SERIAL,
  stream_id text NOT NULL,
  subscriber_pid text NOT NULL,
  options jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp without time zone DEFAULT now() NOT NULL,
  PRIMARY KEY (id),
  UNIQUE (stream_id, subscriber_pid)
);" || exit 1

echo -e "${GREEN}Event store schema initialized successfully${NC}"
echo -e "${GREEN}Test database setup complete!${NC}"

echo "Now run tests with: ./run_tests.sh" 