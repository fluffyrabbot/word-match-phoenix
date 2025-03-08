defmodule GameBot.Infrastructure.Persistence.EventStore.Serialization.EventTranslatorTest do
  use ExUnit.Case, async: true

  alias GameBot.Infrastructure.Error

  # Define migration functions in a separate module
  defmodule TestMigrations do
    def migrate_test_event_v1_to_v2(data) do
      {:ok, Map.put(data, "new_field", "default")}
    end
  end

  defmodule TestTranslator do
    use GameBot.Infrastructure.Persistence.EventStore.Serialization.EventTranslator

    register_event("test_event", TestEvent, 2)
    register_event("other_event", OtherEvent, 1)

    # Use function reference instead of anonymous function
    register_migration("test_event", 1, 2, &TestMigrations.migrate_test_event_v1_to_v2/1)
  end

  defmodule TestEvent do
    defstruct [:id, :data]
  end

  defmodule OtherEvent do
    defstruct [:id]
  end

  describe "lookup_module/1" do
    test "returns module for known event type" do
      assert {:ok, TestEvent} = TestTranslator.lookup_module("test_event")
    end

    test "returns error for unknown event type" do
      assert {:error, %Error{type: :not_found}} = TestTranslator.lookup_module("unknown")
    end
  end

  describe "get_version/1" do
    test "returns version for known event type" do
      assert {:ok, 2} = TestTranslator.get_version("test_event")
      assert {:ok, 1} = TestTranslator.get_version("other_event")
    end

    test "returns error for unknown event type" do
      assert {:error, %Error{type: :not_found}} = TestTranslator.get_version("unknown")
    end
  end

  describe "migrate/4" do
    test "returns same data when versions match" do
      data = %{"field" => "value"}
      assert {:ok, ^data} = TestTranslator.migrate("test_event", data, 2, 2)
    end

    test "successfully migrates data to newer version" do
      data = %{"field" => "value"}
      assert {:ok, migrated} = TestTranslator.migrate("test_event", data, 1, 2)
      assert migrated["new_field"] == "default"
      assert migrated["field"] == "value"
    end

    test "returns error when migrating to older version" do
      assert {:error, %Error{type: :validation}} =
        TestTranslator.migrate("test_event", %{}, 2, 1)
    end

    test "returns error when no migration path exists" do
      assert {:error, %Error{type: :not_found}} =
        TestTranslator.migrate("other_event", %{}, 1, 2)
    end

    test "returns error for unknown event type" do
      assert {:error, %Error{type: :not_found}} =
        TestTranslator.migrate("unknown", %{}, 1, 2)
    end
  end

  describe "event registration" do
    test "registers event modules" do
      modules = TestTranslator.event_modules()
      assert modules["test_event"] == TestEvent
      assert modules["other_event"] == OtherEvent
    end

    test "registers event versions" do
      versions = TestTranslator.event_versions()
      assert versions["test_event"] == 2
      assert versions["other_event"] == 1
    end

    test "registers migrations" do
      migrations = TestTranslator.migrations()
      assert Map.has_key?(migrations, {"test_event", 1, 2})
    end
  end

  describe "complex migrations" do
    defmodule ComplexMigrations do
      def v1_to_v2(data) do
        {:ok, Map.put(data, "v2_field", "v2")}
      end

      def v2_to_v3(data) do
        {:ok, Map.put(data, "v3_field", "v3")}
      end
    end

    defmodule ComplexTranslator do
      use GameBot.Infrastructure.Persistence.EventStore.Serialization.EventTranslator

      register_event("complex", ComplexEvent, 3)

      register_migration("complex", 1, 2, &ComplexMigrations.v1_to_v2/1)
      register_migration("complex", 2, 3, &ComplexMigrations.v2_to_v3/1)
    end

    defmodule ComplexEvent do
      defstruct [:id]
    end

    test "finds and applies migration path" do
      data = %{"original" => "value"}
      assert {:ok, migrated} = ComplexTranslator.migrate("complex", data, 1, 3)
      assert migrated["original"] == "value"
      assert migrated["v2_field"] == "v2"
      assert migrated["v3_field"] == "v3"
    end

    test "handles partial migrations" do
      data = %{"original" => "value"}
      assert {:ok, migrated} = ComplexTranslator.migrate("complex", data, 2, 3)
      assert migrated["original"] == "value"
      assert migrated["v3_field"] == "v3"
      refute Map.has_key?(migrated, "v2_field")
    end
  end

  describe "error handling in migrations" do
    defmodule ErrorMigrations do
      def v1_to_v2(_data) do
        {:error, "Migration failed"}
      end
    end

    defmodule ErrorTranslator do
      use GameBot.Infrastructure.Persistence.EventStore.Serialization.EventTranslator

      register_event("error_event", ErrorEvent, 2)

      register_migration("error_event", 1, 2, &ErrorMigrations.v1_to_v2/1)
    end

    defmodule ErrorEvent do
      defstruct [:id]
    end

    test "handles migration errors" do
      assert {:error, %Error{type: :validation}} =
        ErrorTranslator.migrate("error_event", %{}, 1, 2)
    end
  end
end
