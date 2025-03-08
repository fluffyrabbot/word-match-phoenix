#!/bin/bash

echo "Resetting test databases for game_bot..."

# Database parameters
PG_USER="postgres"
PG_PASSWORD="csstarahid"
PG_HOST="localhost"

# Use PGPASSWORD environment variable to avoid password prompt
export PGPASSWORD=$PG_PASSWORD

# Stop any running processes that might be connected to the databases
echo "Stopping any connected processes..."
pkill -f "postgres.*game_bot_test" || true
pkill -f "postgres.*game_bot_eventstore_test" || true

# Drop and recreate the main test database
echo "Dropping and recreating main test database..."
psql -U $PG_USER -h $PG_HOST -d postgres -c "DROP DATABASE IF EXISTS game_bot_test;"
psql -U $PG_USER -h $PG_HOST -d postgres -c "CREATE DATABASE game_bot_test ENCODING 'UTF8';"

# Drop and recreate the event store test database
echo "Dropping and recreating event store test database..."
psql -U $PG_USER -h $PG_HOST -d postgres -c "DROP DATABASE IF EXISTS game_bot_eventstore_test;"
psql -U $PG_USER -h $PG_HOST -d postgres -c "CREATE DATABASE game_bot_eventstore_test ENCODING 'UTF8';"

# Set environment variable to ensure we use the test environment
export MIX_ENV=test

echo "Running squashed migration..."
# Run just the squashed migration file
psql -U $PG_USER -h $PG_HOST -d game_bot_test -f ./priv/repo/squshed_migration.sql

# Initialize event store schema in the test database
echo "Creating event store schema in event store database..."
psql -U $PG_USER -h $PG_HOST -d game_bot_eventstore_test -c "CREATE SCHEMA IF NOT EXISTS event_store;"

# Create EventStore tables
echo "Creating event store tables..."
cat <<EOT | psql -U $PG_USER -h $PG_HOST -d game_bot_eventstore_test
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

echo "Running migrations for the main database..."
MIX_ENV=test mix ecto.migrate

echo "Test database reset complete!" 