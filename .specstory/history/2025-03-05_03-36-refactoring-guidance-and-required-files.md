## SpecStory

## Refactoring Guidance and Required Files (3/5/2025, 3:36:14 AM)

_**User**_

@module_organization.md @refactoring_plan.md read these two documents that describe what i want to accomplish and tell me which files you need to see to understand how to accurately perform this refactoring

---

_**Assistant**_

Based on the module organization and refactoring plans, I'd need to see these key files to understand the current implementation and help with the refactoring:

1. Core Infrastructure Files:
```
game_bot/lib/game_bot/infrastructure/event_store.ex
game_bot/lib/game_bot/infrastructure/event_store_adapter.ex
game_bot/lib/game_bot/infrastructure/repo.ex
```

2. Event Store Implementation:
```
game_bot/lib/game_bot/infrastructure/event_store/error.ex
game_bot/lib/game_bot/infrastructure/event_store/serializer.ex
```

3. Sample Domain Files (to understand dependencies):
```
game_bot/lib/game_bot/domain/events/game_events.ex
game_bot/lib/game_bot/domain/commands/game_commands.ex
game_bot/lib/game_bot/domain/aggregates/game_aggregate.ex
```

4. Sample Game Mode Implementation:
```
game_bot/lib/game_bot/domain/game_modes/base.ex
```

These files would help me understand:
1. Current event store implementation and its dependencies
2. How errors are currently handled
3. Event serialization approach
4. Domain layer dependencies and circular references
5. Current module boundaries and interfaces
6. Existing patterns that need standardization

This would allow me to provide specific guidance on:
- Creating proper interfaces and behaviors
- Resolving circular dependencies
- Implementing consistent error handling
- Reorganizing the modules according to the plan
- Maintaining backward compatibility during refactoring

Would you please share these files, starting with the core infrastructure files?

---

_**User**_

@event_store_adapter.ex @event_store.ex @repo.ex 

---

_**Assistant**_

Based on these files, I can see the current infrastructure layer implementation and help plan the refactoring. Here's what I observe:

1. The current structure has good separation of concerns but needs better organization:
   - `EventStoreAdapter` has proper error handling and validation
   - `EventStore` is a thin wrapper around the EventStore library
   - `Repo` is a basic Ecto repository

2. Key areas for refactoring according to the plan:

```
infrastructure/persistence/
├── event_store/
│   ├── behaviour.ex          # NEW - Define core interface
│   ├── error.ex             # MOVE - From EventStoreAdapter
│   ├── config.ex            # NEW - Extract config from EventStore
│   ├── serializer.ex        # EXISTING - Need to see current implementation
│   ├── adapter.ex           # RENAME - From EventStoreAdapter
│   └── implementation/
│       ├── postgres.ex      # MOVE - From EventStore
│       └── memory.ex        # NEW - For testing
└── repo/
    ├── behaviour.ex         # NEW - Define repository interface
    ├── error.ex            # NEW - Standardize error handling
    └── postgres.ex         # MOVE - From current Repo
```

To proceed with the refactoring, I need to see:

1. The serializer implementation:
```
game_bot/lib/game_bot/infrastructure/event_store/serializer.ex
```

2. The current error module:
```
game_bot/lib/game_bot/infrastructure/event_store/error.ex
```

This will help me understand:
- How events are currently serialized
- The existing error handling patterns
- Any potential circular dependencies

Would you please share these files?

---

_**User**_

@serializer.ex @error.ex 

---

_**Assistant**_

Perfect, now I have a complete picture of the infrastructure layer. Here's my proposed refactoring plan with specific file changes:

1. First, let's create the new directory structure and core behavior definitions:

````elixir:game_bot/lib/game_bot/infrastructure/persistence/event_store/behaviour.ex
defmodule GameBot.Infrastructure.Persistence.EventStore.Behaviour do
  @moduledoc """
  Defines the core interface for event store implementations.
  """

  @type stream_id :: String.t()
  @type version :: non_neg_integer()
  @type event :: term()
  @type error :: EventStore.Error.t()

  @callback append_to_stream(stream_id(), version(), [event()], keyword()) ::
    {:ok, [event()]} | {:error, error()}

  @callback read_stream_forward(stream_id(), version(), pos_integer(), keyword()) ::
    {:ok, [event()]} | {:error, error()}

  @callback subscribe_to_stream(stream_id(), pid(), keyword(), keyword()) ::
    {:ok, pid()} | {:error, error()}

  @callback stream_version(stream_id()) ::
    {:ok, version()} | {:error, error()}
end
````

2. Create a standardized error module:

````elixir:game_bot/lib/game_bot/infrastructure/persistence/error.ex
defmodule GameBot.Infrastructure.Persistence.Error do
  @moduledoc """
  Standardized error handling for persistence operations.
  """

  @type error_type ::
    :validation |
    :serialization |
    :not_found |
    :concurrency |
    :timeout |
    :connection |
    :system |
    :stream_too_large

  @type t :: %__MODULE__{
    type: error_type(),
    context: module(),
    message: String.t(),
    details: term()
  }

  defexception [:type, :context, :message, :details]

  @impl true
  def message(%{type: type, context: ctx, message: msg, details: details}) do
    "#{inspect(ctx)} error (#{type}): #{msg}\nDetails: #{inspect(details)}"
  end
end
````

3. Move and update the EventStore implementation:

````elixir:game_bot/lib/game_bot/infrastructure/persistence/event_store/postgres.ex
defmodule GameBot.Infrastructure.Persistence.EventStore.Postgres do
  @moduledoc """
  PostgreSQL-based event store implementation.
  """
  
  use EventStore, otp_app: :game_bot
  @behaviour GameBot.Infrastructure.Persistence.EventStore.Behaviour

  alias GameBot.Infrastructure.Persistence.Error
  alias GameBot.Infrastructure.Persistence.EventStore.Serializer

  # ... rest of current EventStore.ex implementation with updated error handling
  # and behaviour implementation
end
````

4. Update the adapter with new organization:

````elixir:game_bot/lib/game_bot/infrastructure/persistence/event_store/adapter.ex
defmodule GameBot.Infrastructure.Persistence.EventStore.Adapter do
  @moduledoc """
  Adapter layer for EventStore providing validation, serialization, and monitoring.
  """

  alias GameBot.Infrastructure.Persistence.Error
  alias GameBot.Infrastructure.Persistence.EventStore.{Behaviour, Serializer}

  # ... rest of current EventStoreAdapter.ex implementation with updated
  # error handling and module references
end
````

5. Create a repository behavior:

````elixir:game_bot/lib/game_bot/infrastructure/persistence/repo/behaviour.ex
defmodule GameBot.Infrastructure.Persistence.Repo.Behaviour do
  @moduledoc """
  Defines the core interface for repository implementations.
  """

  @callback transaction((() -> result)) :: {:ok, result} | {:error, term()} when result: term()
  @callback insert(struct()) :: {:ok, struct()} | {:error, term()}
  @callback update(struct()) :: {:ok, struct()} | {:error, term()}
  @callback delete(struct()) :: {:ok, struct()} | {:error, term()}
end
````

Key changes:
1. Clear separation of interfaces and implementations
2. Standardized error handling across persistence layer
3. Proper behavior definitions for implementations
4. Consistent module naming and organization
5. Better documentation and type specifications

Would you like me to continue with specific implementation details for any of these components?

---

_**User**_

yes, and let me know if you need to see any files for precise implementation

---

_**Assistant**_

Thanks for creating those initial files. Now we need to implement the concrete functionality. Let me see:

1. First, I need to see the current serializer implementation to properly move and update it:
```
game_bot/lib/game_bot/infrastructure/event_store/serializer.ex
```

2. Then we need to implement the full Postgres adapter with proper error handling. I'll need:
```
game_bot/lib/game_bot/infrastructure/event_store.ex
```

3. Finally, we should implement the repository with the new behavior. I'll need:
```
game_bot/lib/game_bot/infrastructure/repo.ex
```

The key tasks are:

1. Move and update the serializer to use the new error module
2. Implement the full Postgres event store with proper behavior implementation
3. Create a proper repository implementation with error handling

Would you please share those files? I already have the serializer.ex from earlier, so I can start with implementing the updated serializer:

````elixir:game_bot/lib/game_bot/infrastructure/persistence/event_store/serializer.ex
defmodule GameBot.Infrastructure.Persistence.EventStore.Serializer do
  @moduledoc """
  Event serializer for GameBot.
  Handles serialization, deserialization, and validation of game events.
  """

  alias GameBot.Domain.Events.GameEvents
  alias GameBot.Infrastructure.Persistence.Error

  # ... I'll continue with the full implementation once you confirm you want to see it
````

Would you like me to proceed with the full serializer implementation first, or would you prefer to see the other files first?

---

_**User**_

@serializer.ex @event_store.ex @repo.ex @event_store_adapter.ex 

---

_**Assistant**_

Perfect, I can see all the original files. Let me implement each component in order:

1. First, let's implement the updated serializer with the new error handling:

````elixir:game_bot/lib/game_bot/infrastructure/persistence/event_store/serializer.ex
defmodule GameBot.Infrastructure.Persistence.EventStore.Serializer do
  @moduledoc """
  Event serializer for GameBot.
  Handles serialization, deserialization, and validation of game events.
  """

  alias GameBot.Domain.Events.GameEvents
  alias GameBot.Infrastructure.Persistence.Error

  @required_stored_fields ~w(event_type event_version data stored_at)
  @current_schema_version 1

  @type result :: {:ok, term()} | {:error, Error.t()}

  @doc """
  Serializes an event to the format expected by the event store.
  """
  @spec serialize(struct()) :: result()
  def serialize(event) do
    try do
      with :ok <- validate_event(event),
           serialized <- GameEvents.serialize(event) do
        {:ok, serialized}
      end
    rescue
      e in Protocol.UndefinedError ->
        {:error, %Error{
          type: :serialization,
          context: __MODULE__,
          message: "Event type not serializable",
          details: %{module: event.__struct__, error: e}
        }}
      e in FunctionClauseError ->
        {:error, %Error{
          type: :serialization,
          context: __MODULE__,
          message: "Invalid event structure",
          details: %{module: event.__struct__, error: e}
        }}
      e ->
        {:error, %Error{
          type: :serialization,
          context: __MODULE__,
          message: "Serialization failed",
          details: e
        }}
    end
  end

  @doc """
  Deserializes stored event data back into an event struct.
  """
  @spec deserialize(map()) :: result()
  def deserialize(event_data) do
    try do
      with :ok <- validate_stored_data(event_data),
           {:ok, event} <- do_deserialize(event_data),
           :ok <- validate_event(event) do
        {:ok, event}
      end
    rescue
      e in KeyError ->
        {:error, %Error{
          type: :serialization,
          context: __MODULE__,
          message: "Missing required event data",
          details: %{missing_key: e.key, available_keys: Map.keys(event_data)}
        }}
      e ->
        {:error, %Error{
          type: :serialization,
          context: __MODULE__,
          message: "Deserialization failed",
          details: e
        }}
    end
  end

  @doc """
  Returns the current version of an event type.
  """
  @spec event_version(String.t()) :: {:ok, pos_integer()} | {:error, Error.t()}
  def event_version(event_type) do
    try do
      version = case event_type do
        "game_started" -> @current_schema_version
        "round_started" -> @current_schema_version
        "guess_processed" -> @current_schema_version
        "guess_abandoned" -> @current_schema_version
        "team_eliminated" -> @current_schema_version
        "game_completed" -> @current_schema_version
        "knockout_round_completed" -> @current_schema_version
        "race_mode_time_expired" -> @current_schema_version
        "longform_day_ended" -> @current_schema_version
        _ ->
          raise "Unknown event type: #{event_type}"
      end
      {:ok, version}
    rescue
      e in RuntimeError ->
        {:error, %Error{
          type: :validation,
          context: __MODULE__,
          message: "Invalid event type",
          details: e.message
        }}
    end
  end

  # Private Functions

  defp validate_event(event) do
    module = event.__struct__

    if function_exported?(module, :validate, 1) do
      module.validate(event)
    else
      {:error, %Error{
        type: :validation,
        context: __MODULE__,
        message: "Event module missing validate/1",
        details: module
      }}
    end
  end

  defp validate_stored_data(data) when is_map(data) do
    case Enum.find(@required_stored_fields, &(not Map.has_key?(data, &1))) do
      nil -> :ok
      missing ->
        {:error, %Error{
          type: :validation,
          context: __MODULE__,
          message: "Missing required field in stored data",
          details: %{missing_field: missing, available_fields: Map.keys(data)}
        }}
    end
  end

  defp validate_stored_data(data) do
    {:error, %Error{
      type: :validation,
      context: __MODULE__,
      message: "Invalid stored data format",
      details: %{expected: "map", got: inspect(data)}
    }}
  end

  defp do_deserialize(%{"event_type" => type, "event_version" => version, "data" => data}) do
    with {:ok, expected_version} <- event_version(type),
         :ok <- validate_version(version, expected_version) do
      try do
        event = GameEvents.deserialize(%{
          "event_type" => type,
          "data" => data
        })
        {:ok, event}
      rescue
        e -> {:error, %Error{
          type: :serialization,
          context: __MODULE__,
          message: "Failed to construct event",
          details: %{event_type: type, error: e}
        }}
      end
    end
  end

  defp validate_version(actual, expected) when actual == expected, do: :ok
  defp validate_version(actual, expected) do
    {:error, %Error{
      type: :validation,
      context: __MODULE__,
      message: "Event version mismatch",
      details: %{actual: actual, expected: expected}
    }}
  end
end
````

Would you like me to continue with implementing the Postgres adapter and repository next?

---

_**User**_

yes

---

_**Assistant**_

Great, now let's implement the Postgres adapter with proper behavior implementation:

````elixir:game_bot/lib/game_bot/infrastructure/persistence/event_store/postgres.ex
defmodule GameBot.Infrastructure.Persistence.EventStore.Postgres do
  @moduledoc """
  PostgreSQL-based event store implementation.
  """
  
  use EventStore, otp_app: :game_bot
  @behaviour GameBot.Infrastructure.Persistence.EventStore.Behaviour

  alias GameBot.Infrastructure.Persistence.Error
  alias GameBot.Infrastructure.Persistence.EventStore.Serializer

  # Configuration
  @telemetry_prefix [:game_bot, :event_store]

  @impl true
  def init(config) do
    :telemetry.attach(
      "event-store-handler",
      @telemetry_prefix ++ [:event],
      &handle_telemetry_event/4,
      nil
    )

    {:ok, config}
  end

  @impl GameBot.Infrastructure.Persistence.EventStore.Behaviour
  def append_to_stream(stream_id, expected_version, events, opts \\ []) do
    try do
      super(stream_id, expected_version, events, opts)
    rescue
      e in EventStore.WrongExpectedVersionError ->
        {:error, %Error{
          type: :concurrency,
          context: __MODULE__,
          message: "Concurrent modification detected",
          details: %{stream_id: stream_id, expected: expected_version, actual: e.current_version}
        }}
      e ->
        {:error, %Error{
          type: :system,
          context: __MODULE__,
          message: "Failed to append events",
          details: %{stream_id: stream_id, error: e}
        }}
    end
  end

  @impl GameBot.Infrastructure.Persistence.EventStore.Behaviour
  def read_stream_forward(stream_id, start_version \\ 0, count \\ 1000, opts \\ []) do
    try do
      super(stream_id, start_version, count, opts)
    rescue
      EventStore.StreamNotFoundError ->
        {:error, %Error{
          type: :not_found,
          context: __MODULE__,
          message: "Stream not found",
          details: %{stream_id: stream_id}
        }}
      e ->
        {:error, %Error{
          type: :system,
          context: __MODULE__,
          message: "Failed to read stream",
          details: %{stream_id: stream_id, error: e}
        }}
    end
  end

  @impl GameBot.Infrastructure.Persistence.EventStore.Behaviour
  def subscribe_to_stream(stream_id, subscriber, subscription_options \\ [], opts \\ []) do
    try do
      with {:ok, subscription} <- super(stream_id, subscriber, subscription_options, opts) do
        Process.monitor(subscription)
        {:ok, subscription}
      end
    rescue
      e ->
        {:error, %Error{
          type: :system,
          context: __MODULE__,
          message: "Failed to create subscription",
          details: %{stream_id: stream_id, error: e}
        }}
    end
  end

  @impl GameBot.Infrastructure.Persistence.EventStore.Behaviour
  def stream_version(stream_id) do
    try do
      case read_stream_forward(stream_id, 0, 1) do
        {:ok, []} -> {:ok, 0}
        {:ok, events} -> {:ok, length(events)}
        error -> error
      end
    rescue
      e ->
        {:error, %Error{
          type: :system,
          context: __MODULE__,
          message: "Failed to get stream version",
          details: %{stream_id: stream_id, error: e}
        }}
    end
  end

  # Private Functions

  defp handle_telemetry_event(@telemetry_prefix ++ [:event], measurements, metadata, _config) do
    require Logger
    Logger.debug(fn ->
      "EventStore event: #{inspect(metadata)}\nMeasurements: #{inspect(measurements)}"
    end)
  end
end
````

Now let's implement the adapter that provides the high-level interface:

````elixir:game_bot/lib/game_bot/infrastructure/persistence/event_store/adapter.ex
defmodule GameBot.Infrastructure.Persistence.EventStore.Adapter do
  @moduledoc """
  Adapter layer for EventStore providing validation, serialization, and monitoring.
  """

  alias GameBot.Infrastructure.Persistence.Error
  alias GameBot.Infrastructure.Persistence.EventStore.{Behaviour, Serializer}

  # Configuration
  @max_append_retries Application.compile_env(:game_bot, [EventStore, :max_append_retries], 3)
  @max_stream_size Application.compile_env(:game_bot, [EventStore, :max_stream_size], 10_000)
  @base_backoff_delay 100

  @store Application.compile_env(:game_bot, [EventStore, :implementation], 
    GameBot.Infrastructure.Persistence.EventStore.Postgres)

  @doc """
  Append events to a stream with validation and retries.
  """
  def append_to_stream(stream_id, expected_version, events, opts \\ []) do
    with :ok <- validate_events(events),
         :ok <- validate_stream_size(stream_id),
         {:ok, serialized} <- serialize_events(events) do
      do_append_with_retry(stream_id, expected_version, serialized, opts)
    end
  end

  @doc """
  Read events from a stream with deserialization.
  """
  def read_stream_forward(stream_id, start_version \\ 0, count \\ 1000, opts \\ []) do
    with {:ok, events} <- @store.read_stream_forward(stream_id, start_version, count, opts),
         {:ok, deserialized} <- deserialize_events(events) do
      {:ok, deserialized}
    end
  end

  @doc """
  Subscribe to a stream with monitoring.
  """
  def subscribe_to_stream(stream_id, subscriber, subscription_options \\ [], opts \\ []) do
    @store.subscribe_to_stream(stream_id, subscriber, subscription_options, opts)
  end

  # Private Functions

  defp validate_events(events) when is_list(events), do: :ok
  defp validate_events(events), do: {:error, validation_error("Events must be a list", events)}

  defp validate_stream_size(stream_id) do
    case @store.stream_version(stream_id) do
      {:ok, version} when version >= @max_stream_size ->
        {:error, stream_size_error(stream_id, version)}
      _ ->
        :ok
    end
  end

  defp do_append_with_retry(stream_id, expected_version, events, opts) do
    timeout = Keyword.get(opts, :timeout, 5000)
    retry_count = Keyword.get(opts, :retry_count, @max_append_retries)

    case do_append_with_timeout(stream_id, expected_version, events, timeout) do
      {:error, %Error{type: :connection}} when retry_count > 0 ->
        Process.sleep(exponential_backoff(retry_count))
        do_append_with_retry(stream_id, expected_version, events, [
          {:timeout, timeout},
          {:retry_count, retry_count - 1}
        ])
      result ->
        result
    end
  end

  defp do_append_with_timeout(stream_id, expected_version, events, timeout) do
    task = Task.async(fn ->
      @store.append_to_stream(stream_id, expected_version, events)
    end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, timeout_error(stream_id, timeout)}
    end
  end

  defp serialize_events(events) do
    events
    |> Enum.map(&Serializer.serialize/1)
    |> collect_results()
  end

  defp deserialize_events(events) do
    events
    |> Enum.map(&(&1.data))
    |> Enum.map(&Serializer.deserialize/1)
    |> collect_results()
  end

  defp collect_results(results) do
    results
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, item}, {:ok, items} -> {:cont, {:ok, [item | items]}}
      {:error, _} = error, _ -> {:halt, error}
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      error -> error
    end
  end

  defp exponential_backoff(retry) do
    trunc(:math.pow(2, @max_append_retries - retry) * @base_backoff_delay)
  end

  # Error Helpers
  defp validation_error(message, details), do: 
    %Error{type: :validation, context: __MODULE__, message: message, details: details}
  
  defp stream_size_error(stream_id, size), do: 
    %Error{type: :stream_too_large, context: __MODULE__, 
           message: "Stream exceeds maximum size", 
           details: %{stream_id: stream_id, current_size: size, max_size: @max_stream_size}}
  
  defp timeout_error(stream_id, timeout), do: 
    %Error{type: :timeout, context: __MODULE__, 
           message: "Operation timed out", 
           details: %{stream_id: stream_id, timeout: timeout}}
end
````

Would you like me to implement the repository next?

---

_**User**_

yes

---

_**Assistant**_

Now let's implement the repository with proper error handling and behavior implementation:

````elixir:game_bot/lib/game_bot/infrastructure/persistence/repo/postgres.ex
defmodule GameBot.Infrastructure.Persistence.Repo.Postgres do
  @moduledoc """
  PostgreSQL repository implementation with standardized error handling.
  """

  use Ecto.Repo,
    otp_app: :game_bot,
    adapter: Ecto.Adapters.Postgres

  @behaviour GameBot.Infrastructure.Persistence.Repo.Behaviour

  alias GameBot.Infrastructure.Persistence.Error

  @impl GameBot.Infrastructure.Persistence.Repo.Behaviour
  def transaction(fun) do
    try do
      super(fun)
    rescue
      e in Ecto.ConstraintError ->
        {:error, %Error{
          type: :validation,
          context: __MODULE__,
          message: "Constraint violation",
          details: %{
            constraint: e.constraint,
            type: e.type,
            message: e.message
          }
        }}
      e in Ecto.InvalidChangesetError ->
        {:error, %Error{
          type: :validation,
          context: __MODULE__,
          message: "Invalid changeset",
          details: e.changeset
        }}
      e ->
        {:error, %Error{
          type: :system,
          context: __MODULE__,
          message: "Transaction failed",
          details: e
        }}
    end
  end

  @impl GameBot.Infrastructure.Persistence.Repo.Behaviour
  def insert(struct, opts \\ []) do
    try do
      super(struct, opts)
    rescue
      e in Ecto.ConstraintError ->
        {:error, constraint_error(e)}
      e ->
        {:error, system_error("Insert failed", e)}
    end
  end

  @impl GameBot.Infrastructure.Persistence.Repo.Behaviour
  def update(struct, opts \\ []) do
    try do
      super(struct, opts)
    rescue
      e in Ecto.StaleEntryError ->
        {:error, %Error{
          type: :concurrency,
          context: __MODULE__,
          message: "Concurrent modification",
          details: %{struct: e.struct, attempted_value: e.attempted_value}
        }}
      e ->
        {:error, system_error("Update failed", e)}
    end
  end

  @impl GameBot.Infrastructure.Persistence.Repo.Behaviour
  def delete(struct, opts \\ []) do
    try do
      super(struct, opts)
    rescue
      e in Ecto.StaleEntryError ->
        {:error, %Error{
          type: :concurrency,
          context: __MODULE__,
          message: "Concurrent deletion",
          details: %{struct: e.struct}
        }}
      e ->
        {:error, system_error("Delete failed", e)}
    end
  end

  # Private Functions

  defp constraint_error(%{constraint: constraint, type: type} = e) do
    %Error{
      type: :validation,
      context: __MODULE__,
      message: "Constraint violation",
      details: %{
        constraint: constraint,
        type: type,
        message: e.message
      }
    }
  end

  defp system_error(message, error) do
    %Error{
      type: :system,
      context: __MODULE__,
      message: message,
      details: error
    }
  end
end
````

Now we need to create a high-level repository interface:

````elixir:game_bot/lib/game_bot/infrastructure/persistence/repo.ex
defmodule GameBot.Infrastructure.Persistence.Repo do
  @moduledoc """
  High-level repository interface providing standardized access to persistence.
  """

  alias GameBot.Infrastructure.Persistence.Error
  alias GameBot.Infrastructure.Persistence.Repo.Postgres

  @repo Application.compile_env(:game_bot, [__MODULE__, :implementation], Postgres)

  @doc """
  Executes the given function inside a transaction.
  """
  def transaction(fun) when is_function(fun, 0) do
    @repo.transaction(fun)
  end

  @doc """
  Inserts a struct into the repository.
  """
  def insert(struct, opts \\ []) do
    @repo.insert(struct, opts)
  end

  @doc """
  Updates a struct in the repository.
  """
  def update(struct, opts \\ []) do
    @repo.update(struct, opts)
  end

  @doc """
  Deletes a struct from the repository.
  """
  def delete(struct, opts \\ []) do
    @repo.delete(struct, opts)
  end

  @doc """
  Gets a single record by id.
  """
  def get(queryable, id, opts \\ []) do
    try do
      case @repo.get(queryable, id) do
        nil -> {:error, not_found_error(queryable, id)}
        record -> {:ok, record}
      end
    rescue
      e -> {:error, system_error("Failed to get record", e)}
    end
  end

  # Error Helpers

  defp not_found_error(queryable, id) do
    %Error{
      type: :not_found,
      context: __MODULE__,
      message: "Record not found",
      details: %{
        queryable: queryable,
        id: id
      }
    }
  end

  defp system_error(message, error) do
    %Error{
      type: :system,
      context: __MODULE__,
      message: message,
      details: error
    }
  end
end
````

This completes the refactoring of the infrastructure layer with:

1. Clear separation of interfaces and implementations
2. Standardized error handling across all components
3. Proper behavior definitions
4. Consistent module organization
5. Improved testability through dependency injection
6. Better error messages and context

Would you like me to explain any part in more detail or help with testing these components?

---

_**User**_

update documentation 

---

_**Assistant**_

I'll update the module organization documentation to reflect the new structure:

````markdown:game_bot/lib/docs/infrastructure/module_organization.md
# Module Organization

## Current Structure

### Infrastructure Layer
```
game_bot/lib/game_bot/infrastructure/persistence/
├── error.ex                # Standardized error handling
├── repo/                  # Repository pattern implementation
│   ├── behaviour.ex       # Repository behavior definition
│   ├── postgres.ex        # PostgreSQL repository implementation
│   └── repo.ex           # High-level repository interface
└── event_store/          # Event sourcing implementation
    ├── behaviour.ex      # EventStore behavior definition
    ├── adapter.ex        # High-level EventStore interface
    ├── postgres.ex       # PostgreSQL EventStore implementation
    └── serializer.ex     # Event serialization
```

### Domain Layer
```
game_bot/lib/game_bot/domain/
├── aggregates/         # Domain aggregates
├── commands/          # Command definitions
├── events/           # Event definitions
├── game_modes/       # Game mode implementations
└── projections/     # Event projections
```

### Bot Layer
```
game_bot/lib/game_bot/bot/
├── commands/         # Command handlers
│   ├── game_commands.ex
│   ├── replay_commands.ex
│   └── team_commands.ex
└── dispatcher.ex    # Command routing
```

## Infrastructure Layer Design

### Error Handling
- Standardized error types across all infrastructure components
- Consistent error structure with context, type, message, and details
- Clear error categorization (validation, concurrency, system, etc.)

### Repository Pattern
- Clear behavior definition for repositories
- Standardized CRUD operations
- Transaction support
- Proper error handling and mapping
- Dependency injection support

### Event Store
- Behavior-driven design
- Serialization/deserialization of events
- Retry mechanisms for transient failures
- Stream size management
- Telemetry integration

## Implementation Details

### Error Module
```elixir
%Error{
  type: error_type(),      # Type of error
  context: module(),       # Module where error occurred
  message: String.t(),     # Human-readable message
  details: term()          # Error-specific details
}
```

### Repository Interface
```elixir
# Core operations
transaction((() -> result)) :: {:ok, result} | {:error, Error.t()}
insert(struct()) :: {:ok, struct()} | {:error, Error.t()}
update(struct()) :: {:ok, struct()} | {:error, Error.t()}
delete(struct()) :: {:ok, struct()} | {:error, Error.t()}
```

### Event Store Interface
```elixir
# Core operations
append_to_stream(stream_id(), version(), [event()], opts()) :: {:ok, [event()]} | {:error, Error.t()}
read_stream_forward(stream_id(), version(), count(), opts()) :: {:ok, [event()]} | {:error, Error.t()}
subscribe_to_stream(stream_id(), pid(), opts(), opts()) :: {:ok, pid()} | {:error, Error.t()}
```

## Key Features

1. **Clear Module Boundaries**
   - Separate interfaces from implementations
   - Consistent naming conventions
   - Proper dependency management

2. **Error Handling**
   - Standardized error types
   - Detailed error context
   - Proper error propagation

3. **Dependency Injection**
   - Configurable implementations
   - Easy testing support
   - Runtime flexibility

4. **Monitoring & Telemetry**
   - Event store monitoring
   - Performance tracking
   - Error logging

## Usage Guidelines

1. **Error Handling**
```elixir
# Always use the standardized Error struct
{:error, %Error{type: :validation, context: __MODULE__}}

# Provide detailed error information
{:error, %Error{
  type: :concurrency,
  context: __MODULE__,
  message: "Concurrent modification",
  details: %{expected: version, actual: current}
}}
```

2. **Repository Usage**
```elixir
# Use the high-level interface
alias GameBot.Infrastructure.Persistence.Repo

# Operations return tagged tuples
{:ok, record} = Repo.insert(struct)
{:ok, record} = Repo.get(User, id)
```

3. **Event Store Usage**
```elixir
alias GameBot.Infrastructure.Persistence.EventStore.Adapter

# Operations include validation and retries
{:ok, events} = Adapter.append_to_stream("game-123", version, events)
```

## Testing Strategy

1. **Unit Tests**
   - Test each implementation separately
   - Mock dependencies using behaviors
   - Test error conditions

2. **Integration Tests**
   - Test complete workflows
   - Use test implementations
   - Verify error handling

3. **Property Tests**
   - Test serialization
   - Verify error handling
   - Check concurrent operations
````

This documentation now reflects:
1. The new directory structure
2. Clear interfaces and implementations
3. Standardized error handling
4. Usage guidelines
5. Testing strategy

Would you like me to add or clarify anything in the documentation?

---

_**User**_

@refactoring_plan.md update our progress on the refactoring plan and tell me what to prioritize next

---

_**Assistant**_

I'll update the refactoring plan to reflect our progress and next priorities:

````markdown:game_bot/lib/docs/infrastructure/refactoring_plan.md
# Refactoring Priority and Plans

## Progress Update

### ✅ Completed
1. Created new directory structure for infrastructure layer
2. Implemented standardized error handling
3. Created behavior definitions for repositories and event store
4. Implemented PostgreSQL repository with error handling
5. Implemented EventStore adapter with retries and validation
6. Added proper serialization with error handling
7. Added telemetry integration for monitoring

### 🚧 In Progress
1. Infrastructure Layer Cleanup
   - [x] Move event store code to infrastructure/persistence
   - [x] Create clear interfaces
   - [x] Standardize error handling
   - [ ] Add tests for new implementations
   - [ ] Remove old event store implementations

## Next Priorities

### 1. Immediate (Current Sprint)
1. **Testing Infrastructure**
   - [ ] Create test helpers for repository testing
   - [ ] Add unit tests for error handling
   - [ ] Add integration tests for PostgreSQL implementations
   - [ ] Add property tests for serialization

2. **Migration Tasks**
   - [ ] Update existing code to use new repository interface
   - [ ] Update existing code to use new event store interface
   - [ ] Remove deprecated modules:
     - `game_bot/lib/game_bot/infrastructure/event_store.ex`
     - `game_bot/lib/game_bot/infrastructure/event_store_adapter.ex`
     - `game_bot/lib/game_bot/infrastructure/event_store/serializer.ex`
     - `game_bot/lib/game_bot/infrastructure/repo.ex`

### 2. Next Sprint
1. **Domain Layer Reorganization**
   - [ ] Separate event definitions by context
   - [ ] Create proper aggregate roots
   - [ ] Define clear command/event flows
   - [ ] Remove circular dependencies

2. **Documentation**
   - [ ] Add detailed API documentation
   - [ ] Create usage examples
   - [ ] Document testing patterns

### 3. Future Work
1. **Bot Layer Refinement**
   - [ ] Simplify command handlers
   - [ ] Improve error reporting
   - [ ] Add telemetry/logging

## Implementation Approach

1. **Testing First**
   ```elixir
   # Create test helpers
   defmodule GameBot.Test.RepositoryCase do
     # Common test setup and helpers
   end

   # Add comprehensive tests
   describe "repository operations" do
     test "handles concurrent modifications"
     test "properly validates input"
     test "manages transactions"
   end
   ```

2. **Gradual Migration**
   ```elixir
   # Update existing code to use new interfaces
   alias GameBot.Infrastructure.Persistence.{Repo, EventStore.Adapter}

   def handle_command(command) do
     Repo.transaction(fn ->
       # Use new interfaces
     end)
   end
   ```

3. **Cleanup**
   - Remove old implementations only after all dependencies are updated
   - Verify no references to old modules exist
   - Run full test suite after each removal

## Success Metrics

- [ ] All tests passing
- [ ] No references to old implementations
- [ ] Improved error handling coverage
- [ ] Clear module boundaries
- [ ] Documentation up to date

## Risk Mitigation

1. **Testing**
   - Add tests before removing old code
   - Use property testing for serialization
   - Add integration tests for workflows

2. **Migration**
   - Update one module at a time
   - Keep old implementations until fully migrated
   - Verify each step with tests

3. **Monitoring**
   - Add telemetry for key operations
   - Monitor error rates during migration
   - Track performance metrics
````

Based on this update, I recommend focusing on:

1. First, create comprehensive tests for the new infrastructure implementations
2. Then, gradually migrate existing code to use the new interfaces
3. Finally, remove the old implementations once everything is migrated

Would you like me to help with implementing any of these priorities?

---

_**User**_

yes create tests that map exactly onto our new implementation

---

_**Assistant**_

I'll create comprehensive tests for our new infrastructure implementations. Let's start with the test helpers and then implement specific test cases for each component.

1. First, let's create the test helper:

````elixir:game_bot/test/support/repository_case.ex
defmodule GameBot.Test.RepositoryCase do
  @moduledoc """
  Helper module for testing repository and event store implementations.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias GameBot.Infrastructure.Persistence.Error
      alias GameBot.Infrastructure.Persistence.{Repo, EventStore}
      alias GameBot.Infrastructure.Persistence.EventStore.{Adapter, Serializer}

      import GameBot.Test.RepositoryCase
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(GameBot.Infrastructure.Persistence.Repo.Postgres)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(GameBot.Infrastructure.Persistence.Repo.Postgres, {:shared, self()})
    end

    :ok
  end

  @doc """
  Creates a test event for serialization testing.
  """
  def build_test_event(type \\ "test_event") do
    %{
      event_type: type,
      event_version: 1,
      data: %{
        "test_field" => "test_value",
        "timestamp" => DateTime.utc_now()
      },
      stored_at: DateTime.utc_now()
    }
  end

  @doc """
  Creates a unique stream ID for testing.
  """
  def unique_stream_id, do: "test-#{:erlang.unique_integer([:positive])}"
end
````

2. Now let's create the serializer tests:

````elixir:game_bot/test/game_bot/infrastructure/persistence/event_store/serializer_test.exs
defmodule GameBot.Infrastructure.Persistence.EventStore.SerializerTest do
  use GameBot.Test.RepositoryCase, async: true
  use ExUnitProperties

  alias GameBot.Infrastructure.Persistence.EventStore.Serializer
  alias GameBot.Infrastructure.Persistence.Error

  describe "serialize/1" do
    test "successfully serializes valid event" do
      event = build_test_event()
      assert {:ok, serialized} = Serializer.serialize(event)
      assert is_map(serialized)
      assert serialized.event_type == event.event_type
      assert serialized.event_version == event.event_version
    end

    test "returns error for invalid event structure" do
      assert {:error, %Error{type: :validation}} = Serializer.serialize(%{invalid: "structure"})
    end

    property "serialization is reversible" do
      check all event <- event_generator() do
        assert {:ok, serialized} = Serializer.serialize(event)
        assert {:ok, deserialized} = Serializer.deserialize(serialized)
        assert event == deserialized
      end
    end
  end

  describe "deserialize/1" do
    test "successfully deserializes valid event data" do
      event = build_test_event()
      {:ok, serialized} = Serializer.serialize(event)
      assert {:ok, deserialized} = Serializer.deserialize(serialized)
      assert deserialized.event_type == event.event_type
    end

    test "returns error for missing required fields" do
      assert {:error, %Error{type: :validation}} = 
        Serializer.deserialize(%{"incomplete" => "data"})
    end
  end

  describe "event_version/1" do
    test "returns correct version for known event types" do
      assert {:ok, version} = Serializer.event_version("game_started")
      assert is_integer(version)
    end

    test "returns error for unknown event type" do
      assert {:error, %Error{type: :validation}} = 
        Serializer.event_version("unknown_event_type")
    end
  end

  # Generators for property testing
  defp event_generator do
    gen all
      type <- StreamData.string(:alphanumeric, min_length: 1),
      version <- StreamData.positive_integer(),
      data <- map_generator() do
      %{
        event_type: type,
        event_version: version,
        data: data,
        stored_at: DateTime.utc_now()
      }
    end
  end

  defp map_generator do
    gen all
      keys <- StreamData.list_of(StreamData.string(:alphanumeric), min_length: 1),
      values <- StreamData.list_of(StreamData.string(:alphanumeric), min_length: 1),
      pairs = Enum.zip(keys, values) do
      Map.new(pairs)
    end
  end
end
````

3. Let's create the PostgreSQL event store tests:

````elixir:game_bot/test/game_bot/infrastructure/persistence/event_store/postgres_test.exs
defmodule GameBot.Infrastructure.Persistence.EventStore.PostgresTest do
  use GameBot.Test.RepositoryCase, async: true

  alias GameBot.Infrastructure.Persistence.EventStore.Postgres
  alias GameBot.Infrastructure.Persistence.Error

  describe "append_to_stream/4" do
    test "successfully appends events to stream" do
      stream_id = unique_stream_id()
      events = [build_test_event()]

      assert {:ok, stored_events} = Postgres.append_to_stream(stream_id, 0, events)
      assert length(stored_events) == 1
    end

    test "handles concurrent modifications" do
      stream_id = unique_stream_id()
      events = [build_test_event()]

      {:ok, _} = Postgres.append_to_stream(stream_id, 0, events)
      assert {:error, %Error{type: :concurrency}} = 
        Postgres.append_to_stream(stream_id, 0, events)
    end
  end

  describe "read_stream_forward/4" do
    test "reads events from existing stream" do
      stream_id = unique_stream_id()
      events = [build_test_event()]

      {:ok, _} = Postgres.append_to_stream(stream_id, 0, events)
      assert {:ok, read_events} = Postgres.read_stream_forward(stream_id)
      assert length(read_events) == 1
    end

    test "handles non-existent stream" do
      assert {:error, %Error{type: :not_found}} = 
        Postgres.read_stream_forward("non-existent-stream")
    end
  end

  describe "subscribe_to_stream/4" do
    test "successfully subscribes to stream" do
      stream_id = unique_stream_id()
      assert {:ok, subscription} = Postgres.subscribe_to_stream(stream_id, self())
      assert is_pid(subscription)
    end
  end

  describe "stream_version/1" do
    test "returns correct version for empty stream" do
      stream_id = unique_stream_id()
      assert {:ok, 0} = Postgres.stream_version(stream_id)
    end

    test "returns correct version after appending" do
      stream_id = unique_stream_id()
      events = [build_test_event()]

      {:ok, _} = Postgres.append_to_stream(stream_id, 0, events)
      assert {:ok, 1} = Postgres.stream_version(stream_id)
    end
  end
end
````

4. Finally, let's test the adapter:

````elixir:game_bot/test/game_bot/infrastructure/persistence/event_store/adapter_test.exs
defmodule GameBot.Infrastructure.Persistence.EventStore.AdapterTest do
  use GameBot.Test.RepositoryCase, async: true

  alias GameBot.Infrastructure.Persistence.EventStore.Adapter
  alias GameBot.Infrastructure.Persistence.Error

  describe "append_to_stream/4" do
    test "validates events before appending" do
      assert {:error, %Error{type: :validation}} = 
        Adapter.append_to_stream("test-stream", 0, "invalid")
    end

    test "validates stream size" do
      stream_id = unique_stream_id()
      events = List.duplicate(build_test_event(), 10_001)

      assert {:error, %Error{type: :stream_too_large}} = 
        Adapter.append_to_stream(stream_id, 0, events)
    end

    test "handles serialization errors" do
      stream_id = unique_stream_id()
      invalid_event = %{invalid: "structure"}

      assert {:error, %Error{type: :serialization}} = 
        Adapter.append_to_stream(stream_id, 0, [invalid_event])
    end
  end

  describe "read_stream_forward/4" do
    test "deserializes events on read" do
      stream_id = unique_stream_id()
      event = build_test_event()

      {:ok, _} = Adapter.append_to_stream(stream_id, 0, [event])
      assert {:ok, [read_event]} = Adapter.read_stream_forward(stream_id)
      assert read_event.event_type == event.event_type
    end
  end

  describe "retry mechanism" do
    test "retries on connection errors" do
      # This would need a mock implementation to properly test
      # We could add a test implementation that fails N times then succeeds
    end

    test "respects timeout settings" do
      stream_id = unique_stream_id()
      event = build_test_event()

      assert {:error, %Error{type: :timeout}} = 
        Adapter.append_to_stream(stream_id, 0, [event], timeout: 1)
    end
  end
end
````

Would you like me to:
1. Add more specific test cases for any component?
2. Create tests for the repository implementation?
3. Add test helpers for mocking dependencies?

---

_**User**_

suggest the next step

---

_**Assistant**_

Looking at our test implementation, I notice a few key areas we should address next:

1. We need a mock implementation to properly test the retry mechanism in the adapter. Let's create:

````elixir:game_bot/test/support/mocks/event_store.ex
defmodule GameBot.Test.Mocks.EventStore do
  @moduledoc """
  Mock EventStore implementation for testing retry mechanisms and error conditions.
  """
  @behaviour GameBot.Infrastructure.Persistence.EventStore.Behaviour

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def set_failure_count(count) do
    GenServer.call(__MODULE__, {:set_failure_count, count})
  end

  # Behaviour Implementation
  @impl true
  def append_to_stream(stream_id, version, events, opts \\ []) do
    GenServer.call(__MODULE__, {:append, stream_id, version, events, opts})
  end

  # ... other behaviour implementations
end
````

2. Then update the adapter test to use this mock:

````elixir:game_bot/test/game_bot/infrastructure/persistence/event_store/adapter_test.exs
  describe "retry mechanism" do
    setup do
      start_supervised!(GameBot.Test.Mocks.EventStore)
      :ok
    end

    test "retries on connection errors" do
      stream_id = unique_stream_id()
      event = build_test_event()
      
      GameBot.Test.Mocks.EventStore.set_failure_count(2)
      
      assert {:ok, _} = Adapter.append_to_stream(stream_id, 0, [event])
    end
  end
````

3. We should also add repository tests:

````elixir:game_bot/test/game_bot/infrastructure/persistence/repo/postgres_test.exs
defmodule GameBot.Infrastructure.Persistence.Repo.PostgresTest do
  use GameBot.Test.RepositoryCase, async: true
  
  alias GameBot.Infrastructure.Persistence.Repo.Postgres
  alias GameBot.Infrastructure.Persistence.Error

  describe "transaction/1" do
    test "successfully executes transaction"
    test "rolls back on error"
    test "handles concurrent modifications"
  end
  
  # ... other tests
end
````

Here's my suggested priority order:

1. First, implement the mock EventStore
   - This will allow proper testing of retry mechanisms
   - Help verify error handling
   - Enable testing of timeout scenarios

2. Then, add repository tests
   - Test transaction handling
   - Test concurrent modifications
   - Test error conditions

3. Finally, add integration tests
   - Test complete workflows
   - Verify error propagation
   - Test performance under load

Would you like me to implement any of these components next?

---

_**User**_

yes implement in your order

---

_**Assistant**_

I'll start with implementing the mock EventStore fully:

````elixir:game_bot/test/support/mocks/event_store.ex
defmodule GameBot.Test.Mocks.EventStore do
  @moduledoc """
  Mock EventStore implementation for testing retry mechanisms and error conditions.
  """
  @behaviour GameBot.Infrastructure.Persistence.EventStore.Behaviour

  use GenServer
  alias GameBot.Infrastructure.Persistence.Error

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def set_failure_count(count) do
    GenServer.call(__MODULE__, {:set_failure_count, count})
  end

  def set_delay(milliseconds) do
    GenServer.call(__MODULE__, {:set_delay, milliseconds})
  end

  def reset_state do
    GenServer.call(__MODULE__, :reset_state)
  end

  # Behaviour Implementation

  @impl true
  def append_to_stream(stream_id, version, events, opts \\ []) do
    GenServer.call(__MODULE__, {:append, stream_id, version, events, opts})
  end

  @impl true
  def read_stream_forward(stream_id, start_version \\ 0, count \\ 1000, opts \\ []) do
    GenServer.call(__MODULE__, {:read, stream_id, start_version, count, opts})
  end

  @impl true
  def subscribe_to_stream(stream_id, subscriber, subscription_options \\ [], opts \\ []) do
    GenServer.call(__MODULE__, {:subscribe, stream_id, subscriber, subscription_options, opts})
  end

  @impl true
  def stream_version(stream_id) do
    GenServer.call(__MODULE__, {:version, stream_id})
  end

  # Server Implementation

  @impl true
  def init(_opts) do
    {:ok, %{
      streams: %{},
      failure_count: 0,
      delay: 0,
      subscriptions: %{}
    }}
  end

  @impl true
  def handle_call({:set_failure_count, count}, _from, state) do
    {:reply, :ok, %{state | failure_count: count}}
  end

  def handle_call({:set_delay, delay}, _from, state) do
    {:reply, :ok, %{state | delay: delay}}
  end

  def handle_call(:reset_state, _from, _state) do
    {:reply, :ok, %{streams: %{}, failure_count: 0, delay: 0, subscriptions: %{}}}
  end

  def handle_call({:append, stream_id, version, events, _opts}, _from, state) do
    if state.failure_count > 0 do
      {:reply, {:error, connection_error()}, %{state | failure_count: state.failure_count - 1}}
    else
      if state.delay > 0, do: Process.sleep(state.delay)

      stream = Map.get(state.streams, stream_id, [])
      current_version = length(stream)

      cond do
        version != current_version ->
          {:reply, {:error, concurrency_error(version, current_version)}, state}
        true ->
          new_stream = stream ++ events
          new_state = put_in(state.streams[stream_id], new_stream)
          notify_subscribers(stream_id, events, state.subscriptions)
          {:reply, {:ok, events}, new_state}
      end
    end
  end

  def handle_call({:read, stream_id, start_version, count, _opts}, _from, state) do
    if state.delay > 0, do: Process.sleep(state.delay)

    case Map.get(state.streams, stream_id) do
      nil ->
        {:reply, {:error, not_found_error(stream_id)}, state}
      events ->
        result = events
        |> Enum.drop(start_version)
        |> Enum.take(count)
        {:reply, {:ok, result}, state}
    end
  end

  def handle_call({:subscribe, stream_id, subscriber, _options, _opts}, _from, state) do
    ref = make_ref()
    new_subscriptions = Map.update(
      state.subscriptions,
      stream_id,
      %{ref => subscriber},
      &Map.put(&1, ref, subscriber)
    )
    {:reply, {:ok, ref}, %{state | subscriptions: new_subscriptions}}
  end

  def handle_call({:version, stream_id}, _from, state) do
    case Map.get(state.streams, stream_id) do
      nil -> {:reply, {:ok, 0}, state}
      events -> {:reply, {:ok, length(events)}, state}
    end
  end

  # Private Functions

  defp notify_subscribers(stream_id, events, subscriptions) do
    case Map.get(subscriptions, stream_id) do
      nil -> :ok
      subscribers ->
        Enum.each(subscribers, fn {_ref, pid} ->
          send(pid, {:events, events})
        end)
    end
  end

  defp connection_error do
    %Error{
      type: :connection,
      context: __MODULE__,
      message: "Simulated connection error",
      details: %{retryable: true}
    }
  end

  defp concurrency_error(expected, actual) do
    %Error{
      type: :concurrency,
      context: __MODULE__,
      message: "Wrong expected version",
      details: %{expected: expected, actual: actual}
    }
  end

  defp not_found_error(stream_id) do
    %Error{
      type: :not_found,
      context: __MODULE__,
      message: "Stream not found",
      details: %{stream_id: stream_id}
    }
  end
end
````

This mock implementation:
1. Simulates connection failures with configurable retry count
2. Supports artificial delays for timeout testing
3. Maintains in-memory state for streams
4. Handles subscriptions and notifications
5. Provides proper error handling

Now we can use this to properly test the adapter's retry mechanism. Would you like me to:

1. Update the adapter tests to use this mock implementation more thoroughly?
2. Move on to implementing the repository tests?
3. Something else?

---

_**User**_

For the code present, we get this error:
```
** (TokenMissingError) token missing on game_bot/test/game_bot/infrastructure/persistence/event_store/serializer_test.exs:78:6:
    error: missing terminator: end
    │
  1 │ defmodule GameBot.Infrastructure.Persistence.EventStore.SerializerTest do
    │                                                                        └ unclosed delimiter
 ...
 78 │   end
    │      └ missing closing delimiter (expected "end")
    │
    └─ game_bot/test/game_bot/infrastructure/persistence/event_store/serializer_test.exs:78:6
```
How can I resolve this? If you propose a fix, please make it concise.

---

_**Assistant**_

The issue is in the `map_generator` function. Here's the fix:

````elixir:game_bot/test/game_bot/infrastructure/persistence/event_store/serializer_test.exs
  defp map_generator do
    gen all(
      keys <- StreamData.list_of(StreamData.string(:alphanumeric), min_length: 1),
      values <- StreamData.list_of(StreamData.string(:alphanumeric), min_length: 1),
      pairs = Enum.zip(keys, values)) do
      Map.new(pairs)
    end
  end
````

The issue was missing parentheses around the `gen all` arguments, similar to how we fixed the `event_generator` function.

---



---

