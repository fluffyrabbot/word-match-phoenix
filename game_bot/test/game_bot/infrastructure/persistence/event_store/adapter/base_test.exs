defmodule GameBot.Infrastructure.Persistence.EventStore.Adapter.BaseTest do
  use ExUnit.Case, async: false

  alias GameBot.Infrastructure.Error
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Base
  alias GameBot.Infrastructure.Persistence.EventStore.Serialization.JsonSerializer

  # Define the TestEvent struct for tests
  defmodule TestEvent do
    defstruct [:id, :stream_id, :event_type, :data, :metadata]

    # Add implementation of required functions for event serialization
    def event_type, do: "test_event"
    def event_version, do: 1
  end

  defmodule TestAdapter do
    use Base, serializer: JsonSerializer

    def do_append_to_stream("success", _version, events, _opts), do: {:ok, length(events)}
    def do_append_to_stream("retry", _version, _events, _opts) do
      if :ets.update_counter(:retry_counter, :count, {2, 1}) < 3 do
        {:error, Error.connection_error(__MODULE__, "Connection failed")}
      else
        {:ok, 1}
      end
    end
    def do_append_to_stream("error", _version, _events, _opts) do
      {:error, Error.validation_error(__MODULE__, "Invalid stream")}
    end

    def do_read_stream_forward("success", _start, count, _opts) do
      # Return properly structured events for deserialization
      events = Enum.map(1..count, fn i ->
        %{
          "id" => "event_#{i}",
          "type" => "test_event",
          "version" => 1,
          "data" => %{"test" => "value_#{i}"},
          "metadata" => %{"meta" => "data_#{i}"},
          "stream_id" => "success"
        }
      end)
      {:ok, events}
    end

    def do_read_stream_forward("retry", _start, _count, _opts) do
      if :ets.update_counter(:retry_counter, :count, {2, 1}) < 3 do
        {:error, Error.connection_error(__MODULE__, "Connection failed")}
      else
        # Return a properly structured event
        {:ok, [
          %{
            "id" => "retry_event",
            "type" => "test_event",
            "version" => 1,
            "data" => %{"test" => "retry_value"},
            "metadata" => %{"meta" => "retry_data"},
            "stream_id" => "retry"
          }
        ]}
      end
    end

    def do_read_stream_forward("error", _start, _count, _opts) do
      {:error, Error.not_found_error(__MODULE__, "Stream not found")}
    end

    def do_subscribe_to_stream("success", _subscriber, _options, _opts), do: {:ok, make_ref()}
    def do_subscribe_to_stream("retry", _subscriber, _options, _opts) do
      if :ets.update_counter(:retry_counter, :count, {2, 1}) < 3 do
        {:error, Error.connection_error(__MODULE__, "Connection failed")}
      else
        {:ok, make_ref()}
      end
    end
    def do_subscribe_to_stream("error", _subscriber, _options, _opts) do
      {:error, Error.validation_error(__MODULE__, "Invalid subscription")}
    end
  end

  # Global setup for all tests
  setup do
    # Set up the retry counter
    :ets.new(:retry_counter, [:set, :public, :named_table])
    :ets.insert(:retry_counter, {:count, 0})

    # Set up telemetry for all tests that need it
    test_pid = self()

    # Clean up any previous handlers
    :telemetry.list_handlers([])
    |> Enum.each(fn %{id: id} ->
      :telemetry.detach(id)
    end)

    # Define a module for telemetry handler to avoid using local functions
    defmodule TelemetryHandler do
      def handle_event(name, measurements, metadata, config) do
        test_pid = config
        send(test_pid, {:telemetry, name, measurements, metadata})
      end
    end

    # Attach new handler using the module function
    :telemetry.attach(
      "test-handler-#{inspect(self())}",
      [:game_bot, :event_store, :append],
      &TelemetryHandler.handle_event/4,
      test_pid
    )

    on_exit(fn ->
      # Clean up telemetry handlers on test completion
      :telemetry.detach("test-handler-#{inspect(self())}")
    end)

    :ok
  end

  describe "append_to_stream/4" do
    test "successfully appends events" do
      event = %TestEvent{id: "test"}
      assert {:ok, 1} = TestAdapter.append_to_stream("success", 0, [event])
    end

    test "retries on transient errors" do
      event = %TestEvent{id: "test"}
      assert {:ok, 1} = TestAdapter.append_to_stream("retry", 0, [event])
      assert :ets.lookup_element(:retry_counter, :count, 2) == 3
    end

    test "returns error on permanent failure" do
      event = %TestEvent{id: "test"}
      assert {:error, %Error{type: :validation}} = TestAdapter.append_to_stream("error", 0, [event])
    end
  end

  describe "read_stream_forward/4" do
    test "successfully reads events" do
      assert {:ok, events} = TestAdapter.read_stream_forward("success", 0, 2)
      assert length(events) == 2
    end

    test "retries on transient errors" do
      assert {:ok, [_event]} = TestAdapter.read_stream_forward("retry", 0, 1)
      assert :ets.lookup_element(:retry_counter, :count, 2) == 3
    end

    test "returns error on permanent failure" do
      assert {:error, %Error{type: :not_found}} = TestAdapter.read_stream_forward("error", 0, 1)
    end
  end

  describe "subscribe_to_stream/4" do
    test "successfully subscribes to stream" do
      assert {:ok, subscription} = TestAdapter.subscribe_to_stream("success", self())
      assert is_reference(subscription)
    end

    test "retries on transient errors" do
      assert {:ok, subscription} = TestAdapter.subscribe_to_stream("retry", self())
      assert is_reference(subscription)
      assert :ets.lookup_element(:retry_counter, :count, 2) == 3
    end

    test "returns error on permanent failure" do
      assert {:error, %Error{type: :validation}} = TestAdapter.subscribe_to_stream("error", self())
    end
  end

  describe "telemetry" do
    test "emits telemetry events for successful operations" do
      event = %TestEvent{id: "test"}
      TestAdapter.append_to_stream("success", 0, [event])

      # Wait for telemetry event to be received
      Process.sleep(500)

      # Verify event was received
      assert_received {:telemetry, [:game_bot, :event_store, :append], %{duration: _},
        %{
          operation: :append,
          stream_id: "success",
          result: :ok,
          error: nil,
          metadata: %{adapter: TestAdapter}
        }}
    end

    test "emits telemetry events for failed operations" do
      event = %TestEvent{id: "test"}
      TestAdapter.append_to_stream("error", 0, [event])

      # Wait for telemetry event to be received
      Process.sleep(500)

      # Verify event was received
      assert_received {:telemetry, [:game_bot, :event_store, :append], %{duration: _},
        %{
          operation: :append,
          stream_id: "error",
          result: :error,
          error: %Error{type: :validation},
          metadata: %{adapter: TestAdapter}
        }}
    end
  end
end
