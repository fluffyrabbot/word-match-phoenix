# Enhanced PubSub System Usage Guide

This guide explains how to use the enhanced PubSub system for event handling in the GameBot application.

## Overview

The enhanced PubSub system provides focused topic-based subscriptions, allowing components to subscribe to:
- Game-specific events
- Event type-specific events (across all games)

This approach reduces unnecessary message processing and improves system modularity.

## Subscription Patterns

### Using the SubscriptionManager

The `GameBot.Domain.Events.SubscriptionManager` provides standard subscription helpers:

```elixir
alias GameBot.Domain.Events.SubscriptionManager

# Subscribe to all events for a specific game
SubscriptionManager.subscribe_to_game("game_123")

# Subscribe to all events of a specific type, across all games
SubscriptionManager.subscribe_to_event_type("game_started")

# Unsubscribe from a topic
SubscriptionManager.unsubscribe("game:game_123")
```

### Topic Format

Topics follow these standard patterns:
- `game:{game_id}` - For all events in a specific game
- `event_type:{event_type}` - For all events of a specific type

## Creating Event Handlers

### Using the Handler Behavior

The `GameBot.Domain.Events.Handler` behavior simplifies creating robust event handlers:

```elixir
defmodule MyApp.GameCompletionNotifier do
  use GameBot.Domain.Events.Handler, 
    interests: ["event_type:game_completed"]
  
  @impl true
  def handle_event(%GameBot.Domain.Events.GameEvents.GameCompleted{} = event) do
    # Process the game completed event
    Logger.info("Game #{event.game_id} completed!")
    
    # Do something with the event...
    
    :ok
  end
  
  # Ignore other event types
  def handle_event(_), do: :ok
end
```

### Registering Handlers

Add your handler to your application's supervision tree:

```elixir
defmodule MyApp.Application do
  use Application
  
  def start(_type, _args) do
    children = [
      # ... other children
      MyApp.GameCompletionNotifier
    ]
    
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

### Advanced: Subscribing to Multiple Interests

Handlers can subscribe to multiple interests:

```elixir
defmodule MyApp.GameStatusTracker do
  use GameBot.Domain.Events.Handler
  
  @impl true
  def interests do
    [
      "event_type:game_started",
      "event_type:game_completed",
      "game:special_tournament_123"
    ]
  end
  
  @impl true
  def handle_event(event) do
    # Process events based on their type
    case event do
      %GameBot.Domain.Events.GameEvents.GameStarted{} ->
        # Handle game started
        :ok
        
      %GameBot.Domain.Events.GameEvents.GameCompleted{} ->
        # Handle game completed
        :ok
        
      _ ->
        # Handle other event types from the specific game
        :ok
    end
  end
end
```

## Error Handling

The Handler behavior automatically:
- Logs errors from event handling
- Recovers from exceptions
- Resubscribes to topics after crashes
- Continues processing subsequent events

## Broadcasting Events

For most applications, you won't need to broadcast events directly as the `Pipeline` module handles this automatically. However, if you need to broadcast events manually:

```elixir
alias GameBot.Domain.Events.Broadcaster

# Broadcast an event to appropriate topics
Broadcaster.broadcast_event(event)
```

## Telemetry Measurements

The enhanced PubSub system includes telemetry measurements for broadcast operations:

- Event: `[:game_bot, :events, :broadcast]`
- Measurements:
  - `duration`: Time taken to broadcast the event (in monotonic time)
  - `topic_count`: Number of topics the event was broadcast to
- Metadata:
  - `event_type`: Type of the event
  - `topics`: List of topics the event was broadcast to
  - `timestamp`: When the broadcast occurred

## Enabling Enhanced PubSub

The enhanced PubSub system is controlled by a feature flag in the application configuration:

```elixir
# In config/config.exs (or environment-specific config)
config :game_bot, :event_system,
  use_enhanced_pubsub: true  # Set to false to use legacy broadcasting
```

This enables gradual adoption and easy rollback if needed.

## Best Practices

1. **Topic Granularity**: Subscribe to the most specific topic possible to minimize unnecessary message processing
2. **Error Handling**: Always handle errors gracefully in your event handlers
3. **State Management**: Use GenServer state to track processed events and avoid duplicate processing
4. **Pattern Matching**: Use pattern matching to handle specific event types efficiently 