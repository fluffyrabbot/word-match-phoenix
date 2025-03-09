# Repository Interface Implementation

## Overview

This document explains the implementation of a Repository interface layer that resolves test failures related to repository initialization and mocking issues.

## Problem

The test suite was failing with the following issues:

1. **Repository Initialization Issues**: Many tests failed with "could not lookup Ecto repo" errors
2. **Mock Repository Implementation Gaps**: Tests using mocks failed with "unknown function" errors
3. **Transaction Management Issues**: Tests with transactions failed due to missing mock expectations
4. **Connection Management Issues**: Database connections weren't being properly handled in tests

## Solution

Instead of attempting to redefine functions already created by the `use Ecto.Repo` macro (which causes compilation conflicts), we implemented a delegation-based Repository interface following the adapter pattern already used in the EventStore module.

### Key Components

1. **Repository Interface**: A central module that delegates to the configured implementation
2. **Mock Repository**: An implementation that follows the Repository.Behaviour interface for testing
3. **Test Environment Setup**: Proper configuration of the repository implementation in tests

## Repository Interface Layer

```elixir
defmodule GameBot.Infrastructure.Repository do
  # Delegate to the configured implementation
  def implementation do
    Application.get_env(:game_bot, :repository_implementation, 
      GameBot.Infrastructure.Persistence.Repo.Postgres)
  end
  
  # Delegate all repository functions
  defdelegate transaction(fun, opts \\ []), to: implementation()
  defdelegate insert(struct, opts \\ []), to: implementation()
  defdelegate update(changeset, opts \\ []), to: implementation()
  defdelegate delete(struct, opts \\ []), to: implementation()
  defdelegate rollback(value), to: implementation()
  defdelegate one(queryable, opts \\ []), to: implementation()
  defdelegate all(queryable, opts \\ []), to: implementation()
  defdelegate get(queryable, id, opts \\ []), to: implementation()
  defdelegate delete_all(queryable, opts \\ []), to: implementation()
end
```

## Mock Repository

```elixir
defmodule GameBot.Infrastructure.Persistence.Repo.MockRepo do
  @behaviour GameBot.Infrastructure.Persistence.Repo.Behaviour
  
  # Default implementation of behavior functions
  @impl true
  def transaction(fun, _opts \\ []) do
    try do
      result = fun.()
      {:ok, result}
    rescue
      e -> {:error, e}
    catch
      :throw, {:ecto_rollback, value} -> {:error, value}
    end
  end
  
  # Other implementations...
end
```

## Test Environment Setup

```elixir
# Configure the mock repository in test setup
Application.put_env(:game_bot, :repository_implementation, 
  GameBot.Infrastructure.Persistence.Repo.MockRepo)

# Set up Mox to verify expectations
Mox.set_mox_global(GameBot.Infrastructure.Persistence.Repo.MockRepo)
Mox.verify_on_exit!()
```

## Usage Example

Before:
```elixir
alias GameBot.Infrastructure.Persistence.Repo

def store_entity(entity) do
  case Repo.insert(entity) do
    {:ok, stored} -> {:ok, stored}
    {:error, changeset} -> {:error, changeset}
  end
end
```

After:
```elixir
alias GameBot.Infrastructure.Repository

def store_entity(entity) do
  case Repository.insert(entity) do
    {:ok, stored} -> {:ok, stored}
    {:error, changeset} -> {:error, changeset}
  end
end
```

## Advantages

1. **No Macro Conflicts**: Avoids conflicts with functions defined by macros
2. **Clean Separation**: Production code has no test-specific logic
3. **Consistent Interface**: Domain code uses the same interface in production and tests
4. **Testability**: Mock adapter provides explicit control over test behavior
5. **Simplicity**: Each module has a single responsibility

## Migration Strategy

1. Create the Repository interface and Mock implementation
2. Update the test environment setup
3. Gradually migrate domain services to use the Repository interface
4. Update test expectations to use the mock interface

This approach respects the existing architecture while solving the specific issues with tests, creating a cleaner, more maintainable codebase. 