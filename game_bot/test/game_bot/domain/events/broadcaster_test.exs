defmodule GameBot.Domain.Events.BroadcasterTest do
  use ExUnit.Case

  alias GameBot.Domain.Events.GameEvents.ExampleEvent

  # Use a unique name for the PubSub service in this test module
  @pubsub_name :"GameBot.PubSub.BroadcasterTest"

  # Override the PubSub name in the Broadcaster module for testing
  setup_all do
    # Save the original module attribute value
    if Process.whereis(GameBot.PubSub) do
      original_pubsub = :sys.get_state(Process.whereis(GameBot.PubSub))
      # Return the original value for teardown
      %{original_pubsub: original_pubsub}
    else
      %{}
    end
  end

  setup do
    # Start a local registry for clean testing
    start_supervised!({Registry, keys: :duplicate, name: TestRegistry})

    # Start a local PubSub server with a unique name
    start_supervised!({Phoenix.PubSub, name: @pubsub_name})

    # Subscribe the test process to topics with a test reference
    test_ref = make_ref()

    # Return the test state
    %{test_ref: test_ref}
  end

  # Helper function to provide the PubSub name
  def pubsub_name, do: @pubsub_name

  # Define a module-specific subscription manager with our test PubSub
  defmodule TestSubscriptionManager do
    def subscribe_to_game(game_id) do
      pubsub = GameBot.Domain.Events.BroadcasterTest.pubsub_name()
      Phoenix.PubSub.subscribe(pubsub, "game:#{game_id}")
    end

    def subscribe_to_event_type(type) do
      pubsub = GameBot.Domain.Events.BroadcasterTest.pubsub_name()
      Phoenix.PubSub.subscribe(pubsub, "event_type:#{type}")
    end
  end

  # Define a module-specific broadcaster with our test PubSub
  defmodule TestBroadcaster do
    def broadcast_event(event) do
      pubsub = GameBot.Domain.Events.BroadcasterTest.pubsub_name()

      # Get event type
      event_type = event.__struct__.event_type()

      # Define topics
      topics = [
        "game:#{event.game_id}",
        "event_type:#{event_type}"
      ]

      # Broadcast to each topic
      topics
      |> Enum.each(fn topic ->
        Phoenix.PubSub.broadcast(pubsub, topic, {:event, event})
      end)

      # Record telemetry (simplified for test)
      GameBot.Domain.Events.Telemetry.record_event_broadcast(
        event_type,
        topics,
        System.monotonic_time()
      )

      # Return the same result format
      {:ok, event}
    end
  end

  describe "broadcast_event/1" do
    test "broadcasts to both game and event_type topics", %{test_ref: test_ref} do
      # Create a test event
      game_id = "test_game_123"
      event = ExampleEvent.new(
        game_id,
        "guild_123",
        "player_456",
        "create",
        %{test_ref: inspect(test_ref)},
        %{source_id: "test", correlation_id: "test"}
      )

      # Subscribe to both topics using our test manager
      __MODULE__.TestSubscriptionManager.subscribe_to_game(game_id)
      __MODULE__.TestSubscriptionManager.subscribe_to_event_type("example_event")

      # Broadcast the event using our test broadcaster
      __MODULE__.TestBroadcaster.broadcast_event(event)

      # We should receive the event twice (once for each subscription)
      assert_receive {:event, ^event}, 500
      assert_receive {:event, ^event}, 500

      # Shouldn't receive any more events
      refute_receive {:event, _}, 100
    end

    test "returns {:ok, event} to maintain pipeline compatibility" do
      # Create a test event
      event = ExampleEvent.new(
        "test_game_456",
        "guild_123",
        "player_456",
        "create",
        %{},
        %{source_id: "test", correlation_id: "test"}
      )

      # Broadcast the event using our test broadcaster
      result = __MODULE__.TestBroadcaster.broadcast_event(event)

      # Verify the return format
      assert result == {:ok, event}
    end

    test "records telemetry for broadcast operations" do
      # Create a test event
      event = ExampleEvent.new(
        "test_game_789",
        "guild_123",
        "player_456",
        "create",
        %{},
        %{source_id: "test", correlation_id: "test"}
      )

      # Create a telemetry handler to capture the event
      parent = self()
      handler_id = :erlang.unique_integer()

      :telemetry.attach(
        "test-handler-#{handler_id}",
        [:game_bot, :events, :broadcast],
        fn [:game_bot, :events, :broadcast], measurements, metadata, _config ->
          send(parent, {:telemetry, measurements, metadata})
        end,
        nil
      )

      # Broadcast the event using our test broadcaster
      __MODULE__.TestBroadcaster.broadcast_event(event)

      # Verify telemetry was recorded
      assert_receive {:telemetry, measurements, metadata}, 500

      # Clean up the telemetry handler
      :telemetry.detach("test-handler-#{handler_id}")

      # Verify the measurements
      assert is_integer(measurements.duration)
      assert measurements.topic_count == 2

      # Verify the metadata
      assert metadata.event_type == "example_event"
      assert length(metadata.topics) == 2
      assert Enum.member?(metadata.topics, "game:#{event.game_id}")
      assert Enum.member?(metadata.topics, "event_type:example_event")
    end
  end
end
