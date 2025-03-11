defmodule GameBot.Infrastructure.Persistence.EventStore.Adapter.PostgresTest do
  use ExUnit.Case, async: false
  # Remove the EventStoreCase since it's causing issues
  # use GameBot.EventStoreCase

  alias GameBot.Infrastructure.{Error, ErrorHelpers}
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
  alias GameBot.Infrastructure.Persistence.EventStore.JsonSerializer
  alias GameBot.Infrastructure.Persistence.Repo
  require Logger

  @moduletag :integration
  @moduletag timeout: 120_000  # Increase test timeout to avoid timeouts

  # Define a TestEvent struct that will be properly serialized
  defmodule TestEvent do
    defstruct [:stream_id, :event_type, :data, :metadata, :type, :version]

    def event_type, do: "test_event"
    def event_version, do: 1

    # This is the key function that ensures proper serialization
    def to_map(%__MODULE__{} = event) do
      %{
        "stream_id" => event.stream_id,
        "event_type" => event.event_type,
        "data" => event.data,
        "metadata" => event.metadata
      }
    end

    def from_map(data) do
      %__MODULE__{
        stream_id: data["stream_id"],
        event_type: "test_event",
        data: data["data"],
        metadata: data["metadata"],
        type: "test_event",
        version: 1
      }
    end
  end

  setup_all do
    # Start the applications
    {:ok, _} = Application.ensure_all_started(:postgrex)
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Application.ensure_all_started(:game_bot)

    # Use a direct connection for schema setup
    config = [
      username: "postgres",
      password: "csstarahid",
      hostname: "localhost",
      database: "game_bot_eventstore_test",
      pool_size: 2,
      timeout: 30_000
    ]

    {:ok, conn} = Postgrex.start_link(config)

    # Create schema and tables
    Postgrex.query!(conn, "DROP SCHEMA IF EXISTS event_store CASCADE", [])
    Postgrex.query!(conn, "CREATE SCHEMA event_store", [])
    Postgrex.query!(conn, "SET search_path TO event_store", [])

    Postgrex.query!(conn, """
      CREATE TABLE event_store.streams (
        id text NOT NULL,
        version bigint NOT NULL,
        created_at timestamp without time zone DEFAULT now() NOT NULL,
        PRIMARY KEY(id)
      );
    """, [])
    Postgrex.query!(conn, """
      CREATE TABLE event_store.events (
        event_id bigserial NOT NULL,
        stream_id text NOT NULL,
        event_type text NOT NULL,
        event_data jsonb NOT NULL,
        event_metadata jsonb NOT NULL,
        event_version bigint NOT NULL,
        created_at timestamp without time zone DEFAULT now() NOT NULL,
        PRIMARY KEY(event_id),
        FOREIGN KEY(stream_id) REFERENCES event_store.streams(id)
      );
    """, [])
    Postgrex.query!(conn, """
      CREATE TABLE event_store.subscriptions (
        id bigserial NOT NULL,
        stream_id text NOT NULL,
        subscriber_pid text NOT NULL,
        options jsonb,
        created_at timestamp without time zone DEFAULT now() NOT NULL,
        PRIMARY KEY(id),
        FOREIGN KEY(stream_id) REFERENCES event_store.streams(id)
      );
    """, [])

    # Close the direct connection
    GenServer.stop(conn)

    # Register our TestEvent with the serializer
    original_registry = Application.get_env(:game_bot, :event_registry)

    # Create a mock registry module that knows about our TestEvent
    defmodule TestRegistry do
      def module_for_type("test_event"), do: {:ok, TestEvent}
      def module_for_type(type), do: {:error, :not_found}

      def event_type_for(%TestEvent{}), do: "test_event"
      def event_type_for(_), do: nil

      def event_version_for(%TestEvent{}), do: 1
      def event_version_for(_), do: nil

      def encode_event(%TestEvent{} = event), do: TestEvent.to_map(event)
      def encode_event(_), do: nil

      def decode_event(TestEvent, data), do: TestEvent.from_map(data)
      def decode_event(_, _), do: nil

      def migrate_event(_, _, _, _), do: {:error, :not_supported}
    end

    # Set our test registry
    Application.put_env(:game_bot, :event_registry, TestRegistry)

    on_exit(fn ->
      # Restore the original registry
      Application.put_env(:game_bot, :event_registry, original_registry)
    end)

    :ok
  end

  setup do
    # Set the sandbox to auto mode for simplicity
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo, [])
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Postgres, [])

    # Use auto mode for simplicity in tests
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    Ecto.Adapters.SQL.Sandbox.mode(Postgres, {:shared, self()})

    # Clean up test database before each test
    Repo.query!("TRUNCATE event_store.events CASCADE", [])
    Repo.query!("TRUNCATE event_store.streams CASCADE", [])
    Repo.query!("TRUNCATE event_store.subscriptions CASCADE", [])

    # Clean up on exit
    on_exit(fn ->
      # Reset the sandbox mode
      Ecto.Adapters.SQL.Sandbox.checkin(Repo)
      Ecto.Adapters.SQL.Sandbox.checkin(Postgres)
    end)

    :ok
  end

  # Create a properly structured test event
  defp create_test_event_local(stream_id) do
    # Create a simple map with both atom and string keys
    %{
      "stream_id" => stream_id,
      "event_type" => "test_event",
      "data" => %{"key" => "value"},
      "metadata" => %{"guild_id" => "123456"},
      "type" => "test_event",
      "version" => 1,
      stream_id: stream_id,
      event_type: "test_event",
      data: %{"key" => "value"},
      metadata: %{"guild_id" => "123456"},
      type: "test_event",
      version: 1
    }
  end

  describe "append_to_stream/4" do
    test "successfully appends events to a new stream" do
      stream_id = "stream-#{System.unique_integer([:positive])}"
      event = create_test_event_local(stream_id)
      assert {:ok, 1} = Postgres.append_to_stream(stream_id, :no_stream, [event])
    end

    test "successfully appends multiple events" do
      stream_id = "stream-#{System.unique_integer([:positive])}"
      events = [
        create_test_event_local(stream_id),
        create_test_event_local(stream_id)
      ]
      assert {:ok, 2} = Postgres.append_to_stream(stream_id, :no_stream, events)
    end

    test "handles optimistic concurrency control" do
      stream_id = "stream-#{System.unique_integer([:positive])}"
      event = create_test_event_local(stream_id)
      assert {:ok, 1} = Postgres.append_to_stream(stream_id, :no_stream, [event])
      assert {:ok, 2} = Postgres.append_to_stream(stream_id, 1, [create_test_event_local(stream_id)])
      assert {:error, %Error{type: :concurrency}} = Postgres.append_to_stream(stream_id, 1, [event])
    end

    test "allows :any version for appending" do
      stream_id = "stream-#{System.unique_integer([:positive])}"
      event = create_test_event_local(stream_id)
      assert {:ok, 1} = Postgres.append_to_stream(stream_id, :any, [event])
      assert {:ok, 2} = Postgres.append_to_stream(stream_id, :any, [event])
    end
  end

  describe "read_stream_forward/4" do
    test "reads events from a stream" do
      stream_id = "stream-#{System.unique_integer([:positive])}"
      event = create_test_event_local(stream_id)
      {:ok, _} = Postgres.append_to_stream(stream_id, :no_stream, [event])

      assert {:ok, read_events} = Postgres.read_stream_forward(stream_id)
      assert length(read_events) == 1
      assert Enum.at(read_events, 0).data["key"] == "value"
    end

    test "reads events from a specific version" do
      stream_id = "stream-#{System.unique_integer([:positive])}"
      events = [
        create_test_event_local(stream_id),
        create_test_event_local(stream_id),
        create_test_event_local(stream_id)
      ]
      {:ok, _} = Postgres.append_to_stream(stream_id, :no_stream, events)

      assert {:ok, read_events} = Postgres.read_stream_forward(stream_id, 2)
      assert length(read_events) == 2
      assert Enum.at(read_events, 0).data["key"] == "value"
      assert Enum.at(read_events, 1).data["key"] == "value"
    end

    test "handles non-existent streams" do
      assert {:error, %Error{type: :not_found}} = Postgres.read_stream_forward("non-existent")
    end
  end

  describe "subscribe_to_stream/4" do
    test "successfully subscribes to a stream" do
      # First create a stream
      stream_id = "stream-#{System.unique_integer([:positive])}"
      {:ok, _} = Postgres.append_to_stream(stream_id, :no_stream, [create_test_event_local(stream_id)])

      # Then subscribe to it - use a string subscriber ID instead of a PID
      assert {:ok, subscription} = Postgres.subscribe_to_stream(stream_id, "test-subscriber")
      assert is_reference(subscription)
    end

    test "handles subscription to non-existent stream" do
      assert {:error, %Error{type: :not_found}} =
        Postgres.subscribe_to_stream("non-existent", "test-subscriber")
    end

    test "supports subscription options" do
      stream_id = "stream-#{System.unique_integer([:positive])}"
      {:ok, _} = Postgres.append_to_stream(stream_id, :no_stream, [create_test_event_local(stream_id)])
      options = [start_from: :origin]

      assert {:ok, subscription} = Postgres.subscribe_to_stream(stream_id, "test-subscriber", options)
      assert is_reference(subscription)
    end
  end

  describe "stream_version/2" do
    test "returns 0 for non-existent stream" do
      assert {:ok, 0} = Postgres.stream_version("non-existent")
    end

    test "returns current version for existing stream" do
      stream_id = "stream-#{System.unique_integer([:positive])}"
      event = create_test_event_local(stream_id)
      {:ok, version} = Postgres.append_to_stream(stream_id, :no_stream, [event])
      assert {:ok, ^version} = Postgres.stream_version(stream_id)
    end
  end

  describe "delete_stream/3" do
    test "successfully deletes a stream" do
      # First create a stream
      stream_id = "stream-#{System.unique_integer([:positive])}"
      event = create_test_event_local(stream_id)
      {:ok, version} = Postgres.append_to_stream(stream_id, :no_stream, [event])

      # Then delete it
      assert :ok = Postgres.delete_stream(stream_id, version)

      # Verify it's gone
      assert {:ok, 0} = Postgres.stream_version(stream_id)
      assert {:error, %Error{type: :not_found}} = Postgres.read_stream_forward(stream_id)
    end

    test "handles optimistic concurrency on delete" do
      stream_id = "stream-#{System.unique_integer([:positive])}"
      event = create_test_event_local(stream_id)
      {:ok, _} = Postgres.append_to_stream(stream_id, :no_stream, [event])

      assert {:error, %Error{type: :concurrency}} = Postgres.delete_stream(stream_id, 999)
    end

    test "handles deleting non-existent stream" do
      assert {:error, %Error{type: :not_found}} = Postgres.delete_stream("non-existent", 0)
    end
  end
end
