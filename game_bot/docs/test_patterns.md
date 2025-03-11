# Test Patterns with DatabaseManager

This guide provides examples of common test patterns using the new database management system.

## Basic Test Setup

### Synchronous Tests
For tests that don't need to run in parallel:

```elixir
defmodule MyTest do
  use ExUnit.Case

  setup tags do
    GameBot.Test.DatabaseManager.setup_sandbox(tags)
    :ok
  end

  test "my synchronous test" do
    # Test code here
  end
end
```

### Asynchronous Tests
For tests that can run in parallel:

```elixir
defmodule MyAsyncTest do
  use ExUnit.Case, async: true

  setup tags do
    GameBot.Test.DatabaseManager.setup_sandbox(tags)
    :ok
  end

  test "my async test" do
    # Test code here
  end
end
```

## Database Transactions

### Using Transactions in Tests
```elixir
defmodule MyTransactionTest do
  use ExUnit.Case
  alias Ecto.Adapters.SQL.Sandbox
  alias GameBot.Infrastructure.Persistence.Repo

  setup tags do
    GameBot.Test.DatabaseManager.setup_sandbox(tags)
    :ok
  end

  test "using transactions" do
    Repo.transaction(fn ->
      # Database operations here
      Repo.insert!(%MySchema{...})
      
      # Will be rolled back after test
    end)
  end
end
```

### Shared Mode for Multiple Processes
When your test needs to share the connection with other processes:

```elixir
defmodule MySharedTest do
  use ExUnit.Case

  setup tags do
    GameBot.Test.DatabaseManager.setup_sandbox(tags)
    
    # Allow other processes to access the connection
    Sandbox.mode(Repo, {:shared, self()})
    
    :ok
  end

  test "with shared connection" do
    parent = self()
    
    Task.start_link(fn ->
      # This process can use the same connection
      Repo.insert!(%MySchema{...})
      send(parent, :done)
    end)

    assert_receive :done
  end
end
```

## Event Store Tests

### Testing Event Persistence
```elixir
defmodule MyEventTest do
  use ExUnit.Case
  alias GameBot.Infrastructure.Persistence.EventStore

  setup tags do
    GameBot.Test.DatabaseManager.setup_sandbox(tags)
    :ok
  end

  test "persisting events" do
    event = %MyEvent{...}
    
    {:ok, _} = EventStore.append_to_stream("my-stream", :any_version, [event])
    {:ok, events} = EventStore.read_stream_forward("my-stream")
    
    assert length(events) == 1
  end
end
```

## Performance Considerations

### Optimizing Async Tests
```elixir
defmodule MyOptimizedTest do
  use ExUnit.Case, async: true

  # Get the maximum number of concurrent tests that can run
  @max_concurrent max(1, GameBot.Test.DatabaseConfig.max_concurrent_tests())
  
  setup tags do
    GameBot.Test.DatabaseManager.setup_sandbox(tags)
    :ok
  end

  for i <- 1..100 do
    # Tests will be distributed across available connections
    @tag timeout: :timer.seconds(30)
    test "concurrent test #{i}" do
      # Your test code here
    end
  end
end
```

### Long-Running Tests
For tests that take longer than usual:

```elixir
defmodule MyLongRunningTest do
  use ExUnit.Case

  setup tags do
    GameBot.Test.DatabaseManager.setup_sandbox(tags)
    :ok
  end

  @tag timeout: :timer.minutes(5)
  test "long running operation" do
    # Long-running test code here
  end
end
```

## Best Practices

1. **Always Use setup_sandbox**
   ```elixir
   setup tags do
     GameBot.Test.DatabaseManager.setup_sandbox(tags)
     :ok
   end
   ```

2. **Clean Up After Tests**
   ```elixir
   setup do
     on_exit(fn ->
       # Clean up any resources created outside the sandbox
     end)
   end
   ```

3. **Use Appropriate Pool Sizes**
   - For sync tests: Default pool is fine
   - For async tests: Pool size is automatically adjusted based on system capabilities

4. **Handle Database Errors**
   ```elixir
   test "handles database errors" do
     assert {:error, _} = Repo.transaction(fn ->
       Repo.query!("SELECT invalid_function()")
     end)
   end
   ```

5. **Use Tags Appropriately**
   ```elixir
   @tag :skip_db  # Skip database setup
   test "no database needed" do
     # Test code that doesn't need database
   end
   ```

## Troubleshooting

### Common Issues

1. **Connection Pool Exhausted**
   ```
   ** (DBConnection.ConnectionError) connection not available and request was dropped from queue after 123123ms
   ```
   Solution: Reduce the number of concurrent async tests or increase pool size in `DatabaseConfig`.

2. **Sandbox Mode Errors**
   ```
   ** (RuntimeError) cannot find ownership process for #PID<X.X.X>
   ```
   Solution: Ensure `setup_sandbox(tags)` is called in the setup block.

3. **Deadlocks**
   ```
   ** (DBConnection.ConnectionError) transaction rollback: deadlock detected
   ```
   Solution: Review transaction ordering or reduce concurrency.

### Debugging Tips

1. Enable SQL logging in config/test.exs:
   ```elixir
   config :game_bot, GameBot.Infrastructure.Persistence.Repo,
     show_sensitive_data_on_connection_error: true,
     log: true
   ```

2. Monitor connection usage:
   ```elixir
   IO.inspect(Repo.checkout_all(), label: "Active connections")
   ```

3. Check pool status:
   ```elixir
   :telemetry.attach("debug-pool",
     [:game_bot, :repo, :pool],
     fn event, measurements, metadata, _config ->
       IO.inspect({event, measurements, metadata}, label: "Pool event")
     end,
     nil)
   ```

## Error Handling Patterns

### Type Validation
```elixir
defmodule MyCommandTest do
  use ExUnit.Case
  alias GameBot.Domain.Commands.MyCommand

  setup tags do
    GameBot.Test.DatabaseManager.setup_sandbox(tags)
    :ok
  end

  test "validates command types" do
    # Ensure proper types are used
    command = %MyCommand{
      user_id: "123",  # String, not integer
      guild_id: "456", # String, not integer
      data: %{valid: true}
    }

    assert :ok = MyCommand.validate(command)
  end

  test "rejects invalid types" do
    command = %MyCommand{
      user_id: 123,    # Wrong type (integer instead of string)
      guild_id: "456",
      data: %{valid: true}
    }

    assert {:error, :invalid_type} = MyCommand.validate(command)
  end
end
```

### EventStore Implementation
```elixir
defmodule MyEventStoreTest do
  use ExUnit.Case
  alias GameBot.Infrastructure.Persistence.EventStore

  # Require Logger for proper logging
  require Logger

  setup tags do
    GameBot.Test.DatabaseManager.setup_sandbox(tags)
    :ok
  end

  test "handles event store operations with proper types" do
    # Ensure proper @impl usage
    event = %MyEvent{
      stream_id: "test-stream",
      type: "test_event",
      data: %{value: "test"},
      metadata: %{user_id: "123"}
    }

    assert {:ok, _} = EventStore.append_to_stream(
      event.stream_id,
      :any_version,
      [event]
    )
  end

  test "handles transaction rollbacks properly" do
    # Use proper rollback function
    assert {:error, :rollback} = Repo.transaction(fn ->
      Repo.rollback(:rollback)
    end)
  end
end
```

### Command Handler Type Safety
```elixir
defmodule MyCommandHandlerTest do
  use ExUnit.Case
  alias GameBot.Bot.Commands.GameCommands

  setup tags do
    GameBot.Test.DatabaseManager.setup_sandbox(tags)
    :ok
  end

  test "handles interaction commands with proper types" do
    interaction = %Nostrum.Struct.Interaction{
      application_id: "123",
      channel_id: "456",
      data: %{name: "command", options: []},
      guild_id: "789",
      id: "101112",
      token: "token",
      type: 1,
      user: %Nostrum.Struct.User{
        id: "131415"
      },
      version: 1
    }

    assert {:ok, _response} = GameCommands.handle_command(interaction)
  end
end
```

### Proper Logger Usage
```elixir
defmodule MyLoggerTest do
  use ExUnit.Case
  # Always require Logger when using Logger functions
  require Logger

  setup tags do
    GameBot.Test.DatabaseManager.setup_sandbox(tags)
    :ok
  end

  test "properly logs database operations" do
    Logger.debug("Starting database operation")
    
    result = Repo.transaction(fn ->
      Logger.debug("Inside transaction")
      {:ok, "success"}
    end)

    Logger.debug("Operation result: #{inspect(result)}")
    assert {:ok, "success"} = result
  end
end
```

### PostgreSQL Types
```elixir
defmodule MyPostgresTypesTest do
  use ExUnit.Case
  alias GameBot.Infrastructure.Persistence.PostgresTypes

  setup tags do
    GameBot.Test.DatabaseManager.setup_sandbox(tags)
    :ok
  end

  test "handles custom PostgreSQL types" do
    # Ensure proper type handling
    assert :ok = PostgresTypes.init([])
    
    # Use proper matching for query parameters
    assert PostgresTypes.matching("param", "value")
    
    # Handle encoding and decoding
    assert {:ok, _} = PostgresTypes.encode(:uuid, "123", [])
    assert {:ok, _} = PostgresTypes.decode(:uuid, "123", [])
  end
end 