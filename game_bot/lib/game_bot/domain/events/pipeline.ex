defmodule GameBot.Domain.Events.Pipeline do
  @moduledoc """
  Processes events through a series of steps:
  1. Validation
  2. Enrichment
  3. Persistence
  4. Caching
  5. Broadcasting
  """

 alias GameBot.Domain.Events.{Cache, Telemetry}

   @doc """
   Processes an event through the pipeline.

  @doc """
  Processes an event through the pipeline.
  Returns {:ok, event} on success, {:error, reason} on failure.
  """
  @spec process_event(struct()) :: {:ok, struct()} | {:error, term()}
  def process_event(event) do
    event
    |> validate()
    |> enrich()
    |> persist()
    |> cache()
    |> broadcast()
  end

  @doc """
  Validates an event's structure and content.
  """
  @spec validate(struct()) :: {:ok, struct()} | {:error, term()}
  def validate(event) do
    start = System.monotonic_time()

    result = with :ok <- event.__struct__.validate(event),
                 :ok <- validate_metadata(event) do
      {:ok, event}
    end

    duration = System.monotonic_time() - start
    Telemetry.record_event_validated(event.__struct__, duration)

    result
  end

  @doc """
  Enriches an event with additional metadata.
  """
  @spec enrich({:ok, struct()} | {:error, term()}) :: {:ok, struct()} | {:error, term()}
  def enrich({:ok, event}) do
    {:ok, Map.update!(event, :metadata, &add_processing_metadata/1)}
  end
  def enrich(error), do: error

  @doc """
  Persists an event to the event store.
  """
  @spec persist({:ok, struct()} | {:error, term()}) :: {:ok, struct()} | {:error, term()}
  def persist({:ok, event} = result) do
    Task.start(fn ->
      # Use the configured EventStore
      event_store = Application.get_env(:game_bot, :event_store_adapter, GameBot.Infrastructure.Persistence.EventStore)

      event_store.append_to_stream(
        event.game_id,
        :any,  # expected version
        [event]
      )
    end)
    result
  end
  def persist(error), do: error

  @doc """
  Caches an event for fast retrieval.
  """
  @spec cache({:ok, struct()} | {:error, term()}) :: {:ok, struct()} | {:error, term()}
  def cache({:ok, event} = result) do
    Cache.cache_event(event)
    result
  end
  def cache(error), do: error

  @doc """
  Broadcasts an event to subscribers.
  """
  @spec broadcast({:ok, struct()} | {:error, term()}) :: {:ok, struct()} | {:error, term()}
  def broadcast({:ok, event} = result) do
    if Application.get_env(:game_bot, :event_system, [])
       |> Keyword.get(:use_enhanced_pubsub, false) do
      # Use the new enhanced broadcaster
      GameBot.Domain.Events.Broadcaster.broadcast_event(event)
      result
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

  # Private Functions

  defp validate_metadata(event) do
    with %{metadata: metadata} <- event,
         true <- is_map(metadata) do
      if Map.has_key?(metadata, "guild_id") or Map.has_key?(metadata, :guild_id) or
         Map.has_key?(metadata, "source_id") or Map.has_key?(metadata, :source_id) do
        :ok
      else
        {:error, "guild_id or source_id is required in metadata"}
      end
    else
      _ -> {:error, "invalid metadata format"}
    end
  end

  defp add_processing_metadata(metadata) do
    metadata
    |> Map.put_new(:processed_at, DateTime.utc_now())
    |> Map.put_new(:processor_id, System.pid())
  end
end
