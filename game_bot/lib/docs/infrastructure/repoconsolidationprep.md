# Repository Consolidation Preparation

## Current Repository Structure

Based on codebase analysis, the current repository structure includes:

### 1. Repository Implementations

| Module | Type | Purpose |
|--------|------|---------|
| `GameBot.Infrastructure.Repository` | Interface | Delegates to configured implementation |
| `GameBot.Infrastructure.Persistence.Repo` | Base Repository | General database operations with EventStore types |
| `GameBot.Infrastructure.Persistence.Repo.Postgres` | Concrete Implementation | PostgreSQL-specific implementation with retry logic |
| `GameBot.Infrastructure.Persistence.EventStore` | Event Store | Event sourcing operations |
| `GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres` | Event Store Adapter | PostgreSQL implementation for event store |
| `GameBot.Infrastructure.Persistence.Repo.MockRepo` | Mock | Test double for repository |

### 2. Repository Registration

The repositories are registered in multiple places:

```elixir
# lib/game_bot/infrastructure/persistence/repository_manager.ex
@repositories [
  GameBot.Infrastructure.Persistence.Repo,
  GameBot.Infrastructure.Persistence.Repo.Postgres,
  GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
]

# config/config.exs
config :game_bot, ecto_repos: [
  GameBot.Infrastructure.Persistence.Repo,
  GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
]

config :game_bot, event_stores: [
  GameBot.Infrastructure.Persistence.EventStore
]
```

## Current Data Usage

### Event Store Data (Event-Sourced)

The event store currently handles:

1. **Game Lifecycle Events**
   - `GameCreated`: Initial game creation
   - `GameStarted`: Game start with teams and configuration
   - `GameCompleted`: Game completion with final results

2. **Round Events**
   - `RoundStarted`: Round beginning
   - `RoundCompleted`: Round completion with results

3. **Guess Events**
   - `GuessProcessed`: Core atomic game action
   - `GuessAbandoned`: Failed guess attempts

4. **Team/Player Events**
   - Team registration/changes
   - Player role assignments

### Domain Repository Data (Read Models)

The domain repository currently handles:

1. **Schemas**
   - `Guess`: Records of guess events for replay
   - Game statistics and metadata
   - User information
   - Team information

## Repository Usage Patterns

1. **Repository Interface**

```elixir
# Repository interface delegates to implementation
defmodule GameBot.Infrastructure.Repository do
  defp impl do
    Application.get_env(:game_bot, :repository_implementation) ||
      Application.get_env(:game_bot, :repo_implementation,
        GameBot.Infrastructure.Persistence.Repo.Postgres)
  end
  
  def transaction(fun, opts \\ []), do: impl().transaction(fun, opts)
  def insert(struct, opts \\ []), do: impl().insert(struct, opts)
  # ... other operations
end
```

2. **EventStore Adapter**

```elixir
# Event store adapter provides facade for event store operations
defmodule GameBot.Infrastructure.Persistence.EventStore.Adapter do
  def append_to_stream(stream_id, expected_version, events, opts \\ []) do
    with {:ok, adapter} <- get_adapter() do
      adapter.append_to_stream(stream_id, expected_version, events, opts)
    end
  end
  
  def read_stream_forward(stream_id, start_version \\ 0, count \\ 1000, opts \\ []) do
    with {:ok, adapter} <- get_adapter() do
      adapter.read_stream_forward(stream_id, start_version, count, opts)
    end
  end
  # ... other operations
end
```

3. **Domain Usage**

```elixir
# Replay functionality using event store
defmodule GameBot.Domain.Commands.ReplayCommands.FetchGameReplay do
  def execute(%__MODULE__{} = command) do
    opts = [guild_id: command.guild_id]
    fetch_game_events(command.game_id, opts)
  end

  defp fetch_game_events(game_id, opts) do
    # Use the adapter's safe functions instead of direct EventStore access
    EventStore.read_stream_forward(game_id, 0, 1000, opts)
  end
end
```

## Custom Implementations

The `GameBot.Infrastructure.Persistence.Repo.Postgres` module contains several custom implementations that need to be preserved:

1. **Retry Logic**
   - `with_retry/3`: Retries operations on recoverable errors
   - Error detection and classification

2. **Error Handling**
   - Custom domain-friendly error wrapper
   - Consistent error patterns

3. **Domain-Friendly Operations**
   - `fetch/3`: Get with better error handling
   - `insert_record/2`: Insert with validation
   - `update_record/2`: Update with concurrency control
   - `delete_record/2`: Delete with validation
   - `execute_transaction/2`: Transaction with proper error handling

## Test Support

The codebase includes test support for both repositories:

1. **Mock Repository**
   - `GameBot.Infrastructure.Persistence.Repo.MockRepo`
   - Used for unit testing

2. **Repository Test Case**
   - `GameBot.RepositoryCase`
   - Supports both real and mock repositories

3. **Database Helper**
   - `GameBot.Test.DatabaseHelper`
   - Manages repository connections for tests

## Consolidation Requirements

Based on the analysis, the following changes are required:

1. **Create New Repository Modules**
   - `GameBot.Infrastructure.Repository`: Domain repository
   - `GameBot.Infrastructure.EventStore`: Event store repository

2. **Migrate Custom Implementations**
   - Move retry logic to appropriate repository
   - Preserve domain-friendly operations
   - Maintain consistent error handling

3. **Update Configuration**
   - Adjust configuration in config files
   - Update repository registration

4. **Update Test Support**
   - Update mock implementations
   - Adjust test helpers
   - Update test cases

5. **Update Repository References**
   - Find and update all references to old repositories
   - Ensure correct repository is used for different data types

## Next Steps

1. **Create the consolidated repository modules**
2. **Update configuration files**
3. **Migrate custom implementations**
4. **Update test support**
5. **Update repository references**
6. **Test the changes** 