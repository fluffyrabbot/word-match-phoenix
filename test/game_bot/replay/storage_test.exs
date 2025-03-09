  # Mock the transaction function
  expect(MockRepo, :transaction, fn fun, _opts ->
    {:ok, fun.()}
  end)

  # Mock the all function to return empty list
  expect(MockRepo, :all, fn _query -> [] end)
