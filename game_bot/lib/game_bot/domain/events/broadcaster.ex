defmodule GameBot.Domain.Events.Broadcaster do
  @moduledoc """
  Enhanced event broadcasting with dual-topic patterns (game ID and event type).
  """

  alias Phoenix.PubSub
  alias GameBot.Domain.Events.Telemetry

  @pubsub GameBot.PubSub

  @doc """
  Broadcasts an event to game and event-type topics.
  Returns {:ok, event} to maintain pipeline compatibility.
  """
  @spec broadcast_event(struct()) :: {:ok, struct()}
  def broadcast_event(event) do
    start_time = System.monotonic_time()

    # Extract event type
    event_type = event.__struct__.event_type()

    # Define core topics - keep it simple
    topics = [
      # Game-specific channel (existing behavior)
      "game:#{event.game_id}",

      # Event type channel (new)
      "event_type:#{event_type}"
    ]

    # Broadcast to each topic
    topics
    |> Enum.each(fn topic ->
      PubSub.broadcast(@pubsub, topic, {:event, event})
    end)

    # Record telemetry
    duration = System.monotonic_time() - start_time
    Telemetry.record_event_broadcast(event_type, topics, duration)

    # Return the same result format as the existing Pipeline.broadcast/1
    {:ok, event}
  end
end
