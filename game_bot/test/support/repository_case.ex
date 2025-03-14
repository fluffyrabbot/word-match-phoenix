defmodule GameBot.RepositoryCase do
  @moduledoc """
  This module defines the setup for tests requiring access to the
  repositories and database.

  It provides:
  - Sandbox setup for database transactions
  - Connection management for tests
  - Automatic cleanup between tests

  Use this module for all tests that interact with the database:

  ```
  use GameBot.RepositoryCase
  ```
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  require Logger

  # Define timeout for database operations
  @timeout 30_000

  # Define repositories to manage
  @repos [
    GameBot.Infrastructure.Persistence.Repo,
    GameBot.Infrastructure.Persistence.Repo.Postgres,
    GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
  ]

  # Define whether repositories should be started on demand
  @start_repos_on_demand true

  using do
    quote do
      alias GameBot.Infrastructure.Persistence.Repo
      alias GameBot.Infrastructure.Persistence.Repo.Postgres
      alias GameBot.Infrastructure.Persistence.EventStore
      alias GameBot.Infrastructure.Persistence.EventStore.Adapter

      import GameBot.RepositoryCase
      import Ecto.Query
    end
  end

  setup_all do
    # Ensure repositories are started
    if @start_repos_on_demand do
      ensure_all_repos_started()
    end

    # Put all repositories in shared mode for setup_all
    # This ensures connections are shared across tests
    Enum.each(@repos, fn repo ->
      Sandbox.mode(repo, :manual)
    end)

    on_exit(fn ->
      Logger.debug("Cleaning up after test suite")
    end)

    :ok
  end

  setup tags do
    pid = self()

    # For async tests, we need to allow the test process to access the sandbox
    if tags[:async] do
      Enum.each(@repos, fn repo ->
        Sandbox.allow(repo, self(), [])
      end)
    end

    # Check out connections for each repository
    repos_with_conns = checkout_connections(tags[:async])

    # For non-async tests, set up shared mode
    unless tags[:async] do
      Enum.each(@repos, fn repo ->
        Sandbox.mode(repo, {:shared, pid})
      end)
    end

    # Register cleanup callback
    on_exit(fn ->
      # Check in all connections
      checkin_connections(repos_with_conns)
    end)

    # Return checkout results to the test
    {:ok, %{repos: repos_with_conns}}
  end

  # Private functions

  # Ensures all repositories are started
  defp ensure_all_repos_started do
    Enum.each(@repos, fn repo ->
      ensure_repo_started(repo)
    end)
  end

  # Ensures a single repository is started
  defp ensure_repo_started(repo) do
    # Only start the repo if it's not already running
    unless Process.whereis(repo) do
      Logger.debug("Starting repository #{inspect(repo)} for test")

      # Get repository config
      config = Application.get_env(:game_bot, repo, [])

      # Add sandbox configuration
      config = config
               |> Keyword.put_new(:pool, Ecto.Adapters.SQL.Sandbox)
               |> Keyword.put_new(:pool_size, 5)

      # Start the repository
      case repo.start_link(config) do
        {:ok, _pid} ->
          Logger.debug("Started repository #{inspect(repo)}")
          :ok
        {:error, {:already_started, _pid}} ->
          :ok
        {:error, error} ->
          Logger.error("Failed to start repository #{inspect(repo)}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  # Checkout connections for all repositories
  defp checkout_connections(async?) do
    Enum.map(@repos, fn repo ->
      # Try to checkout a connection
      try do
        opts = if async?, do: [sandbox: false], else: []
        result = Sandbox.checkout(repo, opts)
        # Return the repo and connection status
        {repo, result}
      rescue
        e ->
          Logger.error("Error checking out connection for #{inspect(repo)}: #{inspect(e)}")
          {repo, {:error, e}}
      end
    end)
  end

  # Check in connections after test
  defp checkin_connections(repos_with_conns) do
    Enum.each(repos_with_conns, fn {repo, _conn} ->
      try do
        Sandbox.checkin(repo)
      rescue
        e ->
          Logger.warn("Error checking in #{inspect(repo)}: #{inspect(e)}")
      end
    end)
  end
end
