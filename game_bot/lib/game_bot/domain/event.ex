defmodule GameBot.Domain.Event do
  @moduledoc """
  Defines immutable events for event sourcing.
  
  Events represent facts that have happened in the system and are
  used to build and update projections.
  """
  
  alias GameBot.Infrastructure.Repo
  
  @doc """
  Creates a new event of the given type with the provided attributes.
  
  Returns {:ok, event} on success or {:error, reason} on failure.
  """
  def create(event_type, attrs) when is_atom(event_type) and is_map(attrs) do
    # Validate event data based on type
    with :ok <- validate_event(event_type, attrs),
         # Add event metadata
         event = Map.merge(attrs, %{
           type: event_type,
           id: UUID.uuid4(),
           version: 1
         }),
         # Persist the event
         :ok <- persist_event(event) do
      # Broadcast event to any listeners
      broadcast_event(event)
      
      {:ok, event}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Retrieves events for a specific aggregate (e.g., game session).
  """
  def get_events(aggregate_id) do
    # This would fetch events from storage sorted by timestamp
    # Placeholder implementation
    []
  end
  
  # Private helper functions
  
  defp validate_event(:game_started, attrs) do
    required_fields = [:channel_id, :initiator_id, :game_mode, :timestamp]
    validate_required_fields(attrs, required_fields)
  end
  
  defp validate_event(:player_joined, attrs) do
    required_fields = [:channel_id, :user_id, :timestamp]
    validate_required_fields(attrs, required_fields)
  end
  
  defp validate_event(_type, _attrs) do
    {:error, "Unknown event type"}
  end
  
  defp validate_required_fields(attrs, required_fields) do
    missing = required_fields
              |> Enum.filter(fn field -> !Map.has_key?(attrs, field) end)
              
    case missing do
      [] -> :ok
      fields -> {:error, "Missing required fields: #{inspect(fields)}"}
    end
  end
  
  defp persist_event(event) do
    # This would store the event in the event store
    # Placeholder implementation - in a real app, we'd use Ecto
    # to insert the event into a database table
    IO.inspect(event, label: "Event created")
    :ok
  end
  
  defp broadcast_event(event) do
    # This would publish the event to any subscribers
    # Placeholder implementation - in a real app, we'd use Phoenix.PubSub
    # or similar to notify interested processes
    :ok
  end
end 