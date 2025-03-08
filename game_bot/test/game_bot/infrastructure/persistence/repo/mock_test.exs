defmodule GameBot.Infrastructure.Persistence.Repo.MockTest do
  use GameBot.RepositoryCase, async: false

  alias GameBot.Infrastructure.Persistence.Repo.Postgres
  alias GameBot.Infrastructure.Persistence.Repo.MockRepo
  alias GameBot.Infrastructure.Persistence.Error, as: PersistenceError

  # Define a test schema for demonstration
  defmodule TestSchema do
    use Ecto.Schema

    schema "test_schema" do
      field :name, :string
      field :value, :integer
      timestamps()
    end
  end

  setup do
    IO.puts("In test setup, checking configured repository implementation")
    repo_impl = Application.get_env(:game_bot, :repo_implementation)
    IO.puts("Current repository implementation: #{inspect(repo_impl)}")
    :ok
  end

  setup :verify_on_exit!

  @tag :mock
  test "uses mock repository for transactions" do
    # Set up expectations - when transaction is called, execute the callback and return its result
    IO.puts("Setting up transaction mock expectation")

    # Track if the mock was called
    mock_called = :ets.new(:mock_called, [:set, :public])
    :ets.insert(mock_called, {:transaction_called, false})

    MockRepo
    |> expect(:transaction, fn callback, _opts ->
      IO.puts("Mock transaction called with callback")
      :ets.insert(mock_called, {:transaction_called, true})
      # Simulate successful transaction
      {:ok, callback.()}
    end)

    # Verify which implementation will be used
    current_impl = Application.get_env(:game_bot, :repo_implementation)
    IO.puts("Before transaction, implementation is: #{inspect(current_impl)}")

    # Execute transaction
    IO.puts("Executing transaction through Postgres module")
    result = Postgres.execute_transaction(fn ->
      IO.puts("Inside transaction callback")
      :transaction_result
    end)

    # Verify mock was called
    [{:transaction_called, was_called}] = :ets.lookup(mock_called, :transaction_called)
    IO.puts("Mock transaction was called: #{was_called}")

    # Verify results
    IO.puts("Transaction result: #{inspect(result)}")
    assert result == {:ok, :transaction_result}
    assert was_called, "The mock transaction function was not called"
  end

  @tag :mock
  test "handles error from repository in transactions" do
    # Set up expectations
    IO.puts("Setting up error transaction mock expectation")

    # Track if the mock was called
    mock_called = :ets.new(:error_mock_called, [:set, :public])
    :ets.insert(mock_called, {:transaction_called, false})

    MockRepo
    |> expect(:transaction, fn _callback, _opts ->
      IO.puts("Mock transaction returning error")
      :ets.insert(mock_called, {:transaction_called, true})
      # Simulate transaction error
      {:error, :mock_error}
    end)

    # Verify which implementation will be used
    current_impl = Application.get_env(:game_bot, :repo_implementation)
    IO.puts("Before error transaction, implementation is: #{inspect(current_impl)}")

    # Execute transaction
    IO.puts("Executing transaction that should fail")
    result = Postgres.execute_transaction(fn ->
      IO.puts("This callback should not be called")
      :should_not_reach_here
    end)

    # Verify mock was called
    [{:transaction_called, was_called}] = :ets.lookup(mock_called, :transaction_called)
    IO.puts("Mock transaction was called for error case: #{was_called}")

    # Verify results
    IO.puts("Transaction error result: #{inspect(result)}")
    assert result == {:error, :mock_error}
    assert was_called, "The mock transaction function was not called for error case"
  end

  @tag :mock
  test "uses mock repository for insert operations" do
    test_record = %TestSchema{name: "test", value: 42}

    # Track if the mock was called
    mock_called = :ets.new(:insert_mock_called, [:set, :public])
    :ets.insert(mock_called, {:insert_called, false})

    # Set up expectations
    MockRepo
    |> expect(:insert, fn _struct, _opts ->
      IO.puts("Mock insert called")
      :ets.insert(mock_called, {:insert_called, true})
      # Simulate successful insert
      {:ok, %TestSchema{id: 1, name: "test", value: 42}}
    end)

    # Verify which implementation will be used
    current_impl = Application.get_env(:game_bot, :repo_implementation)
    IO.puts("Before insert, implementation is: #{inspect(current_impl)}")

    # Execute insert
    IO.puts("Executing insert through Postgres module")
    result = Postgres.insert_record(test_record)

    # Verify mock was called
    [{:insert_called, was_called}] = :ets.lookup(mock_called, :insert_called)
    IO.puts("Mock insert was called: #{was_called}")

    # Verify results
    IO.puts("Insert result: #{inspect(result)}")
    assert {:ok, %{id: 1}} = result
    assert was_called, "The mock insert function was not called"
  end
end
