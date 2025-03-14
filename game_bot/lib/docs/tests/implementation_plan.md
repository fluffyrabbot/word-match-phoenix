# Test Failures - Implementation Plan

This document outlines the step-by-step approach to fix the test failures related to repository initialization and the missing test_schema table.

## Overview of Changes

1. **Repository Verification Module**: Add robust verification of repository startup
2. **test_helper.exs Modifications**: Consolidate repository management in one place
3. **EventStoreCase Updates**: Remove duplicate repository startup logic
4. **Test Schema Creation**: Ensure test_schema table exists

## Implementation Steps

### Step 1: Create Repository Verification Module

Create a new module in `lib/docs/tests/repo_verification.ex` that provides robust repository verification:

```bash
# Use Git Bash to create the directories if they don't exist
mkdir -p lib/docs/tests
```

This module includes functions to:
- Verify repository processes are running
- Test actual database connectivity
- Create missing test schema tables
- Provide clear error messages

### Step 2: Update test_helper.exs

Insert this code in test_helper.exs after repository startup but before running tests:

```elixir
# Import the verification module
Code.require_file("lib/docs/tests/repo_verification.ex")

# Define repositories we need for testing
repos = [
  GameBot.Infrastructure.Persistence.Repo,
  GameBot.Infrastructure.Persistence.Repo.Postgres,
  GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
]

# Verify that all repositories are properly started and functional
GameBot.Test.RepoVerification.verify_all_repositories(repos)

# Ensure test_schema table exists in each repository
Enum.each(repos, fn repo ->
  # Only try to create test_schema for main repositories (not event store)
  if Atom.to_string(repo) =~ "Repo" and not Atom.to_string(repo) =~ "EventStore" do
    GameBot.Test.RepoVerification.ensure_test_schema_exists(repo)
  end
end)
```

### Step 3: Update EventStoreCase

Modify `GameBot.EventStoreCase` to remove duplicate repository startup logic:

1. Replace `setup_all` to only verify event store schema exists
2. Replace `ensure_event_store_schema_exists` to check repository is running
3. Replace `start_all_repos` to verify instead of starting repositories

### Step 4: Test One Failure at a Time

Run individual failing tests to verify changes:

```bash
# Test just the adapter tests first
mix test test/game_bot/infrastructure/persistence/event_store/adapter_test.exs

# Then test integration tests
mix test test/game_bot/infrastructure/persistence/event_store/integration_test.exs
```

### Step 5: Verify All Tests

After fixing individual failures, run the full test suite:

```bash
mix test
```

## Migration Creation

The test_schema migration has already been created at:
`priv/repo/migrations/99999999999999_create_test_schema.exs`

This creates the table that tests are expecting:

```sql
CREATE TABLE IF NOT EXISTS test_schema (
  id SERIAL PRIMARY KEY,
  name VARCHAR,
  value VARCHAR,
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
)
```

## Additional Considerations

1. **Configuration Updates**: The changes maintain existing timeout settings in test.exs
2. **Cleanup Logic**: Explicit transaction rollbacks are added to prevent lingering connections
3. **Error Reporting**: Clear error messages help diagnose any remaining issues
4. **Fail-Fast Approach**: Tests will fail immediately if repositories aren't properly initialized

## Expected Outcomes

After implementing these changes:

1. The "could not lookup Ecto repo" errors should be resolved
2. The "relation 'test_schema' does not exist" errors should be fixed
3. The test suite should run reliably without connection timeouts
4. Repository management will be consolidated in one place

## Verification Steps

After applying changes, verify:

1. All repositories start properly and are verified
2. The test_schema table is created as needed
3. The event_store schema and tables are properly created
4. Tests run without repository errors 