defmodule GameBot.Infrastructure.Persistence.EventStore.MacroIntegrationTest do
  @moduledoc """
  Tests for proper EventStore macro integration across implementations.
  """

  use GameBot.Test.EventStoreCase
  use ExUnit.Case, async: true

  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
  alias GameBot.TestEventStore
  alias GameBot.Test.Mocks.EventStore, as: MockEventStore

  setup :setup_event_store

  describe "EventStore macro integration" do
    test "core EventStore implementation" do
      verify_event_store_implementation(EventStore)
      verify_event_store_macro_usage(EventStore)
      verify_macro_integration_guidelines(EventStore)
    end

    test "PostgreSQL implementation" do
      verify_event_store_implementation(Postgres)
      verify_event_store_macro_usage(Postgres)
      verify_macro_integration_guidelines(Postgres)
    end

    test "test implementation" do
      verify_event_store_implementation(TestEventStore)
      verify_event_store_macro_usage(TestEventStore)
      verify_macro_integration_guidelines(TestEventStore)
    end

    test "mock implementation" do
      verify_event_store_implementation(MockEventStore)
      verify_event_store_macro_usage(MockEventStore)
      verify_macro_integration_guidelines(MockEventStore)
    end
  end

  describe "error handling" do
    test "core EventStore implementation" do
      verify_error_handling(EventStore)
    end

    test "PostgreSQL implementation" do
      verify_error_handling(Postgres)
    end

    test "test implementation" do
      verify_error_handling(TestEventStore)
    end

    test "mock implementation" do
      verify_error_handling(MockEventStore)
    end
  end

  describe "macro-generated functions" do
    test "config/0 is available in all implementations" do
      for module <- [EventStore, Postgres, TestEventStore, MockEventStore] do
        assert function_exported?(module, :config, 0),
               "#{inspect(module)} must have macro-generated config/0"
      end
    end

    test "ack/2 is available in all implementations" do
      for module <- [EventStore, Postgres, TestEventStore, MockEventStore] do
        assert function_exported?(module, :ack, 2),
               "#{inspect(module)} must have macro-generated ack/2"
      end
    end
  end

  describe "stream operations" do
    test "append and read with macro-generated functions" do
      event = create_test_event()

      for module <- [EventStore, Postgres, TestEventStore, MockEventStore] do
        assert {:ok, _} = module.append_to_stream(@test_stream_id, 0, [event])
        assert {:ok, [read_event]} = module.read_stream_forward(@test_stream_id)
        assert read_event.data == event.data
      end
    end
  end
end
