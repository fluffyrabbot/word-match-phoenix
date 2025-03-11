defmodule GameBot.ExampleRepositoryTest do
  use ExUnit.Case, async: false

setup tags do
  GameBot.Test.DatabaseManager.setup_sandbox(tags)
  :ok
end


  # Alias our Repository interface
  alias GameBot.Infrastructure.Repository
  alias GameBot.Infrastructure.Persistence.Repo.MockRepo

  import ExUnit.CaptureLog

  # Define a test schema for demonstration
  defmodule TestSchema do
    use Ecto.Schema

    schema "test_schema" do
      field :name, :string
      field :value, :integer
      timestamps()
    end
  end

  # Set up the test environment
  setup do
    # Configure repository implementation
    Application.put_env(:game_bot, :repository_implementation, MockRepo)

    # Reset any previous test state
    on_exit(fn ->
      :ok
    end)

    :ok
  end

  test "uses repository interface for transactions" do
    # The test now relies on the default implementation in MockRepo
    result = Repository.transaction(fn ->
      "transaction result"
    end)

    # Verify the result
    assert result == {:ok, "transaction result"}
  end

  test "uses repository interface for insert operations" do
    # Create a test record
    test_record = %TestSchema{name: "test", value: 42}

    # Call the Repository interface
    result = Repository.insert(test_record)

    # Verify the result matches the format from our MockRepo implementation
    assert {:ok, inserted_record} = result
    assert inserted_record.name == "test"
    assert inserted_record.value == 42
    assert is_integer(inserted_record.id) # MockRepo assigns an ID
  end

  test "uses repository interface for query operations" do
    # Override the MockRepo.one/2 function for this test using a temporary process dictionary
    original_one = :erlang.fun_to_list(&MockRepo.one/2)

    try do
      # Store a specific result for this test
      Process.put({:mock_repo, :one_result}, %TestSchema{id: 2, name: "result", value: 100})

      # Temporarily redefine MockRepo.one/2 for this test
      :meck.new(MockRepo, [:passthrough])
      :meck.expect(MockRepo, :one, fn _query, _opts ->
        Process.get({:mock_repo, :one_result})
      end)

      # Call the Repository interface
      result = Repository.one(TestSchema)

      # Verify the result
      assert %TestSchema{id: 2, name: "result"} = result
    after
      # Clean up
      Process.delete({:mock_repo, :one_result})
      :meck.unload(MockRepo)
    end
  end

  test "handles error cases through repository interface" do
    # We need to temporarily override the default implementation for this test
    :meck.new(MockRepo, [:passthrough])
    :meck.expect(MockRepo, :transaction, fn _fun, _opts -> {:error, :mock_error} end)

    try do
      # Call the Repository interface
      result = Repository.transaction(fn ->
        :should_not_reach_here
      end)

      # Verify the error result
      assert result == {:error, :mock_error}
    after
      :meck.unload(MockRepo)
    end
  end
end
