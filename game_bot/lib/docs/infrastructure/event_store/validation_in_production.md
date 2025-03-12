# Event Validation in Production Systems

This document provides guidance for handling event validation in production environments, focusing on robustness, performance, and error handling.

## Introduction

While validation is crucial for maintaining data integrity, it requires special consideration in production environments where performance, backward compatibility, and error handling become critical concerns.

## Validation Strategies

### Strict vs. Lenient Validation

Consider different validation strategies for different contexts:

1. **Strict Validation (Default)**
   - Reject any events that don't meet validation rules
   - Suitable for new development, testing, and critical operations
   - Prevents invalid data from entering the system

2. **Lenient Validation**
   - Accept events with minor validation issues
   - Log warnings instead of rejecting events
   - Suitable for high-volume, non-critical operations

3. **Versioned Validation**
   - Apply different validation rules based on event version
   - Allow older event formats alongside newer ones
   - Suitable for systems with multiple versions in production

### Configuration

Make validation behavior configurable:

```elixir
# In config/prod.exs
config :game_bot, GameBot.Infrastructure.Persistence.EventStore,
  validation: [
    enabled: true,                 # Enable/disable validation globally
    mode: :strict,                 # :strict, :lenient, or :versioned
    log_validation_errors: true,   # Log all validation errors
    bypass_validation_for: []      # List of event types to skip validation
  ]
```

## Error Handling

### Graceful Degradation

Design systems to gracefully handle validation failures:

```elixir
def process_event(event) do
  case Serializer.serialize(event) do
    {:ok, serialized} ->
      # Process normally
      EventStore.append(serialized)
      
    {:error, validation_error} ->
      # Log the error
      Logger.error("Validation failed: #{validation_error}")
      
      # Take appropriate action based on context
      case determine_criticality(event) do
        :critical ->
          # For critical events, alert and retry with manual intervention
          alert_operations_team(event, validation_error)
          {:error, validation_error}
          
        :non_critical ->
          # For non-critical events, store in error queue for later processing
          ErrorQueue.enqueue(event, validation_error)
          {:error, :queued_for_review}
      end
  end
end
```

### Error Queues

Implement error queues to handle invalid events:

```elixir
defmodule GameBot.Infrastructure.Persistence.ErrorQueue do
  @moduledoc """
  Stores events that failed validation for later review and processing.
  """
  
  def enqueue(event, error_reason) do
    # Store the invalid event with error information
    %{
      event: event,
      error: error_reason,
      timestamp: DateTime.utc_now(),
      status: :pending
    }
    |> store_in_error_queue()
  end
  
  def list_pending_errors do
    # Retrieve pending errors for review
  end
  
  def resolve_error(error_id, action) do
    # Mark error as resolved with specific action taken
  end
  
  # Private functions
  defp store_in_error_queue(error_entry) do
    # Store in database or other persistent storage
  end
end
```

### Monitoring and Alerts

Set up monitoring for validation failures:

```elixir
# In your monitoring setup
defmodule GameBot.Monitoring do
  def setup_validation_monitoring do
    # Set up metrics for validation failures
    :telemetry.attach(
      "validation-failures",
      [:game_bot, :event_store, :validation, :failure],
      &handle_validation_failure/4,
      nil
    )
  end
  
  def handle_validation_failure(_event, %{count: count}, metadata, _config) do
    # Record metrics
    record_metric("validation.failures", count)
    
    # Alert if threshold exceeded
    if count > alert_threshold() do
      send_alert("High validation failure rate detected")
    end
  end
end
```

## Performance Optimization

### Selective Validation

Apply validation selectively to balance security and performance:

```elixir
defmodule GameBot.Infrastructure.Persistence.EventStore do
  # Determine whether to validate based on event type and context
  defp should_validate?(event, context) do
    cond do
      # Skip validation for bulk historical imports
      context.bulk_import? ->
        false
        
      # Skip validation for specific non-critical event types in high-throughput scenarios
      high_throughput_mode?() and non_critical_event?(event) ->
        false
        
      # Skip validation for allowlisted event types
      event_type = event.__struct__
      event_type in bypass_validation_event_types() ->
        false
        
      # Otherwise validate
      true ->
        true
    end
  end
end
```

### Caching Validation Results

For repeated validations of similar events, consider caching validation results:

```elixir
defmodule GameBot.Domain.Events.ValidationCache do
  @moduledoc """
  Caches validation results to improve performance.
  """
  
  use GenServer
  
  # Cache validation results with TTL
  def cache_result(event_type, event_hash, result) do
    GenServer.cast(__MODULE__, {:cache, event_type, event_hash, result})
  end
  
  # Check if we have a cached result
  def get_cached_result(event_type, event_hash) do
    GenServer.call(__MODULE__, {:get, event_type, event_hash})
  end
  
  # Clear cache entries
  def clear_cache do
    GenServer.cast(__MODULE__, :clear)
  end
  
  # GenServer implementation
  # ...
end
```

### Batch Validation

For bulk operations, validate events in batches:

```elixir
defmodule GameBot.Domain.Events.BatchValidator do
  @moduledoc """
  Validates batches of events efficiently.
  """
  
  alias GameBot.Domain.Events.EventValidator
  
  @spec validate_batch(list(struct()), opts :: keyword()) :: 
    {:ok, list(struct())} | {:error, list({struct(), String.t()})}
  def validate_batch(events, opts \\ []) do
    # Determine validation mode
    validation_mode = Keyword.get(opts, :mode, :strict)
    
    # Validate all events
    results = 
      events
      |> Enum.map(&{&1, EventValidator.validate(&1)})
    
    case validation_mode do
      :strict ->
        # In strict mode, fail if any event is invalid
        if Enum.all?(results, fn {_, result} -> result == :ok end) do
          {:ok, events}
        else
          errors = Enum.filter(results, fn {_, result} -> result != :ok end)
                  |> Enum.map(fn {event, {:error, reason}} -> {event, reason} end)
          {:error, errors}
        end
        
      :lenient ->
        # In lenient mode, filter out invalid events and continue
        valid_events = Enum.filter(results, fn {_, result} -> result == :ok end)
                      |> Enum.map(fn {event, _} -> event end)
        invalid = Enum.filter(results, fn {_, result} -> result != :ok end)
                |> Enum.map(fn {event, {:error, reason}} -> {event, reason} end)
        
        # Log invalid events
        Enum.each(invalid, fn {event, reason} ->
          Logger.warning("Filtered invalid event: #{inspect(event.__struct__)} - #{reason}")
        end)
        
        {:ok, valid_events}
    end
  end
end
```

## Backward Compatibility

### Handling Legacy Events

Support backward compatibility for legacy events:

```elixir
defimpl GameBot.Domain.Events.EventValidator, for: GameBot.Domain.Events.GameEvents.GameStarted.V1 do
  alias GameBot.Domain.Events.EventValidatorHelpers, as: Helpers

  def validate(event) do
    # Apply legacy validation rules
    with :ok <- Helpers.validate_required(event, [:id, :timestamp, :game_id]),
         :ok <- Helpers.validate_id(event.id, :id),
         :ok <- Helpers.validate_id(event.game_id, :game_id),
         :ok <- Helpers.validate_datetime(event.timestamp, :timestamp) do
      :ok
    end
  end
end
```

### Event Migration

Implement event migration for handling legacy events:

```elixir
defmodule GameBot.Domain.Events.EventMigrator do
  @moduledoc """
  Migrates events between different versions.
  """
  
  def migrate(event) do
    # Detect event version
    event_module = event.__struct__
    
    case event_module do
      GameBot.Domain.Events.GameEvents.GameStarted.V1 ->
        migrate_game_started_v1_to_v2(event)
        
      _ ->
        # If no migration needed, return as is
        event
    end
  end
  
  defp migrate_game_started_v1_to_v2(v1_event) do
    # Create a V2 event from V1 data
    %GameBot.Domain.Events.GameEvents.GameStarted.V2{
      id: v1_event.id,
      timestamp: v1_event.timestamp,
      game_id: v1_event.game_id,
      round_number: v1_event.round_number || 1,  # Default for missing field
      teams: migrate_teams_format(v1_event.teams)
    }
  end
  
  defp migrate_teams_format(old_teams) do
    # Convert old team format to new format
    Enum.map(old_teams, fn old_team ->
      %{
        id: old_team.id,
        name: old_team.name,
        score: old_team.score || 0,  # Default for missing field
        members: []  # New field in V2
      }
    end)
  end
end
```

## Testing Validation in Production

### Canary Validation

Implement canary validation to test new validation rules in production:

```elixir
defmodule GameBot.Infrastructure.Persistence.ValidationCanary do
  @moduledoc """
  Tests new validation rules on production events without affecting normal operation.
  """
  
  def check_event(event) do
    # Apply the new validation rules
    result = apply_new_validation_rules(event)
    
    # Record the result for analysis
    record_canary_result(event, result)
    
    # Always return :ok to not affect production
    :ok
  end
  
  defp apply_new_validation_rules(event) do
    # Try the new validation rules that aren't in production yet
    try do
      NewValidatorModule.validate(event)
    rescue
      e -> {:error, Exception.message(e)}
    end
  end
  
  defp record_canary_result(event, result) do
    # Store the result for analysis
    Logger.debug("Canary validation: #{inspect(event.__struct__)} - #{inspect(result)}")
    
    # Could also store in database, metrics system, etc.
  end
end
```

### Shadow Mode

Run new validation logic in shadow mode:

```elixir
defmodule GameBot.Infrastructure.Persistence.EventStore.Serializer do
  # In your serializer
  def serialize(event, opts \\ []) do
    # Current validation
    validation_result = 
      if Keyword.get(opts, :validate, true) do
        GameBot.Domain.Events.EventValidator.validate(event)
      else
        :ok
      end
    
    # Shadow validation (new rules under test)
    if Application.get_env(:game_bot, :shadow_validation_enabled, false) do
      Task.start(fn ->
        try do
          # Apply new validation rules without affecting result
          shadow_result = NewValidatorModule.validate(event)
          record_shadow_validation_result(event, shadow_result)
        rescue
          e -> record_shadow_validation_error(event, e)
        end
      end)
    end
    
    # Continue with normal operation based on current validation
    case validation_result do
      :ok -> 
        # Proceed with serialization
        # ...
      error -> 
        error
    end
  end
end
```

## Logging and Auditing

### Structured Validation Logs

Implement structured logging for validation errors:

```elixir
defmodule GameBot.Infrastructure.Logging.ValidationLogger do
  require Logger
  
  def log_validation_error(event, error_reason) do
    Logger.error(
      "Event validation failed",
      event_type: event.__struct__,
      event_id: event.id,
      error: error_reason,
      metadata: %{
        game_id: event.game_id,
        timestamp: event.timestamp
      }
    )
  end
  
  def log_validation_warning(event, warning_reason) do
    Logger.warning(
      "Event validation warning",
      event_type: event.__struct__,
      event_id: event.id,
      warning: warning_reason
    )
  end
end
```

### Audit Trail

Maintain an audit trail of validation exceptions:

```elixir
defmodule GameBot.Infrastructure.Persistence.ValidationAudit do
  @moduledoc """
  Records an audit trail of validation exceptions.
  """
  
  alias GameBot.Infrastructure.Persistence.Repo
  
  def record_exception(event, error, context) do
    %GameBot.Infrastructure.Persistence.Schemas.ValidationException{
      event_type: event.__struct__ |> to_string(),
      event_id: event.id,
      error_message: error,
      context: context,
      timestamp: DateTime.utc_now(),
      resolved: false
    }
    |> Repo.insert()
  end
  
  def list_unresolved_exceptions do
    # Query unresolved exceptions
  end
  
  def mark_as_resolved(exception_id, resolution_notes) do
    # Mark an exception as resolved
  end
end
```

## Conclusion

Effective event validation in production requires a balance between strictness and flexibility. By implementing proper error handling, performance optimization, and backward compatibility measures, you can ensure data integrity without sacrificing system reliability or performance.

Key takeaways:

1. **Configure validation behavior** based on environment and context
2. **Implement graceful error handling** for validation failures
3. **Optimize validation performance** in high-throughput scenarios
4. **Maintain backward compatibility** for legacy events
5. **Test validation changes** safely in production
6. **Monitor and log validation issues** for continuous improvement

Following these practices will help you maintain a robust validation system that supports your production environment's reliability and performance requirements. 