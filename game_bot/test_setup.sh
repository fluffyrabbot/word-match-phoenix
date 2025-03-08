#!/bin/bash

set -e

echo "Setting up test environment for game_bot..."

# Set environment variable to ensure we use the test environment
export MIX_ENV=test

# Database parameters
PG_USER="postgres"
PG_PASSWORD="csstarahid"
PG_HOST="localhost"

# Use PGPASSWORD environment variable to avoid password prompt
export PGPASSWORD=$PG_PASSWORD

# Drop and recreate databases
echo "Dropping and recreating test databases..."
psql -U $PG_USER -h $PG_HOST -d postgres -c "DROP DATABASE IF EXISTS game_bot_test;" || true
psql -U $PG_USER -h $PG_HOST -d postgres -c "DROP DATABASE IF EXISTS game_bot_eventstore_test;" || true
psql -U $PG_USER -h $PG_HOST -d postgres -c "CREATE DATABASE game_bot_test ENCODING 'UTF8';" || true
psql -U $PG_USER -h $PG_HOST -d postgres -c "CREATE DATABASE game_bot_eventstore_test ENCODING 'UTF8';" || true

# Clean build artifacts to ensure no leftover modules cause issues
echo "Cleaning build artifacts..."
mix clean

# Get dependencies
echo "Getting dependencies..."
mix deps.get

# Compile the project
echo "Compiling project..."
mix compile

# Create event store schema directly to ensure it exists
echo "Creating event store schema..."
psql -U $PG_USER -h $PG_HOST -d game_bot_eventstore_test -c "CREATE SCHEMA IF NOT EXISTS event_store;"

# Run the migrations
echo "Running migrations..."
mix ecto.migrate || true

# Run event store setup
echo "Setting up event store..."
MIX_ENV=test mix game_bot.event_store_setup || true

echo "Setup complete! Ready to run tests." 