defmodule GameBot.Infrastructure.Persistence.Repo.PostgresTest do
  use GameBot.Test.RepositoryCase, async: true

  alias GameBot.Infrastructure.Persistence.Repo.Postgres
  alias GameBot.Infrastructure.Persistence.Error
  alias Ecto.Changeset

  # Test schema for repository operations
  defmodule TestSchema do
    use Ecto.Schema

    schema "test_schema" do
      field :name, :string
      field :value, :integer
      timestamps()
    end

    def changeset(struct \\ %__MODULE__{}, params) do
      struct
      |> Changeset.cast(params, [:name, :value])
      |> Changeset.validate_required([:name, :value])
      |> Changeset.validate_length(:name, min: 3)
    end
  end

  setup do
    # Create test table
    Postgres.query!("CREATE TABLE IF NOT EXISTS test_schema (
      id SERIAL PRIMARY KEY,
      name VARCHAR(255) NOT NULL,
      value INTEGER NOT NULL,
      inserted_at TIMESTAMP NOT NULL,
      updated_at TIMESTAMP NOT NULL
    )")

    on_exit(fn ->
      Postgres.query!("DROP TABLE IF EXISTS test_schema")
    end)

    :ok
  end

  describe "transaction/1" do
    test "successfully executes transaction" do
      result = Postgres.transaction(fn ->
        {:ok, record} = Postgres.insert(%TestSchema{name: "test", value: 1})
        record
      end)

      assert {:ok, %TestSchema{name: "test"}} = result
    end

    test "rolls back on error" do
      result = Postgres.transaction(fn ->
        {:ok, _} = Postgres.insert(%TestSchema{name: "test1", value: 1})
        {:error, _} = Postgres.insert(%TestSchema{name: "t", value: 2})  # Invalid name
      end)

      assert {:error, %Error{type: :validation}} = result
      assert {:error, %Error{type: :not_found}} =
        Postgres.get(TestSchema, 1)
    end

    test "handles nested transactions" do
      result = Postgres.transaction(fn ->
        Postgres.transaction(fn ->
          {:ok, record} = Postgres.insert(%TestSchema{name: "nested", value: 1})
          record
        end)
      end)

      assert {:ok, %TestSchema{name: "nested"}} = result
    end
  end

  describe "insert/2" do
    test "successfully inserts valid record" do
      assert {:ok, record} = Postgres.insert(%TestSchema{name: "test", value: 1})
      assert record.id != nil
      assert record.name == "test"
    end

    test "handles validation errors" do
      assert {:error, %Error{type: :validation}} =
        Postgres.insert(%TestSchema{name: "t", value: 1})
    end

    test "handles constraint violations" do
      {:ok, _} = Postgres.insert(%TestSchema{name: "unique", value: 1})
      assert {:error, %Error{type: :validation}} =
        Postgres.insert(%TestSchema{name: "unique", value: 1})
    end
  end

  describe "update/2" do
    test "successfully updates record" do
      {:ok, record} = Postgres.insert(%TestSchema{name: "test", value: 1})

      assert {:ok, updated} = Postgres.update(
        Changeset.change(record, value: 2)
      )
      assert updated.value == 2
    end

    test "handles concurrent modifications" do
      {:ok, record} = Postgres.insert(%TestSchema{name: "test", value: 1})
      stale_record = record

      {:ok, _} = Postgres.update(Changeset.change(record, value: 2))
      assert {:error, %Error{type: :concurrency}} =
        Postgres.update(Changeset.change(stale_record, value: 3))
    end
  end

  describe "delete/2" do
    test "successfully deletes record" do
      {:ok, record} = Postgres.insert(%TestSchema{name: "test", value: 1})
      assert {:ok, _} = Postgres.delete(record)
      assert {:error, %Error{type: :not_found}} = Postgres.get(TestSchema, record.id)
    end

    test "handles concurrent deletions" do
      {:ok, record} = Postgres.insert(%TestSchema{name: "test", value: 1})
      {:ok, _} = Postgres.delete(record)
      assert {:error, %Error{type: :concurrency}} = Postgres.delete(record)
    end
  end
end
