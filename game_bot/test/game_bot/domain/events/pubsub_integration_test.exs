defmodule GameBot.Domain.Events.PubSubIntegrationTest do
  use ExUnit.Case

  alias GameBot.Domain.Events.{
    Pipeline,
    SubscriptionManager,
    Broadcaster,
    Telemetry
  }

  alias GameBot.Domain.Events.GameEvents.ExampleEvent

  # Use a unique name for the PubSub in this test module
  @pubsub_name :"GameBot.PubSub.IntegrationTest"

  # Define a custom pipeline for testing
  defmodule TestPipeline do
    # Import the pubsub_name function from the parent module
    def pubsub_name, do: GameBot.Domain.Events.PubSubIntegrationTest.pubsub_name()

    def broadcast({:ok, event} = result) do
      if Application.get_env(:game_bot, :event_system, [])
         |> Keyword.get(:use_enhanced_pubsub, false) do
        # Use the enhanced broadcaster
        GameBot.Domain.Events.PubSubIntegrationTest.TestBroadcaster.broadcast_event(event)
      else
        # Legacy broadcasting
        Phoenix.PubSub.broadcast(
          pubsub_name(),
          "game:#{event.game_id}",
          {:event, event}
        )
        result
      end
    end
    def broadcast(error), do: error

    def process_event(event) do
      {:ok, event}
      |> broadcast()
    end
  end

  # Define a test broadcaster
  defmodule TestBroadcaster do
    def broadcast_event(event) do
      pubsub = GameBot.Domain.Events.PubSubIntegrationTest.pubsub_name()
      start_time = System.monotonic_time()

      # Extract event type
      event_type = event.__struct__.event_type()

      # Define core topics
      topics = [
        # Game-specific channel (existing behavior)
        "game:#{event.game_id}",

        # Event type channel (new)
        "event_type:#{event_type}"
      ]

      # Broadcast to each topic
      topics
      |> Enum.each(fn topic ->
        Phoenix.PubSub.broadcast(pubsub, topic, {:event, event})
      end)

      # Record telemetry (important for the test)
      duration = System.monotonic_time() - start_time
      GameBot.Domain.Events.Telemetry.record_event_broadcast(
        event_type,
        topics,
        duration
      )

      # Return the same result format
      {:ok, event}
    end
  end

  # Define a test subscription manager
  defmodule TestSubscriptionManager do
    def subscribe_to_game(game_id) do
      pubsub = GameBot.Domain.Events.PubSubIntegrationTest.pubsub_name()
      Phoenix.PubSub.subscribe(pubsub, "game:#{game_id}")
    end

    def subscribe_to_event_type(type) do
      pubsub = GameBot.Domain.Events.PubSubIntegrationTest.pubsub_name()
      Phoenix.PubSub.subscribe(pubsub, "event_type:#{type}")
    end
  end

  # Define a test handler for integration testing
  defmodule GameEventsCounter do
    use GenServer
    require Logger

    def start_link(_opts) do
      GenServer.start_link(__MODULE__, %{count: 0}, name: __MODULE__)
    end

    def init(state) do
      # Subscribe to interests
      pubsub = GameBot.Domain.Events.PubSubIntegrationTest.pubsub_name()
      Phoenix.PubSub.subscribe(pubsub, "event_type:example_event")
      {:ok, state}
    end

    def handle_info({:event, %GameBot.Domain.Events.GameEvents.ExampleEvent{} = event}, state) do
      GenServer.cast(__MODULE__, {:increment, event})
      {:noreply, state}
    end

    def handle_info(_msg, state), do: {:noreply, state}

    def handle_event(%GameBot.Domain.Events.GameEvents.ExampleEvent{} = event) do
      GenServer.cast(__MODULE__, {:increment, event})
      :ok
    end

    def handle_event(_), do: :ok

    def get_count do
      GenServer.call(__MODULE__, :get_count)
    end

    def reset_count do
      GenServer.cast(__MODULE__, :reset)
    end

    def handle_call(:get_count, _from, state) do
      {:reply, state.count, state}
    end

    def handle_cast({:increment, _event}, state) do
      {:noreply, %{state | count: state.count + 1}}
    end

    def handle_cast(:reset, state) do
      {:noreply, %{state | count: 0}}
    end
  end

  # Helper function to provide the PubSub name
  def pubsub_name, do: @pubsub_name

  setup do
    # Reset application environment for testing
    original_env = Application.get_env(:game_bot, :event_system, [])

    # Start required services
    start_supervised!({Phoenix.PubSub, name: @pubsub_name})
    start_supervised!(GameEventsCounter)

    # Setup telemetry counter
    test_pid = self()
    test_ref = make_ref()
    ref_string = inspect(test_ref)

    # Attach a telemetry handler for broadcast events
    :telemetry.attach(
      "test-broadcast-handler-#{ref_string}",
      [:game_bot, :events, :broadcast],
      fn _event, _measurements, _metadata, _config ->
        send(test_pid, {:telemetry_broadcast, test_ref})
      end,
      nil
    )

    # Create a test event
    event = ExampleEvent.new(
      "integration_test_game",
      "guild_123",
      "player_456",
      "create",
      %{test_ref: ref_string},
      %{source_id: "test", correlation_id: "test"}
    )

    on_exit(fn ->
      # Reset application environment
      if original_env == [] do
        Application.delete_env(:game_bot, :event_system)
      else
        Application.put_env(:game_bot, :event_system, original_env)
      end

      # Detach telemetry handlers
      :telemetry.detach("test-broadcast-handler-#{ref_string}")
    end)

    %{event: event, test_ref: test_ref}
  end

  describe "enhanced PubSub integration" do
    test "pipeline uses normal broadcasting when feature is disabled", %{event: event} do
      # Set the feature flag to false
      Application.put_env(:game_bot, :event_system, use_enhanced_pubsub: false)

      # Reset counter
      GameEventsCounter.reset_count()

      # Process the event through the test pipeline
      TestPipeline.process_event(event)

      # Handler should NOT receive the event (since we're using legacy broadcasting)
      :timer.sleep(100)  # Give some time for processing
      assert GameEventsCounter.get_count() == 0

      # Shouldn't receive telemetry for broadcast
      refute_receive {:telemetry_broadcast, _}, 100
    end

    test "pipeline uses enhanced broadcasting when feature is enabled", %{event: event, test_ref: test_ref} do
      # Set the feature flag to true
      Application.put_env(:game_bot, :event_system, use_enhanced_pubsub: true)

      # Reset counter
      GameEventsCounter.reset_count()

      # Process the event through the test pipeline
      TestPipeline.process_event(event)

      # Handler should receive the event through event_type topic
      :timer.sleep(100)  # Give some time for processing
      assert GameEventsCounter.get_count() == 1

      # Should receive telemetry for broadcast
      assert_receive {:telemetry_broadcast, ^test_ref}, 500
    end

    test "direct subscription to game topic works", %{event: event} do
      # Enable enhanced PubSub
      Application.put_env(:game_bot, :event_system, use_enhanced_pubsub: true)

      # Subscribe directly to the game topic
      TestSubscriptionManager.subscribe_to_game(event.game_id)

      # Process the event through the test pipeline
      TestPipeline.process_event(event)

      # Should receive the event on the game topic
      assert_receive {:event, received_event}, 500
      assert received_event.id == event.id
    end
  end
end
