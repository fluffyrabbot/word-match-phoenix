defmodule GameBot.RepositoryCase do
  @moduledoc """
  This module defines common utilities for testing repositories.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias GameBot.Infrastructure.Persistence.Repo
      alias GameBot.Infrastructure.Persistence.Repo.Postgres
      alias GameBot.Infrastructure.Persistence.Repo.MockRepo
      import Ecto
      import Ecto.Query
      import GameBot.RepositoryCase
      # Import Mox for setting up expectations
      import Mox
    end
  end

  # This function checks if the current module is tagged with :mock
  # It will be called by the setup function to determine if we should use the mock repo
  defp mock_test?(tags) do
    # First check if the individual test has the mock tag
    test_has_mock = tags[:mock] == true

    # Then check if the module has the mock tag
    module_has_mock = case tags[:registered] do
      %{} = registered ->
        registered[:mock] == true
      _ -> false
    end

    # Log for debugging
    IO.puts("Mock detection - Test tag: #{test_has_mock}, Module tag: #{module_has_mock}")

    # Return true if either the test or the module has the mock tag
    test_has_mock || module_has_mock
  end

  setup tags do
    IO.puts("Repository case setup - tags: #{inspect(tags)}")

    # Set application env for repository implementation
    # For mock tests, we use the MockRepo
    # Use our improved mock detection function
    if mock_test?(tags) do
      # First clear any previous setting to avoid stale configurations
      Application.delete_env(:game_bot, :repo_implementation)

      # Then set the mock implementation
      IO.puts("Setting up mock test - configuring MockRepo")
      Application.put_env(:game_bot, :repo_implementation, GameBot.Infrastructure.Persistence.Repo.MockRepo)

      # Verify the configuration was set correctly
      repo_impl = Application.get_env(:game_bot, :repo_implementation)
      IO.puts("Repository implementation set to: #{inspect(repo_impl)}")

      # Only pass the TestServer pid if it exists
      test_server = Process.whereis(GameBot.TestServer)
      if test_server do
        IO.puts("TestServer exists, adding to allowed processes")
        Mox.allow(GameBot.Infrastructure.Persistence.Repo.MockRepo, self(), test_server)
      else
        IO.puts("TestServer does not exist, only allowing test process")
        Mox.set_mox_global(GameBot.Infrastructure.Persistence.Repo.MockRepo)
        Mox.verify_on_exit!()
      end
    else
      # For regular tests, use the actual Postgres repo
      IO.puts("Setting up real repository test (no mock tag) - using Postgres")
      Application.put_env(:game_bot, :repo_implementation, GameBot.Infrastructure.Persistence.Repo.Postgres)

      # Set up the main repository
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(GameBot.Infrastructure.Persistence.Repo)

      unless tags[:async] do
        Ecto.Adapters.SQL.Sandbox.mode(GameBot.Infrastructure.Persistence.Repo, {:shared, self()})
      end

      # Set up the Postgres repository
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(GameBot.Infrastructure.Persistence.Repo.Postgres)

      unless tags[:async] do
        Ecto.Adapters.SQL.Sandbox.mode(GameBot.Infrastructure.Persistence.Repo.Postgres, {:shared, self()})
      end
    end

    # Start the test event store if not already started
    case Process.whereis(GameBot.TestEventStore) do
      nil ->
        {:ok, pid} = GameBot.TestEventStore.start_link()
        on_exit(fn ->
          if Process.alive?(pid) do
            GameBot.TestEventStore.stop(GameBot.TestEventStore)
          end
        end)
      pid ->
        # Reset state if store already exists
        GameBot.TestEventStore.set_failure_count(0)
        # Clear any existing streams
        :sys.replace_state(pid, fn _ -> %GameBot.TestEventStore.State{} end)
    end

    :ok
  end

  @doc """
  Creates a test event for serialization testing.
  """
  def build_test_event(attrs \\ %{}) do
    Map.merge(%{
      event_type: "test_event",
      event_version: 1,
      data: %{
        game_id: "game-#{System.unique_integer([:positive])}",
        mode: :test,
        round_number: 1,
        timestamp: DateTime.utc_now()
      }
    }, attrs)
  end

  @doc """
  Creates a unique stream ID for testing.
  """
  def unique_stream_id do
    "test-stream-#{System.unique_integer([:positive])}"
  end
end
