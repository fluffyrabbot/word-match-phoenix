defmodule GameBot.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use GameBot.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias GameBot.Infrastructure.Persistence.RepositoryManager
  alias GameBot.Test.ConnectionHelper

  using do
    quote do
      alias GameBot.Infrastructure.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import GameBot.DataCase
    end
  end

  setup tags do
    # Close connections before the test and ensure repositories are started
    ConnectionHelper.close_db_connections()

    # Ensure all repositories are started
    :ok = RepositoryManager.ensure_all_started()

    # Setup the sandbox using our custom function
    GameBot.DataCase.setup_sandbox(tags)

    # Register cleanup
    on_exit(fn ->
      ConnectionHelper.close_db_connections()
    end)

    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    # Start owner with better error handling
    try do
      pid = Ecto.Adapters.SQL.Sandbox.start_owner!(GameBot.Infrastructure.Repo, shared: not tags[:async])
      on_exit(fn ->
        try do
          Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
        rescue
          e -> IO.puts("Warning: Failed to stop owner: #{inspect(e)}")
        end
      end)
    rescue
      e ->
        IO.puts("Error setting up sandbox: #{inspect(e)}")
        # Try to ensure repo is started and retry once
        RepositoryManager.ensure_started(GameBot.Infrastructure.Repo)
        pid = Ecto.Adapters.SQL.Sandbox.start_owner!(GameBot.Infrastructure.Repo, shared: not tags[:async])
        on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    end
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
