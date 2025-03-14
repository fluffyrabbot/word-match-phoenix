#!/bin/bash
# Script to apply repository test fixes

set -e  # Exit on error

echo "=== Starting repository test fixes implementation ==="

# Ensure directories exist
mkdir -p lib/docs/tests

# Copy the repository verification module
echo "1. Installing repository verification module..."
cp lib/docs/tests/repo_verification.ex lib/docs/tests/repo_verification.ex.bak 2>/dev/null || true

# Add the test_schema migration if it doesn't exist
if [ ! -f "priv/repo/migrations/99999999999999_create_test_schema.exs" ]; then
  echo "2. Creating test_schema migration..."
  cat > priv/repo/migrations/99999999999999_create_test_schema.exs << 'EOF'
defmodule GameBot.Repo.Migrations.CreateTestSchema do
  use Ecto.Migration

  def change do
    # Create a test schema table that test cases are looking for
    create table(:test_schema) do
      add :name, :string
      add :value, :string
      timestamps()
    end
  end
end
EOF
else
  echo "2. Test schema migration already exists."
fi

# Backup test_helper.exs before modifying
echo "3. Backing up test_helper.exs..."
cp test/test_helper.exs test/test_helper.exs.bak

# Show instructions for updating test_helper.exs
echo "4. Manual updates required:"
echo "   - Add repository verification code to test_helper.exs"
echo "   - Update EventStoreCase to remove duplicate repository startup"
echo ""
echo "=== Please make these changes manually by following the implementation plan ==="
echo "=== in lib/docs/tests/implementation_plan.md ==="
echo ""
echo "Run tests with:"
echo "mix test test/game_bot/infrastructure/persistence/event_store/adapter_test.exs"
echo ""
echo "To revert changes:"
echo "cp test/test_helper.exs.bak test/test_helper.exs"
echo "" 