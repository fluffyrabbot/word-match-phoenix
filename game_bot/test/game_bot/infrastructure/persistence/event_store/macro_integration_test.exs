defmodule GameBot.Infrastructure.Persistence.EventStore.MacroIntegrationTest do
  @moduledoc """
  Tests for proper EventStore macro integration across implementations.

  This test focuses primarily on the Postgres implementation since that's
  the one that requires an actual database connection.
  """

  use ExUnit.Case, async: false

  # Define a TestEvent struct for the tests
  defmodule TestEvent do
    @moduledoc false
    defstruct [:data, :metadata]

    def event_type, do: "test_event"
    def event_version, do: 1

    # Add to_map function to control serialization
    def to_map(%__MODULE__{} = event) do
      %{
        data: event.data,
        metadata: event.metadata
      }
    end
  end

  # The main implementation to test
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres, as: EventStore

  # Set a shorter timeout for database operations
  @db_timeout 5_000
  @test_stream_id "test-macro-integration-#{:erlang.unique_integer([:positive])}"

  setup do
    # Clean up connections first
    cleanup_existing_connections()

    # Set up the database connection for the test
    checkout_connection()

    # Return context
    [test_stream_id: @test_stream_id]
  end

  test "EventStore implementation makes key functions available" do
    # Verify the EventStore implements all required functions
    assert function_exported?(EventStore, :append_to_stream, 4)
    assert function_exported?(EventStore, :read_stream_forward, 4)
    assert function_exported?(EventStore, :stream_version, 2)
    assert function_exported?(EventStore, :subscribe_to_stream, 4)
    assert function_exported?(EventStore, :delete_stream, 3)
  end

  test "append and read stream operations work", %{test_stream_id: stream_id} do
    # Create a test event
    event = %TestEvent{
      data: %{test: "data"},
      metadata: %{guild_id: "test-guild-1"}
    }

    # Append the event to the stream
    {:ok, version} = EventStore.append_to_stream(stream_id, :no_stream, [event], [timeout: @db_timeout])
    assert is_integer(version) && version > 0

    # Read the event back from the stream
    {:ok, read_events} = EventStore.read_stream_forward(stream_id, 0, 1000, [timeout: @db_timeout])
    assert length(read_events) == 1
    read_event = hd(read_events)
    assert read_event.data == event.data
  end

  test "stream_version returns correct version", %{test_stream_id: stream_id} do
    # Create and append an event
    event = %TestEvent{
      data: %{test: "version_test"},
      metadata: %{guild_id: "test-guild-1"}
    }

    # Check initial version
    {:ok, initial_version} = EventStore.stream_version(stream_id, [timeout: @db_timeout])
    assert initial_version == 0

    # Append event and check updated version
    {:ok, new_version} = EventStore.append_to_stream(stream_id, :no_stream, [event], [timeout: @db_timeout])
    assert new_version > initial_version

    # Verify stream_version returns the updated version
    {:ok, current_version} = EventStore.stream_version(stream_id, [timeout: @db_timeout])
    assert current_version == new_version
  end

  test "delete_stream removes the stream", %{test_stream_id: stream_id} do
    # Create and append an event
    event = %TestEvent{
      data: %{test: "delete_test"},
      metadata: %{guild_id: "test-guild-1"}
    }

    # Append to create the stream
    {:ok, version} = EventStore.append_to_stream(stream_id, :no_stream, [event], [timeout: @db_timeout])

    # Verify stream exists
    {:ok, read_events} = EventStore.read_stream_forward(stream_id, 0, 1000, [timeout: @db_timeout])
    assert length(read_events) == 1

    # Delete the stream
    :ok = EventStore.delete_stream(stream_id, version, [timeout: @db_timeout])

    # Verify stream no longer exists (will return an empty list or error depending on implementation)
    case EventStore.read_stream_forward(stream_id, 0, 1000, [timeout: @db_timeout]) do
      {:ok, []} -> :ok  # Some implementations return empty list
      {:error, _} -> :ok  # Some return an error for non-existent streams
      _ -> flunk("Expected empty stream or error after deletion")
    end
  end

  # Helper functions

  defp checkout_connection do
    # Check to see if the EventStore module is available
    if Process.whereis(EventStore) == nil do
      # Start the repository with a direct connection
      config = [
        username: "postgres",
        password: "csstarahid",
        hostname: "localhost",
        database: "game_bot_eventstore_test",
        port: 5432,
        pool: Ecto.Adapters.SQL.Sandbox,
        pool_size: 2,
        timeout: @db_timeout
      ]

      {:ok, _} = EventStore.start_link(config)
    end

    # Check it out for the test
    Ecto.Adapters.SQL.Sandbox.checkout(EventStore)
  end

  defp cleanup_existing_connections do
    # Close any existing Postgrex connections to prevent issues
    for pid <- Process.list() do
      info = Process.info(pid, [:dictionary])
      if info && get_in(info, [:dictionary, :"$initial_call"]) == {Postgrex.Protocol, :init, 1} do
        Process.exit(pid, :kill)
      end
    end

    # Small delay to allow processes to terminate
    Process.sleep(100)
  end
end
