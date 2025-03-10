#!/bin/bash

# update_deps.sh - Script to update dependencies for GameBot project
# Usage: ./update_deps.sh [--force]

# Enable error handling
set -e

echo "GameBot Dependency Updater"
echo "=========================="

# Check for force flag
FORCE_FLAG=""
if [ "$1" == "--force" ]; then
    FORCE_FLAG="--force"
    echo "Running in force mode - will attempt to update beyond current constraints"
fi

# Step 1: Get current dependencies
echo -e "\n[1/4] Fetching current dependencies..."
mix deps.get $FORCE_FLAG

# Step 2: Show outdated dependencies
echo -e "\n[2/4] Checking for outdated dependencies..."
mix hex.outdated

# Step 3: Update dependencies
echo -e "\n[3/4] Updating dependencies..."
mix deps.update --all

# Step 4: Compile to verify everything works
echo -e "\n[4/4] Compiling project to verify dependencies..."
mix compile

echo -e "\nDependency update completed."
echo "If you need to update beyond current version constraints,"
echo "edit the version specifications in mix.exs and run this script again." 