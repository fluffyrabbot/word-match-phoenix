defmodule GameBot.TestEventStore do
  @moduledoc """
  A simple in-memory event store for testing.
  """

  alias GameBot.Domain.Events.GameEvents.GameStarted
  require EventStore
  alias EventStore.RecordedEvent

  # Define the struct fields explicitly
  @recorded_event_fields [
    :event_id,
    :event_number,
    :stream_id,
    :stream_version,
    :correlation_id,
    :causation_id,
    :event_type,
    :data,
    :metadata,
    :created_at
  ]

  def append_to_stream(stream_id, expected_version, events) do
    # Store events in ETS
    :ets.insert(:test_event_store, {stream_id, expected_version, events})
    :ok
  end

  def read_stream_forward(stream_id) do
    case :ets.lookup(:test_event_store, stream_id) do
      [{^stream_id, version, events}] ->
        # Convert events to recorded_events format
        recorded_events = Enum.map(events, fn event ->
          serialized = GameBot.Domain.Events.GameEvents.serialize(event)
          struct(RecordedEvent, %{
            event_id: UUID.uuid4(),
            event_number: version,
            stream_id: stream_id,
            stream_version: version,
            correlation_id: nil,
            causation_id: nil,
            event_type: serialized["event_type"],
            data: serialized["data"],
            metadata: %{},
            created_at: DateTime.utc_now()
          })
        end)
        {:ok, recorded_events}
      [] ->
        {:ok, []}
    end
  end

  def read_all_streams_forward do
    case :ets.tab2list(:test_event_store) do
      [] ->
        {:ok, []}
      events ->
        first_event = List.first(events)
        case first_event do
          {stream_id, version, event_list} ->
            recorded_events = Enum.map(event_list, fn event ->
              serialized = GameBot.Domain.Events.GameEvents.serialize(event)
              struct(RecordedEvent, %{
                event_id: UUID.uuid4(),
                event_number: version,
                stream_id: stream_id,
                stream_version: version,
                correlation_id: nil,
                causation_id: nil,
                event_type: serialized["event_type"],
                data: serialized["data"],
                metadata: %{},
                created_at: DateTime.utc_now()
              })
            end)
            {:ok, recorded_events}
          _ ->
            {:ok, []}
        end
    end
  end

  def delete_stream(stream_id) do
    :ets.delete(:test_event_store, stream_id)
    :ok
  end

  # Initialize ETS table
  def init do
    :ets.new(:test_event_store, [:set, :public, :named_table])
    :ok
  end
end
