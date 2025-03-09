# Phoenix PubSub Enhancement Plan (Streamlined)

## Introduction

This document outlines a focused plan to enhance the current Phoenix PubSub implementation in the GameBot event system. The plan prioritizes high-value improvements with minimal complexity, while deferring more complex features to an optional phase.

## Current State Assessment

Based on our codebase analysis (specifically `lib/game_bot/domain/events/pipeline.ex`), our event system currently uses Phoenix PubSub in a limited way:

- Events are broadcast only to game-specific channels (`game:#{game_id}`)
- Broadcasting occurs as the final step in the pipeline, after validation, enrichment, persistence, and caching
- No telemetry is currently recorded for broadcasting operations
- All subscribers receive all events for a game, regardless of relevance

## Core Enhancement Goals

1. Implement focused topic-based subscriptions (game ID and event type)
2. Create standardized subscription patterns
3. Add basic error handling for event consumers
4. Add telemetry for broadcast operations

## Implementation Status

**Status: Completed Phase 1 and Phase 2**

All core components have been implemented according to the plan:

| Component | Status | Comments |
|-----------|--------|----------|
| SubscriptionManager | ✅ Done | Provides helpers for both game and event type subscriptions |
| Broadcaster | ✅ Done | Handles dual-topic broadcasting with telemetry |
| Telemetry Updates | ✅ Done | Added broadcast metrics collection |
| Pipeline Integration | ✅ Done | Uses feature flag for gradual adoption |
| Handler Behavior | ✅ Done | Includes error recovery and topic resubscription |
| Tests | ✅ Done | Unit and integration tests implemented |
| Documentation | ✅ Done | User guide and examples provided |

**Feature Status: Disabled by Default**

The enhanced PubSub system is currently disabled by default via configuration. To enable:

```elixir
# In config/config.exs
config :game_bot, :event_system,
  use_enhanced_pubsub: true  # Change from 'false' to 'true'
```

**Next Steps:**
- Run comprehensive integration tests in non-production environments
- Enable the enhanced PubSub system in staging
- Monitor performance and error rates
- Roll out to production after successful staging validation

## Implementation Checklist (Original Plan)

### Phase 1: Core Subscription Enhancements (2-3 days)

- [x] **1.1 Create Simple `SubscriptionManager` Module**
  - [x] Create `lib/game_bot/domain/events/subscription_manager.ex`
  - [x] Implement core subscription helper functions (game and event type)
  - [x] Add documentation for subscription patterns

- [x] **1.2 Create Basic Broadcaster Module**
  - [x] Create `lib/game_bot/domain/events/broadcaster.ex`
  - [x] Implement dual-topic broadcasting (game ID and event type)
  - [x] Add telemetry integration
  - [x] Ensure backward compatibility

- [x] **1.3 Update Telemetry Module**
  - [x] Add `record_event_broadcast/3` function to `lib/game_bot/domain/events/telemetry.ex`
  - [x] Update telemetry handler to include broadcast events

### Phase 2: Integration and Testing (2-3 days)

- [x] **2.1 Integrate with Pipeline**
  - [x] Update `lib/game_bot/domain/events/pipeline.ex` to use new Broadcaster
  - [x] Add feature flag for gradual adoption
  - [x] Ensure backward compatibility

- [x] **2.2 Create Simple Handler Pattern**
  - [x] Create `lib/game_bot/domain/events/handler.ex` with core behavior
  - [x] Implement error handling and recovery mechanisms
  - [x] Create documentation for handler creation

- [x] **2.3 Testing and Documentation**
  - [x] Create unit tests for new components
  - [x] Create integration tests for the pipeline
  - [x] Update documentation with usage examples

## Detailed Implementation

### 1. `SubscriptionManager` Module (Essential)

```elixir
# lib/game_bot/domain/events/subscription_manager.ex
defmodule GameBot.Domain.Events.SubscriptionManager do
  @moduledoc """
  Manages subscriptions to event topics with standardized patterns.
  """

  alias Phoenix.PubSub

  @pubsub GameBot.PubSub

  # Game-specific subscriptions
  def subscribe_to_game(game_id) do
    PubSub.subscribe(@pubsub, "game:#{game_id}")
  end

  # Event type subscriptions
  def subscribe_to_event_type(type) do
    PubSub.subscribe(@pubsub, "event_type:#{type}")
  end

  # Unsubscribe from any topic
  def unsubscribe(topic) do
    PubSub.unsubscribe(@pubsub, topic)
  end
end
```

### 2. Simple Broadcaster (Essential)

```elixir
# lib/game_bot/domain/events/broadcaster.ex
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
```

### 3. Updated Telemetry Module (Essential)

```elixir
# Add to lib/game_bot/domain/events/telemetry.ex
@doc """
Records an event broadcast operation.
"""
@spec record_event_broadcast(String.t(), [String.t()], integer()) :: :ok
def record_event_broadcast(event_type, topics, duration) do
  :telemetry.execute(
    @event_prefix ++ [:broadcast],
    %{
      duration: duration,
      topic_count: length(topics)
    },
    %{
      event_type: event_type,
      topics: topics,
      timestamp: DateTime.utc_now()
    }
  )
end

# Update attach_handlers to include broadcast events
@spec attach_handlers() :: :ok
def attach_handlers do
  :telemetry.attach_many(
    "game-bot-event-handlers",
    [
      @event_prefix ++ [:processed],
      @event_prefix ++ [:validated],
      @event_prefix ++ [:serialized],
      @event_prefix ++ [:broadcast],
      @event_prefix ++ [:error]
    ],
    &handle_event/4,
    nil
  )
end
```

### 4. Pipeline Integration (Essential)

```elixir
# Update lib/game_bot/domain/events/pipeline.ex
@doc """
Broadcasts an event to subscribers through enhanced channels.
"""
@spec broadcast({:ok, struct()} | {:error, term()}) :: {:ok, struct()} | {:error, term()}
def broadcast({:ok, event} = result) do
  if Application.get_env(:game_bot, :use_enhanced_pubsub, false) do
    # Use the new enhanced broadcaster
    GameBot.Domain.Events.Broadcaster.broadcast_event(event)
  else
    # Legacy broadcasting (unchanged)
    Phoenix.PubSub.broadcast(
      GameBot.PubSub,
      "game:#{event.game_id}",
      {:event, event}
    )
    result
  end
end
def broadcast(error), do: error
```

### 5. Basic Handler Framework (Essential)

```elixir
# lib/game_bot/domain/events/handler.ex
defmodule GameBot.Domain.Events.Handler do
  @moduledoc """
  Basic behaviour for creating event handlers with error handling.
  """
  
  @callback handle_event(event :: struct()) :: :ok | {:error, term()}
  @callback interests() :: [String.t()]
  
  defmacro __using__(opts) do
    quote do
      use GenServer
      require Logger
      
      @behaviour GameBot.Domain.Events.Handler
      
      # Default implementation of interests
      @impl true
      def interests do
        unquote(opts[:interests] || [])
      end
      
      def start_link(args \\ []) do
        GenServer.start_link(__MODULE__, args, name: __MODULE__)
      end
      
      @impl true
      def init(args) do
        # Subscribe to all interests
        subscribe_to_interests()
        {:ok, Map.new(args)}
      end
      
      @impl true
      def handle_info({:event, event}, state) do
        try do
          case handle_event(event) do
            :ok -> {:noreply, state}
            {:error, reason} ->
              Logger.error("Error handling event #{inspect(event.__struct__)}: #{inspect(reason)}")
              {:noreply, state}
          end
        rescue
          e ->
            Logger.error("Exception while handling event: #{Exception.message(e)}")
            # Resubscribe to topics
            subscribe_to_interests()
            {:noreply, state}
        end
      end
      
      defp subscribe_to_interests do
        alias GameBot.Domain.Events.SubscriptionManager
        
        # Subscribe to each interest
        for interest <- interests() do
          case interest do
            "game:" <> game_id -> SubscriptionManager.subscribe_to_game(game_id)
            "event_type:" <> type -> SubscriptionManager.subscribe_to_event_type(type)
            _ -> Phoenix.PubSub.subscribe(GameBot.PubSub, interest)
          end
        end
      end
      
      # Allow overriding of handle_info
      defoverridable handle_info: 2
    end
  end
end
```

### 6. Configuration Updates (Essential)

```elixir
# Add to config/config.exs
# Event system configuration
config :game_bot, :event_system,
  use_enhanced_pubsub: false  # Start with this disabled, enable after testing
```

## Migration Strategy

To ensure a smooth transition to the enhanced PubSub system:

1. **Implement Without Breaking Changes**
   - Deploy all new modules with feature flag disabled (`use_enhanced_pubsub: false`)
   - Run comprehensive tests to ensure original functionality works

2. **Incremental Adoption**
   - Enable enhanced broadcasting with feature flag for non-critical environments
   - Monitor performance and ensure no regressions
   - Gradually enable in production once validated

3. **Update Documentation**
   - Create clear examples of how to use the new subscription patterns
   - Document best practices for event handling

## Testing Strategy

1. **Unit Tests**
   - Test each new module in isolation
   - Verify topics are correctly generated
   - Test error handling in handlers

2. **Integration Tests**
   - Test the full event pipeline with enhanced broadcasting
   - Verify both topics receive events
   - Test backward compatibility

## Benefits of Implementation

- **Focused Events**: Components only receive events they care about
- **Maintainability**: Standardized subscription patterns
- **Reliability**: Better error handling and recovery
- **Observability**: Metrics for broadcast operations

## Future Optional Upgrades

These features may be implemented in the future if specific needs arise:

### 1. Additional Topic Patterns (Optional)

```elixir
# Extension to SubscriptionManager for guild and player topics
def subscribe_to_guild(guild_id) do
  PubSub.subscribe(@pubsub, "guild:#{guild_id}")
end

def subscribe_to_player(player_id) do
  PubSub.subscribe(@pubsub, "player:#{player_id}")
end
```

### 2. Handler Supervisor (Optional)

```elixir
# lib/game_bot/domain/events/handler_supervisor.ex
defmodule GameBot.Domain.Events.HandlerSupervisor do
  @moduledoc """
  Supervisor for event handlers.
  """
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = get_handler_children()
    
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  # Get handler children from config or use defaults
  defp get_handler_children do
    Application.get_env(:game_bot, :event_handlers, [])
    |> Enum.map(fn
      {module, args} -> {module, args}
      module when is_atom(module) -> {module, []}
    end)
  end
end
```

### 3. Event Transformation System (Optional)

This would enable transforming events into different formats for specific consumers:

```elixir
defmodule GameBot.Domain.Events.Transformer do
  @callback transform(event :: struct()) :: map()
  
  # ...transformation logic
end
```

### 4. Advanced Guild and Player Topic Extraction (Optional)

```elixir
# Add to Broadcaster
defp with_guild_topic(topics, event) do
  guild_id = cond do
    Map.has_key?(event, :guild_id) -> 
      event.guild_id
    Map.has_key?(event, :metadata) && 
    (Map.has_key?(event.metadata, :guild_id) || Map.has_key?(event.metadata, "guild_id")) ->
      event.metadata[:guild_id] || event.metadata["guild_id"]
    true -> 
      nil
  end
  
  if guild_id, do: ["guild:#{guild_id}" | topics], else: topics
end
``` 