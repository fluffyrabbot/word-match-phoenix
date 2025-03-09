defmodule GameBot.Domain.Events.HandlerTest do
  use ExUnit.Case, async: true

  alias GameBot.Domain.Events.GameEvents.ExampleEvent

  # Use a unique name for the PubSub in this test module
  @pubsub_name :"GameBot.PubSub.HandlerTest"

  # Define a test handler module for testing
  defmodule TestEventHandler do
    use GenServer
    require Logger

    # Store the pubsub name for use in the handler
    def pubsub_name, do: GameBot.Domain.Events.HandlerTest.pubsub_name()

    def start_link(opts) do
      parent = Keyword.fetch!(opts, :parent)
      GenServer.start_link(__MODULE__, %{parent: parent}, name: __MODULE__)
    end

    @impl true
    def init(state) do
      send(state.parent, {:init_called, self()})
      # Subscribe to interests manually
      subscribe_to_interests()
      {:ok, state}
    end

    def interests do
      ["event_type:example_event", "game:test_game_123"]
    end

    def handle_event(event, state) do
      send(state.parent, {:event_handled, event})
      :ok
    end

    @impl true
    def handle_info({:event, event}, state) do
      try do
        handle_event(event, state)
        {:noreply, state}
      rescue
        e ->
          Logger.error("Error handling event #{inspect(event.__struct__)}: #{Exception.message(e)}")
          {:noreply, state}
      end
    end

    @impl true
    def handle_info({:simulate_error, event}, state) do
      # Handle with error
      send(state.parent, {:error_simulation, event})
      {:noreply, state}
    end

    @impl true
    def handle_info({:simulate_crash}, state) do
      # Crash the process to test recovery
      send(state.parent, :before_crash)
      raise "simulated crash"
    end

    defp subscribe_to_interests do
      pubsub = pubsub_name()

      # Subscribe to each interest
      for interest <- interests() do
        case interest do
          "game:" <> game_id ->
            Phoenix.PubSub.subscribe(pubsub, "game:#{game_id}")
          "event_type:" <> type ->
            Phoenix.PubSub.subscribe(pubsub, "event_type:#{type}")
          _ ->
            Phoenix.PubSub.subscribe(pubsub, interest)
        end
      end
    end
  end

  # Helper function to provide the PubSub name
  def pubsub_name, do: @pubsub_name

  setup do
    # Start a PubSub server for testing with a unique name
    start_supervised!({Phoenix.PubSub, name: @pubsub_name})

    # Start our test handler
    parent = self()
    start_supervised!({TestEventHandler, [parent: parent]})

    # Create a test event
    event = ExampleEvent.new(
      "test_game_123",
      "guild_123",
      "player_456",
      "create",
      %{},
      %{source_id: "test", correlation_id: "test"}
    )

    # Return the test state
    %{event: event, parent: parent}
  end

  describe "Handler behavior" do
    test "initializes and subscribes to interests" do
      # Verify that init was called
      assert_receive {:init_called, _pid}, 500

      # Broadcast a message to test subscriptions
      Phoenix.PubSub.broadcast(
        @pubsub_name,
        "event_type:example_event",
        {:event, %{test: "message"}}
      )

      # Verify the handler received the message
      assert_receive {:event_handled, %{test: "message"}}, 500
    end

    test "handles events properly", %{event: event} do
      # Broadcast an event
      Phoenix.PubSub.broadcast(@pubsub_name, "game:test_game_123", {:event, event})

      # Verify the handler processed it
      assert_receive {:event_handled, ^event}, 500
    end

    test "recovers from crashes", %{event: event} do
      # Get the PID before the crash
      pid_before = GenServer.whereis(TestEventHandler)
      assert is_pid(pid_before)

      # Simulate a crash
      send(pid_before, {:simulate_crash})

      # Verify we got the before_crash message
      assert_receive :before_crash, 500

      # Wait for the process to restart
      wait_for_restart = fn ->
        pid_after = GenServer.whereis(TestEventHandler)
        is_pid(pid_after) and pid_after != pid_before
      end

      # Wait for the handler to restart (max 100 tries * 10ms = 1s)
      wait_until(wait_for_restart, 100, 10)

      # Verify we have a new PID
      pid_after = GenServer.whereis(TestEventHandler)
      assert is_pid(pid_after)
      assert pid_after != pid_before

      # Verify the handler still receives events after crashing
      Phoenix.PubSub.broadcast(@pubsub_name, "game:test_game_123", {:event, event})

      # Verify the handler processed it
      assert_receive {:event_handled, ^event}, 500
    end
  end

  # Helper function to wait until a condition is met
  defp wait_until(fun, retries, sleep_ms) do
    if retries > 0 do
      if fun.() do
        :ok
      else
        :timer.sleep(sleep_ms)
        wait_until(fun, retries - 1, sleep_ms)
      end
    else
      {:error, :timeout}
    end
  end
end
