defmodule GameBot.EventStoreCase do
  @moduledoc """
  This module defines the test case to be used by
  event store tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias GameBot.Infrastructure.EventStore

      # Helper to create test events
      def create_test_event(type, data, metadata \\ %{test: true}) do
        %{
          event_type: type,
          data: data,
          metadata: Map.merge(%{test: true}, metadata)
        }
      end

      # Helper to create test stream
      def create_test_stream(stream_id, events) do
        EventStore.append_to_stream(stream_id, :any, events)
      end

      # Helper to generate unique stream IDs
      def unique_stream_id do
        "test-stream-#{System.unique_integer([:positive])}"
      end
    end
  end

  setup do
    # Clean event store before each test
    :ok = GameBot.Infrastructure.EventStore.reset!()
    :ok
  end
end
