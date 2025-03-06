defmodule GameBot.Infrastructure.Persistence.Repo.TransactionTest do
  use GameBot.Test.RepositoryCase, async: true

  alias GameBot.Infrastructure.Persistence.Repo.Postgres
  alias GameBot.Infrastructure.Persistence.Error

  # Test schema for transaction testing
  defmodule TestSchema do
    use Ecto.Schema
    import Ecto.Changeset

    schema "test_schema" do
      field :name, :string
      field :value, :integer
      timestamps()
    end

    def changeset(struct \\ %__MODULE__{}, params) do
      struct
      |> cast(params, [:name, :value])
      |> validate_required([:name, :value])
      |> validate_length(:name, min: 3)
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

  describe "transaction boundaries" do
    test "commits all changes on success" do
      result = Postgres.transaction(fn ->
        {:ok, record1} = Postgres.insert(%TestSchema{name: "test1", value: 1})
        {:ok, record2} = Postgres.insert(%TestSchema{name: "test2", value: 2})
        [record1, record2]
      end)

      assert {:ok, [%TestSchema{}, %TestSchema{}]} = result

      # Verify both records were inserted
      assert {:ok, record1} = Postgres.get(TestSchema, 1)
      assert record1.name == "test1"
      assert {:ok, record2} = Postgres.get(TestSchema, 2)
      assert record2.name == "test2"
    end

    test "rolls back all changes on error" do
      result = Postgres.transaction(fn ->
        {:ok, _} = Postgres.insert(%TestSchema{name: "test1", value: 1})
        {:error, _} = Postgres.insert(%TestSchema{name: "t", value: 2})  # Invalid name
        :should_not_reach_here
      end)

      assert {:error, %Error{type: :validation}} = result

      # Verify neither record was inserted
      assert {:error, %Error{type: :not_found}} = Postgres.get(TestSchema, 1)
    end

    test "handles exceptions by rolling back" do
      result = Postgres.transaction(fn ->
        {:ok, _} = Postgres.insert(%TestSchema{name: "test1", value: 1})
        raise "Deliberate error"
        :should_not_reach_here
      end)

      assert {:error, %Error{}} = result

      # Verify record was not inserted
      assert {:error, %Error{type: :not_found}} = Postgres.get(TestSchema, 1)
    end

    test "respects timeout settings" do
      # Set up a transaction that will take longer than the timeout
      result = Postgres.transaction(fn ->
        {:ok, _} = Postgres.insert(%TestSchema{name: "test1", value: 1})
        Process.sleep(50)  # Sleep longer than our timeout
        :should_not_reach_here
      end, [timeout: 10])  # Very short timeout

      assert {:error, %Error{type: :timeout}} = result

      # Verify record was not inserted
      assert {:error, %Error{type: :not_found}} = Postgres.get(TestSchema, 1)
    end

    test "supports nested transactions" do
      result = Postgres.transaction(fn ->
        {:ok, record1} = Postgres.insert(%TestSchema{name: "outer", value: 1})

        inner_result = Postgres.transaction(fn ->
          {:ok, record2} = Postgres.insert(%TestSchema{name: "inner", value: 2})
          record2
        end)

        assert {:ok, %TestSchema{name: "inner"}} = inner_result
        [record1, inner_result]
      end)

      assert {:ok, [%TestSchema{name: "outer"}, {:ok, %TestSchema{name: "inner"}}]} = result

      # Verify both records were inserted
      assert {:ok, _} = Postgres.get(TestSchema, 1)
      assert {:ok, _} = Postgres.get(TestSchema, 2)
    end
  end
end
