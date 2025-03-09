#!/bin/bash

# Test script for testing the Repository interface implementation
echo "Testing Repository Interface implementation"

# Test the example test file that uses the Repository interface
echo "Running example repository test..."
mix test test/example_repository_test.exs

# Test a specific module that was updated to use the Repository interface
echo "Running Storage module tests..."
mix test test/game_bot/replay/storage_test.exs

# If everything is working correctly, run a more comprehensive set of tests
echo "Do you want to run a more comprehensive test suite? (y/n)"
read response

if [[ "$response" =~ ^[Yy]$ ]]; then
  echo "Running comprehensive test suite..."
  mix test --only mock
fi

echo "Done!" 