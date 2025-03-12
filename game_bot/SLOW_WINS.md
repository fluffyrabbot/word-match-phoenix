# Complex Issues Analysis

## Overview
The test output reveals several deeper, more complex issues that will require more substantial fixes. These include:

1. Database connection and configuration issues
2. Event store initialization problems
3. Event serialization and migration infrastructure
4. Missing implementations for protocol behaviors
5. Test environment setup and teardown issues

## Complex Issue 1: Database and Event Store Initialization

### Problem Description
Many test failures show the Ecto repositories and event store are not properly initialized:

```
** (RuntimeError) could not lookup Ecto repo GameBot.Infrastructure.Persistence.Repo because it was not started or it does not exist
** (RuntimeError) could not lookup GameBot.Infrastructure.Persistence.EventStore because it was not started or it does not exist
```

The test output also shows warning messages like:
```
Event store is not running, cannot reset
```

This suggests the database setup and teardown process isn't working correctly, particularly in the test environment.

### Root Causes
1. Improper database initialization order in test setup
2. Missing supervisor configuration for repositories
3. Potential race conditions in setup/teardown process
4. Mixed async and sync tests using the same database resources

### Solution Approaches

#### Approach 1: Comprehensive Test Environment Configuration

```elixir
# Create a dedicated test helper module (test/support/database_helper.ex)
defmodule GameBot.Test.DatabaseHelper do
  @moduledoc """
  Handles database setup and teardown for tests.
  """
  
  alias GameBot.Infrastructure.Persistence.Repo
  alias GameBot.Infrastructure.Persistence.EventStore
  
  @doc """
  Sets up all database connections for a test.
  """
  def setup_databases do
    # Generate unique database names for this test run
    db_suffix = System.monotonic_time()
    main_db = "game_bot_test_#{db_suffix}"
    event_db = "game_bot_eventstore_test_#{db_suffix}"
    
    # Configure repositories with the test databases
    configure_main_db(main_db)
    configure_event_db(event_db)
    
    # Start repositories
    {:ok, _} = Repo.start_link()
    {:ok, _} = EventStore.start_link()
    
    # Create schemas and tables
    setup_schemas()
    
    # Return configuration for cleanup
    %{main_db: main_db, event_db: event_db}
  end
  
  @doc """
  Cleans up database resources after tests.
  """
  def cleanup_databases(%{main_db: main_db, event_db: event_db}) do
    # Stop repositories
    if Process.whereis(Repo), do: Repo.stop()
    if Process.whereis(EventStore), do: EventStore.stop()
    
    # Drop databases
    {:ok, _} = Postgrex.start_link(database: "postgres") |> elem(1) |> Postgrex.query("DROP DATABASE IF EXISTS #{main_db}", [])
    {:ok, _} = Postgrex.start_link(database: "postgres") |> elem(1) |> Postgrex.query("DROP DATABASE IF EXISTS #{event_db}", [])
    
    :ok
  end
  
  # Private helper functions
  defp configure_main_db(db_name) do
    # Implementation details
  end
  
  defp configure_event_db(db_name) do
    # Implementation details
  end
  
  defp setup_schemas do
    # Implementation details
  end
end
```

#### Approach 2: Refactored Test Case with Improved Setup/Teardown

```elixir
defmodule GameBot.DatabaseCase do
  @moduledoc """
  This module defines the setup for tests requiring
  database access.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias GameBot.Infrastructure.Persistence.Repo
      alias GameBot.Infrastructure.Persistence.EventStore
      
      import Ecto
      import Ecto.Query
      import GameBot.DatabaseCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(GameBot.Infrastructure.Persistence.Repo, 
      shared: not tags[:async])

    # Set up event store for this test
    {:ok, _} = start_supervised(GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres)
    
    # Ensure EventStore is properly initialized
    wait_for_event_store()
    
    on_exit(fn ->
      # Controlled shutdown of resources
      Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
      
      # Clean event streams if needed
      clean_event_streams()
    end)
    
    :ok
  end
  
  defp wait_for_event_store do
    # Poll until EventStore is available or timeout
    # Implementation details
  end
  
  defp clean_event_streams do
    # Implementation details to clean event streams between tests
  end
end
```

## Complex Issue 2: Event Serialization Infrastructure

### Problem Description
There are several complex failures around the event serialization system:

1. Missing JsonSerializer module
2. Undefined protocol implementations
3. Event migration failures
4. Module resolution errors

These suggest problems with the overall event serialization architecture.

### Root Causes
1. Incomplete implementation of serialization protocols
2. Missing versioning and migration infrastructure
3. Inconsistencies between event definitions and serializers

### Solution Approaches

#### Approach 1: Comprehensive Event Serialization Framework

Create a more robust event serialization framework with clear protocol definitions, version handling, and migration support:

```elixir
# Define a strong serialization protocol
defprotocol GameBot.Domain.Events.Serialization do
  @spec serialize(t) :: {:ok, map} | {:error, term}
  def serialize(event)
  
  @spec deserialize(map, module) :: {:ok, struct} | {:error, term}
  def deserialize(data, event_module)
  
  @spec validate(map, module) :: :ok | {:error, term}
  def validate(data, event_module)
  
  @spec version(t) :: non_neg_integer
  def version(event)
end

# Implement a registry for event types and versions
defmodule GameBot.Domain.Events.Registry do
  @moduledoc """
  Maintains a registry of event types, versions, and migration paths.
  """
  
  # Use ETS for high performance lookups
  @table_name :event_registry
  
  @doc """
  Initializes the event registry.
  """
  def init do
    :ets.new(@table_name, [:named_table, :set, :public])
    
    # Register all known event types
    register_all_events()
    
    # Build migration graph
    build_migration_graph()
    
    :ok
  end
  
  @doc """
  Registers an event type with the registry.
  """
  def register_event(type, module, version) do
    :ets.insert(@table_name, {{:event, type}, {module, version}})
  end
  
  @doc """
  Registers a migration path between versions.
  """
  def register_migration(type, from_version, to_version, migration_fun) do
    :ets.insert(@table_name, {{:migration, type, from_version, to_version}, migration_fun})
  end
  
  @doc """
  Finds a migration path from one version to another.
  """
  def find_migration_path(type, from_version, to_version) do
    # Use the graph to find shortest path
    # Implementation details
  end
  
  # Private helpers
  defp register_all_events do
    # Implementation details
  end
  
  defp build_migration_graph do
    # Implementation details
  end
end
```

#### Approach 2: Simplified JSON Serialization Implementation

Create a concrete JSON serializer implementation that handles the common serialization needs:

```elixir
defmodule GameBot.Infrastructure.Persistence.EventStore.JsonSerializer do
  @moduledoc """
  Serializes events to/from JSON format.
  """
  
  alias GameBot.Infrastructure.Persistence.EventStore.Error
  alias GameBot.Domain.Events.Registry
  
  @doc """
  Serializes an event to a JSON-compatible map.
  """
  @spec serialize(struct()) :: {:ok, map()} | {:error, Error.t()}
  def serialize(event) when is_struct(event) do
    with :ok <- validate_event(event),
         type = event_type(event),
         version = event_version(event),
         {:ok, data} = extract_data(event) do
      {:ok, %{
        "type" => type,
        "version" => version,
        "data" => data,
        "metadata" => Map.get(event, :metadata, %{})
      }}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Deserializes JSON data to an event struct.
  """
  @spec deserialize(map(), module()) :: {:ok, struct()} | {:error, Error.t()}
  def deserialize(data, event_module) when is_map(data) and is_atom(event_module) do
    with {:ok, validated_data} <- validate_data(data),
         {:ok, event} <- create_event(validated_data, event_module) do
      {:ok, event}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  # Private helper functions
  defp validate_event(event) do
    # Implementation details
  end
  
  defp event_type(event) do
    # Implementation details
  end
  
  defp event_version(event) do
    # Implementation details
  end
  
  defp extract_data(event) do
    # Implementation details
  end
  
  defp validate_data(data) do
    # Implementation details
  end
  
  defp create_event(data, module) do
    # Implementation details
  end
end
```

## Complex Issue 3: Test Mocking Strategy

### Problem Description
There are failures with mocking, particularly around the EventStoreAccess module:

```
** (ErlangError) Erlang error: {:not_mocked, GameBot.Replay.EventStoreAccess}
```

And there are potential issues with proper teardown of mocks between tests.

### Root Causes
1. Improper mock setup and teardown
2. Use of mocking libraries without proper initialization
3. Conflict between mocked modules in different tests

### Solution Approaches

#### Approach 1: Comprehensive Mocking Framework

```elixir
defmodule GameBot.Test.MockHelper do
  @moduledoc """
  Provides helpers for setting up and tearing down mocks in tests.
  """
  
  @doc """
  Sets up mocks for common dependencies.
  """
  def setup_mocks(opts \\ []) do
    # Set up EventStoreAccess mock
    if Keyword.get(opts, :event_store_access, true) do
      :ok = ensure_mock(GameBot.Replay.EventStoreAccess)
      :meck.expect(GameBot.Replay.EventStoreAccess, :fetch_events, fn id ->
        {:ok, mock_events_for(id)}
      end)
    end
    
    # Set up additional mocks as needed
    if Keyword.get(opts, :storage, false) do
      :ok = ensure_mock(GameBot.Replay.Storage)
      :meck.expect(GameBot.Replay.Storage, :get_replay, fn id, _ ->
        {:ok, mock_replay_for(id)}
      end)
    end
    
    :ok
  end
  
  @doc """
  Tears down all mocks.
  """
  def teardown_mocks do
    :meck.unload()
  end
  
  # Private helpers
  defp ensure_mock(module) do
    if :meck.validate(module) do
      :meck.unload(module)
    end
    :meck.new(module, [:passthrough])
  end
  
  defp mock_events_for(id) do
    # Return appropriate mock events based on ID
    # Implementation details
  end
  
  defp mock_replay_for(id) do
    # Return appropriate mock replay based on ID
    # Implementation details
  end
end
```

#### Approach 2: Use of Behaviors and Test Implementations

Instead of mocking, create test implementations of behaviors:

```elixir
# Define behavior
defmodule GameBot.Replay.EventStoreAccess.Behavior do
  @callback fetch_events(String.t()) :: {:ok, list()} | {:error, term()}
end

# Real implementation
defmodule GameBot.Replay.EventStoreAccess do
  @behaviour GameBot.Replay.EventStoreAccess.Behavior
  
  def fetch_events(id) do
    # Real implementation
  end
end

# Test implementation
defmodule GameBot.Test.StubEventStoreAccess do
  @behaviour GameBot.Replay.EventStoreAccess.Behavior
  
  def fetch_events(id) do
    {:ok, [
      # Test events
    ]}
  end
end

# In application.ex, use configuration to select implementation
defmodule GameBot.Application do
  def start(_type, _args) do
    event_store_access = Application.get_env(:game_bot, :event_store_access, GameBot.Replay.EventStoreAccess)
    
    children = [
      # Other children
      {event_store_access, []}
    ]
    
    # Supervisor options
  end
end

# In config/test.exs, override the implementation
config :game_bot, :event_store_access, GameBot.Test.StubEventStoreAccess
```

## Complex Issue 4: Inconsistent Return Values

### Problem Description
There are inconsistencies in return value patterns across the application:

1. Some functions double-wrap results: `{:ok, {:error, changeset}}`
2. Others use different return patterns: `{:ok, []}` vs. just `[]`
3. Missing or incorrect match patterns in tests

### Root Causes
1. Inconsistent function design across modules
2. Mixing of different error handling approaches
3. Lack of standardized result handling

### Solution Approaches

#### Approach 1: Define and Implement Standard Result Types

Create clear result types and consistent handling patterns:

```elixir
defmodule GameBot.Core.Result do
  @moduledoc """
  Standardized result types for the application.
  """
  
  @type ok(value) :: {:ok, value}
  @type error(reason) :: {:error, reason}
  @type result(value, reason) :: ok(value) | error(reason)
  
  @doc """
  Maps a successful result through a function.
  """
  @spec map(result(a, e), (a -> b)) :: result(b, e) when a: var, b: var, e: var
  def map({:ok, value}, fun), do: {:ok, fun.(value)}
  def map({:error, _} = error, _), do: error
  
  @doc """
  Chains operations that may fail.
  """
  @spec bind(result(a, e), (a -> result(b, e))) :: result(b, e) when a: var, b: var, e: var
  def bind({:ok, value}, fun), do: fun.(value)
  def bind({:error, _} = error, _), do: error
  
  @doc """
  Unwraps a result or returns a default.
  """
  @spec unwrap_or(result(a, e), a) :: a when a: var, e: var
  def unwrap_or({:ok, value}, _), do: value
  def unwrap_or({:error, _}, default), do: default
end
```

#### Approach 2: Standardize Repository Return Values

Create helpers and adapters to standardize repository interactions:

```elixir
defmodule GameBot.Infrastructure.Persistence.RepoAdapter do
  @moduledoc """
  Standardizes repository interactions across the application.
  """
  
  alias GameBot.Infrastructure.Persistence.Repo
  
  @doc """
  Executes a query and standardizes the result.
  """
  @spec query(Ecto.Query.t()) :: {:ok, list()} | {:error, term()}
  def query(query) do
    case Repo.all(query) do
      results when is_list(results) -> {:ok, results}
      error -> {:error, error}
    end
  end
  
  @doc """
  Inserts a record with standardized error handling.
  """
  @spec insert(Ecto.Schema.t()) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def insert(schema) do
    case Repo.insert(schema) do
      {:ok, result} -> {:ok, result}
      {:error, changeset} -> {:error, standardize_changeset_errors(changeset)}
    end
  end
  
  # Private helpers
  defp standardize_changeset_errors(changeset) do
    # Implementation details
  end
end
```

## Implementation Recommendations

To tackle these complex issues effectively:

1. **Start with Database/EventStore Infrastructure**: This affects most tests, so fixing this first will have the biggest impact.

2. **Define clear boundaries between modules**: Ensure each module has clear responsibilities and interfaces.

3. **Standardize error handling and return types**: Create consistent patterns for success/failure results.

4. **Improve test isolation**: Ensure tests properly clean up after themselves and don't interfere with each other.

5. **Consider a test factory approach**: Instead of setting up test data in each test, use a factory pattern to create consistent test data.

These more complex fixes will require deeper changes to the application architecture but will provide a more maintainable and robust system in the long run. 