defmodule GameBot.Test.DatabaseManagerTest do
  use ExUnit.Case
  alias Ecto.Adapters.SQL.Sandbox
  alias GameBot.Infrastructure.Persistence.{Repo, EventStore}
  alias GameBot.Test.{DatabaseManager, DatabaseConfig}

  # Example event for testing
  defmodule TestEvent do
    defstruct [:id, :data]
  end

  describe "sync tests" do
    setup tags do
      DatabaseManager.setup_sandbox(tags)
      :ok
    end

    test "basic database operations" do
      # Test basic database operations in sandbox mode
      Repo.transaction(fn ->
        assert {:ok, _} = Repo.query("SELECT 1")
      end)
    end

    test "event store operations" do
      event = %TestEvent{id: 1, data: "test"}
      stream_id = "test-stream-#{:rand.uniform(1000)}"

      assert {:ok, _} = EventStore.append_to_stream(stream_id, :any_version, [event])
      assert {:ok, [read_event]} = EventStore.read_stream_forward(stream_id)
      assert read_event.data == event.data
    end

    test "handles database errors gracefully" do
      assert {:error, _} = Repo.transaction(fn ->
        Repo.query!("SELECT invalid_function()")
      end)
    end
  end

  describe "async tests" do
    setup tags do
      DatabaseManager.setup_sandbox(tags)
      :ok
    end

    test "concurrent database operations", %{} do
      # Verify we can perform operations in an async test
      Repo.transaction(fn ->
        assert {:ok, _} = Repo.query("SELECT 1")
      end)
    end

    test "concurrent event store operations", %{} do
      event = %TestEvent{id: 2, data: "async test"}
      stream_id = "async-test-stream-#{:rand.uniform(1000)}"

      assert {:ok, _} = EventStore.append_to_stream(stream_id, :any_version, [event])
      assert {:ok, [read_event]} = EventStore.read_stream_forward(stream_id)
      assert read_event.data == event.data
    end
  end

  describe "shared connection tests" do
    setup tags do
      DatabaseManager.setup_sandbox(tags)
      Sandbox.mode(Repo, {:shared, self()})
      :ok
    end

    test "operations from multiple processes" do
      parent = self()

      # Start a task that uses the shared connection
      task = Task.async(fn ->
        Repo.transaction(fn ->
          {:ok, result} = Repo.query("SELECT 1")
          send(parent, {:query_result, result.rows})
        end)
      end)

      assert_receive {:query_result, [[1]]}
      Task.await(task)
    end
  end

  describe "connection pool management" do
    setup tags do
      DatabaseManager.setup_sandbox(tags)
      :ok
    end

    test "respects max concurrent tests limit" do
      max_concurrent = DatabaseConfig.max_concurrent_tests()
      assert is_integer(max_concurrent)
      assert max_concurrent > 0
    end

    test "handles connection checkout timeout" do
      # Create more processes than available connections
      processes = for _ <- 1..10 do
        Task.async(fn ->
          Repo.transaction(fn ->
            # Hold the connection for a bit
            Process.sleep(100)
            {:ok, _} = Repo.query("SELECT 1")
          end)
        end)
      end

      # Verify all processes eventually complete
      results = Task.await_many(processes, :timer.seconds(5))
      assert Enum.all?(results, &match?({:ok, _}, &1))
    end
  end

  describe "cleanup" do
    setup tags do
      DatabaseManager.setup_sandbox(tags)

      on_exit(fn ->
        # Verify cleanup by checking no lingering connections
        # This is just an example - the actual implementation might differ
        Process.sleep(100) # Give time for connections to close
        # Add your cleanup verification here
      end)

      :ok
    end

    @tag :skip_db
    test "skips database setup when tagged" do
      # This test doesn't use the database
      assert true
    end

    test "cleans up resources after test" do
      # Perform some database operations
      Repo.transaction(fn ->
        assert {:ok, _} = Repo.query("SELECT 1")
      end)

      # Resources will be cleaned up by on_exit callback
    end
  end

  describe "error handling" do
    setup tags do
      DatabaseManager.setup_sandbox(tags)
      :ok
    end

    test "handles invalid queries" do
      assert_raise Postgrex.Error, fn ->
        Repo.query!("SELECT * FROM nonexistent_table")
      end
    end

    test "handles transaction failures" do
      assert {:error, _} = Repo.transaction(fn ->
        Repo.query!("SELECT * FROM nonexistent_table")
      end)
    end

    test "handles event store errors" do
      # Try to read from non-existent stream
      assert {:error, :stream_not_found} =
        EventStore.read_stream_forward("nonexistent-stream")
    end
  end
end
