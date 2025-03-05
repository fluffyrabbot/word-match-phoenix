defmodule GameBot.Infrastructure.Persistence.Repo.PostgresTest do
  use GameBot.Test.RepositoryCase, async: true

  alias GameBot.Infrastructure.Persistence.Repo.Postgres
  alias GameBot.Infrastructure.Persistence.Error

  describe "transaction/1" do
    test "successfully executes transaction"
    test "rolls back on error"
    test "handles concurrent modifications"
  end

  # ... other tests
end
