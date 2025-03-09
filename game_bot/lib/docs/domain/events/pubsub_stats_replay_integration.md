# Integrating PubSub with Stats and Replay Systems

## Overview

This document outlines how to integrate the enhanced Phoenix PubSub implementation with stats collection and event replay systems. The enhanced PubSub provides an efficient foundation for both systems by enabling targeted subscriptions and standardized event handling.

## Key Benefits for Stats and Replay Systems

| Feature | Stats System Benefit | Replay System Benefit |
|---------|---------------------|----------------------|
| Event Type Subscriptions | Subscribe only to stats-relevant events | Filter events by type for specific replays |
| Standardized Handlers | Consistent stats processing | Uniform replay event handling |
| Error Recovery | Reliable stats collection | Robust replay processing |
| Telemetry | Monitor stats collection performance | Track replay system efficiency |

## Stats System Integration

### Architecture

The stats system can leverage the enhanced PubSub system to efficiently collect and process game statistics:

```
┌─────────────┐     ┌───────────────┐     ┌────────────────┐
│ Game Events │────▶│ PubSub System │────▶│ Stats Handlers │
└─────────────┘     └───────────────┘     └────────────────┘
                           │                      │
                           ▼                      ▼
                    ┌─────────────┐      ┌────────────────┐
                    │ Event Types │      │  Stats Storage │
                    └─────────────┘      └────────────────┘
```

### Stats Collection Handlers

Implement handlers for different stat categories that subscribe only to relevant event types:

```elixir
defmodule GameBot.Stats.GameCompletionHandler do
  use GameBot.Domain.Events.Handler, 
    interests: ["event_type:game_completed"]
  
  @impl true
  def handle_event(event) do
    # Process game completion stats
    GameBot.Stats.Storage.record_game_stats(
      game_id: event.game_id,
      duration: calculate_duration(event),
      players: event.player_count,
      winner: extract_winner(event)
    )
    :ok
  end
  
  # Helper functions
  defp calculate_duration(event) do
    # Calculate game duration from started_at and completed_at
  end
  
  defp extract_winner(event) do
    # Extract winner information from the event
  end
end
```

Additional handlers for other stat categories:

```elixir
defmodule GameBot.Stats.PlayerPerformanceHandler do
  use GameBot.Domain.Events.Handler, 
    interests: ["event_type:guess_processed", "event_type:player_eliminated"]
  
  # ...implementation
end

defmodule GameBot.Stats.DailyActivityHandler do
  use GameBot.Domain.Events.Handler,
    interests: ["event_type:game_started", "event_type:game_completed"]
  
  # ...implementation
end
```

### Stats Aggregation

Use event type subscriptions to aggregate stats for specific time periods:

```elixir
defmodule GameBot.Stats.AggregationHandler do
  use GameBot.Domain.Events.Handler,
    interests: ["event_type:game_completed"]
  
  @impl true
  def handle_event(event) do
    # Aggregate stats by day, week, month
    update_daily_stats(event)
    update_weekly_stats(event)
    update_monthly_stats(event)
    :ok
  end
  
  # ...implementation
end
```

## Replay System Integration

### Architecture

The replay system uses PubSub to reconstruct game state from events for playback:

```
┌─────────────┐     ┌───────────────┐     ┌────────────────┐
│ Event Store │────▶│ PubSub System │────▶│ Replay Handler │
└─────────────┘     └───────────────┘     └────────────────┘
                                                  │
                                                  ▼
                                          ┌────────────────┐
                                          │  Game Rebuild  │
                                          └────────────────┘
                                                  │
                                                  ▼
                                          ┌────────────────┐
                                          │   Playback     │
                                          └────────────────┘
```

### Replay Processing

Create a specialized handler for replay processing:

```elixir
defmodule GameBot.Replay.EventProcessor do
  use GenServer
  alias GameBot.Domain.Events.SubscriptionManager
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple(opts[:replay_id]))
  end
  
  def init(opts) do
    # Subscribe to all events for this game
    SubscriptionManager.subscribe_to_game(opts[:game_id])
    
    {:ok, %{
      game_id: opts[:game_id],
      replay_id: opts[:replay_id],
      events: [],
      current_position: 0
    }}
  end
  
  def handle_info({:event, event}, state) do
    # Store event in sequence
    updated_events = [event | state.events]
    
    # Update replay state
    {:noreply, %{state | events: updated_events}}
  end
  
  # API for controlling replay
  def advance(replay_id) do
    GenServer.call(via_tuple(replay_id), :advance)
  end
  
  def rewind(replay_id) do
    GenServer.call(via_tuple(replay_id), :rewind)
  end
  
  def jump_to(replay_id, position) do
    GenServer.call(via_tuple(replay_id), {:jump_to, position})
  end
  
  def handle_call(:advance, _from, state) do
    new_position = min(state.current_position + 1, length(state.events) - 1)
    {:reply, {:ok, get_event_at(state, new_position)}, %{state | current_position: new_position}}
  end
  
  def handle_call(:rewind, _from, state) do
    new_position = max(state.current_position - 1, 0)
    {:reply, {:ok, get_event_at(state, new_position)}, %{state | current_position: new_position}}
  end
  
  def handle_call({:jump_to, position}, _from, state) do
    capped_position = min(max(position, 0), length(state.events) - 1)
    {:reply, {:ok, get_event_at(state, capped_position)}, %{state | current_position: capped_position}}
  end
  
  # Helper functions
  defp get_event_at(state, position) do
    Enum.at(state.events, position)
  end
  
  defp via_tuple(replay_id) do
    {:via, Registry, {GameBot.Registry, {:replay, replay_id}}}
  end
end
```

### Creating a Replay Session

```elixir
defmodule GameBot.Replay.Session do
  alias GameBot.Replay.EventProcessor
  alias GameBot.Infrastructure.Persistence.EventStore
  
  def create_replay(game_id) do
    # Generate unique replay ID
    replay_id = UUID.uuid4()
    
    # Start the replay processor
    {:ok, _pid} = EventProcessor.start_link(game_id: game_id, replay_id: replay_id)
    
    # Load all events from storage
    load_historical_events(game_id, replay_id)
    
    {:ok, replay_id}
  end
  
  def load_historical_events(game_id, replay_id) do
    # Retrieve all events for this game from the event store
    {:ok, events} = EventStore.read_stream_forward(game_id)
    
    # Process each event through PubSub to rebuild the game
    for event <- events do
      Phoenix.PubSub.broadcast(
        GameBot.PubSub,
        "game:#{game_id}",
        {:event, event}
      )
    end
  end
end
```

## Integration with the UI

### Stats Display

```elixir
defmodule GameBotWeb.StatsLive do
  use GameBotWeb, :live_view
  alias GameBot.Stats.Storage
  
  def mount(_params, _session, socket) do
    # Get initial stats
    stats = Storage.get_latest_stats()
    
    # Subscribe to stats updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(GameBot.PubSub, "stats:updates")
    end
    
    {:ok, assign(socket, stats: stats)}
  end
  
  def handle_info({:stats_updated, new_stats}, socket) do
    {:noreply, assign(socket, stats: new_stats)}
  end
  
  # ...implementation
end
```

### Replay Controls

```elixir
defmodule GameBotWeb.ReplayLive do
  use GameBotWeb, :live_view
  alias GameBot.Replay.Session
  alias GameBot.Replay.EventProcessor
  
  def mount(%{"game_id" => game_id}, _session, socket) do
    # Create a new replay session
    {:ok, replay_id} = Session.create_replay(game_id)
    
    {:ok, assign(socket, 
      game_id: game_id,
      replay_id: replay_id,
      current_event: nil,
      position: 0
    )}
  end
  
  def handle_event("next", _params, socket) do
    {:ok, event} = EventProcessor.advance(socket.assigns.replay_id)
    {:noreply, assign(socket, current_event: event, position: socket.assigns.position + 1)}
  end
  
  def handle_event("previous", _params, socket) do
    {:ok, event} = EventProcessor.rewind(socket.assigns.replay_id)
    {:noreply, assign(socket, current_event: event, position: socket.assigns.position - 1)}
  end
  
  def handle_event("jump", %{"position" => position}, socket) do
    {:ok, event} = EventProcessor.jump_to(socket.assigns.replay_id, String.to_integer(position))
    {:noreply, assign(socket, current_event: event, position: position)}
  end
  
  # ...implementation
end
```

## Best Practices

### 1. Event Type Granularity

For stats collection, subscribe to specific event types rather than all game events:

✅ DO:
```elixir
use GameBot.Domain.Events.Handler, 
  interests: ["event_type:game_completed", "event_type:round_completed"]
```

❌ DON'T:
```elixir
Phoenix.PubSub.subscribe(GameBot.PubSub, "game:#{game_id}")
```

### 2. Error Handling

Always implement proper error handling in stats and replay handlers:

```elixir
def handle_event(event) do
  try do
    # Process event
    :ok
  rescue
    e ->
      Logger.error("Failed to process event: #{inspect(e)}")
      # Continue processing (don't crash the handler)
      :ok
  end
end
```

### 3. Batching for Performance

For high-volume stats processing, consider batching:

```elixir
defmodule GameBot.Stats.BatchProcessor do
  use GenServer
  
  def init(_) do
    # Start with an empty batch
    schedule_flush()
    {:ok, %{batch: []}}
  end
  
  def handle_info({:event, event}, %{batch: batch} = state) do
    # Add to batch
    {:noreply, %{state | batch: [event | batch]}}
  end
  
  def handle_info(:flush_batch, %{batch: batch} = state) do
    # Process the batch if not empty
    unless Enum.empty?(batch) do
      GameBot.Stats.Storage.store_batch(batch)
    end
    
    # Schedule next flush
    schedule_flush()
    {:noreply, %{state | batch: []}}
  end
  
  defp schedule_flush do
    Process.send_after(self(), :flush_batch, 5_000) # Flush every 5 seconds
  end
end
```

### 4. Memory Management for Replays

For long games, implement pagination or windowing:

```elixir
defmodule GameBot.Replay.WindowedProcessor do
  # ...
  
  def init(opts) do
    # Set a window size
    {:ok, %{
      game_id: opts[:game_id],
      replay_id: opts[:replay_id],
      events: [],
      window_size: 100,
      total_events: 0
    }}
  end
  
  def handle_call({:jump_to, position}, _from, state) do
    # Load appropriate window if needed
    events = maybe_load_window(state, position)
    
    # Update state with new events if loaded
    new_state = if events, do: %{state | events: events}, else: state
    
    # Return the event at the position
    {:reply, {:ok, get_event_at(new_state, position)}, %{new_state | current_position: position}}
  end
  
  defp maybe_load_window(state, position) do
    window_start = div(position, state.window_size) * state.window_size
    
    if position < window_start || position >= window_start + state.window_size do
      # Load new window from storage
      {:ok, events} = GameBot.Infrastructure.Persistence.EventStore.read_stream_forward(
        state.game_id, 
        from: window_start,
        count: state.window_size
      )
      events
    else
      nil # Keep current window
    end
  end
end
```

## Implementation Strategy

To maximize benefits from the enhanced PubSub system:

1. **Implement PubSub enhancements first**
   - Establishes foundation for efficient event distribution
   - Creates handler patterns for stats and replay systems

2. **Develop Stats System next**
   - Focus on event type subscriptions
   - Create specialized handlers for different stat categories
   - Implement storage and aggregation

3. **Build Replay System last**
   - Leverage both PubSub enhancements and stats for context
   - Implement efficient event handling with windowing
   - Create interactive replay controls

This sequence ensures each system can benefit fully from the capabilities of the enhanced PubSub implementation.

## Conclusion

The enhanced PubSub system provides an ideal foundation for both stats collection and replay functionality. By leveraging event type subscriptions and standardized handler patterns, both systems can be implemented efficiently and reliably. The modular design allows for incremental development and future extension as needed. 