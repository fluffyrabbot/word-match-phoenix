defmodule GameBot.Infrastructure.Persistence.EventStore.Serialization.EventTranslatorTest do
  use ExUnit.Case, async: false
  alias GameBot.Infrastructure.Error
  alias GameBot.Infrastructure.Persistence.EventStore.Serialization.EventTranslator

  # Define simple migration functions
  defmodule TestMigrations do
    def v1_to_v2(data), do: {:ok, Map.put(data, "version", 2)}
    def v2_to_v3(data), do: {:ok, Map.put(data, "version", 3)}
    def v3_to_v4(data), do: {:ok, Map.put(data, "version", 4)}
    def custom_v1_to_v2(data), do: {:ok, Map.put(data, "transformed", true)}
    def other_v1_to_v2(data), do: {:ok, Map.put(data, "other", true)}
    def error_v1_to_v2(_data), do: {:error, %Error{type: :migration_failed, message: "Migration failed"}}
  end

  # Simple migration utility
  defmodule MigrationUtil do
    def apply_migrations(data, []), do: {:ok, data}
    def apply_migrations(data, [fun | rest]) do
      case fun.(data) do
        {:ok, migrated} -> apply_migrations(migrated, rest)
        error -> error
      end
    end
  end

  # Simple event translator for testing
  defmodule SimpleTranslator do
    alias GameBot.Infrastructure.Persistence.EventStore.Serialization.EventTranslatorTest.{
      TestMigrations, MigrationUtil
    }
    alias GameBot.Infrastructure.Error

    # Migration path mapping
    def find_migration_path("test_event", 1, 2), do: {:ok, [&TestMigrations.v1_to_v2/1]}
    def find_migration_path("test_event", 2, 3), do: {:ok, [&TestMigrations.v2_to_v3/1]}
    def find_migration_path("test_event", 3, 4), do: {:ok, [&TestMigrations.v3_to_v4/1]}
    def find_migration_path("test_event", 1, 3), do:
      {:ok, [&TestMigrations.v1_to_v2/1, &TestMigrations.v2_to_v3/1]}
    def find_migration_path("test_event", 1, 4), do:
      {:ok, [&TestMigrations.v1_to_v2/1, &TestMigrations.v2_to_v3/1, &TestMigrations.v3_to_v4/1]}
    def find_migration_path("custom_event", 1, 2), do: {:ok, [&TestMigrations.custom_v1_to_v2/1]}
    def find_migration_path("other_event", 1, 2), do: {:ok, [&TestMigrations.other_v1_to_v2/1]}
    def find_migration_path("error_event", 1, 2), do: {:ok, [&TestMigrations.error_v1_to_v2/1]}
    def find_migration_path("complex_event", 1, 3), do:
      {:ok, [&TestMigrations.v1_to_v2/1, &TestMigrations.v2_to_v3/1]}
    def find_migration_path(_, _, _), do:
      {:error, %Error{type: :not_found, message: "No migration path found"}}

    # Migrate data from one version to another
    def migrate(type, data, from, to) do
      case find_migration_path(type, from, to) do
        {:ok, path} -> MigrationUtil.apply_migrations(data, path)
        error -> error
      end
    end
  end

  setup do
    {:ok, data: %{"original_data" => true, "version" => 1}}
  end

  describe "migrate/4" do
    test "applies migrations for simple cases", %{data: data} do
      assert {:ok, migrated} = SimpleTranslator.migrate("test_event", data, 1, 2)
      assert migrated["version"] == 2
    end

    test "returns error for unknown event type", %{data: data} do
      assert {:error, %Error{type: :not_found}} = SimpleTranslator.migrate("unknown_event", data, 1, 2)
    end

    test "returns error for missing migrations", %{data: data} do
      assert {:error, %Error{type: :not_found}} = SimpleTranslator.migrate("test_event", data, 1, 6)
    end

    test "actually transforms data", %{data: data} do
      assert {:ok, migrated} = SimpleTranslator.migrate("custom_event", data, 1, 2)
      assert migrated["transformed"] == true
    end

    test "can find paths across multiple versions", %{data: data} do
      assert {:ok, migrated} = SimpleTranslator.migrate("test_event", data, 1, 3)
      assert migrated["version"] == 3

      {:ok, path} = SimpleTranslator.find_migration_path("complex_event", 1, 3)
      assert length(path) == 2
    end

    test "handles migration errors", %{data: data} do
      assert {:error, %Error{type: :migration_failed}} = SimpleTranslator.migrate("error_event", data, 1, 2)
    end
  end

  # Integration tests with the actual EventTranslator module
  describe "EventTranslator real implementation" do
    test "event module registration" do
      defmodule RealTranslator do
        use EventTranslator

        register_event "real_event", __MODULE__, 1
      end

      assert Enum.member?(RealTranslator.event_modules(), {"real_event", RealTranslator})
      assert Enum.member?(RealTranslator.event_versions(), {"real_event", 1})
    end

    test "migration registration" do
      defmodule MigrationTranslator do
        use EventTranslator

        register_event "migration_event", __MODULE__, 2
        register_migration "migration_event", 1, 2, fn data -> {:ok, data} end
      end

      assert Enum.any?(MigrationTranslator.event_migrations(), fn
        {"migration_event", 1, 2, _fun} -> true
        _ -> false
      end)
    end
  end
end
