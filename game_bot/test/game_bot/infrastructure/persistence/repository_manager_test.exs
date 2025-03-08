defmodule GameBot.Infrastructure.Persistence.RepositoryManagerTest do
  use ExUnit.Case, async: false

  alias GameBot.Infrastructure.Persistence.RepositoryManager
  alias GameBot.Infrastructure.Persistence.Repo
  alias GameBot.Infrastructure.Persistence.Repo.Postgres
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres, as: EventStore

  # Skip sandbox setup for this test since we're managing repositories directly
  @moduletag :skip_checkout

  # Setup and teardown
  setup do
    # Store original repos if they're running
    original_repo_pid = Process.whereis(Repo)
    original_postgres_pid = Process.whereis(Postgres)
    original_event_store_pid = Process.whereis(EventStore)

    # Stop all repositories for a clean test environment
    stop_all_repositories()

    # Test cleanup
    on_exit(fn ->
      # Stop any repositories started during the test
      stop_all_repositories()

      # Restore original repositories if they were running
      if original_repo_pid != nil, do: start_and_wait(Repo)
      if original_postgres_pid != nil, do: start_and_wait(Postgres)
      if original_event_store_pid != nil, do: start_and_wait(EventStore)
    end)

    :ok
  end

  test "ensure_all_started starts all repositories" do
    # Confirm all repos are stopped
    assert Process.whereis(Repo) == nil
    assert Process.whereis(Postgres) == nil
    assert Process.whereis(EventStore) == nil

    # Start all repos
    assert :ok = RepositoryManager.ensure_all_started()

    # Verify each repo is running
    assert Process.whereis(Repo) != nil
    assert Process.whereis(Postgres) != nil
    assert Process.whereis(EventStore) != nil
  end

  test "ensure_started starts a single repository" do
    # Confirm repo is stopped
    assert Process.whereis(Repo) == nil

    # Start just one repo
    assert :ok = RepositoryManager.ensure_started(Repo)

    # Verify only that repo is running
    assert Process.whereis(Repo) != nil
    assert Process.whereis(Postgres) == nil  # Should still be stopped
  end

  test "reset_all stops and restarts all repositories" do
    # Start all repositories first
    RepositoryManager.ensure_all_started()
    Process.sleep(100)  # Allow time for startup

    # Get the current PIDs
    repo_pid = Process.whereis(Repo)
    postgres_pid = Process.whereis(Postgres)
    event_store_pid = Process.whereis(EventStore)

    # Make sure they're actually running
    assert repo_pid != nil
    assert postgres_pid != nil
    assert event_store_pid != nil

    # Reset all
    assert :ok = RepositoryManager.reset_all()
    Process.sleep(100)  # Allow time for restart

    # Verify all are running but with different PIDs
    assert Process.whereis(Repo) != nil
    assert Process.whereis(Postgres) != nil
    assert Process.whereis(EventStore) != nil

    # Check they're different processes
    assert Process.whereis(Repo) != repo_pid
    assert Process.whereis(Postgres) != postgres_pid
    assert Process.whereis(EventStore) != event_store_pid
  end

  test "stop_all stops all repositories" do
    # Make sure all are started first
    RepositoryManager.ensure_all_started()
    Process.sleep(100)  # Allow time for startup

    # Verify they're running
    assert Process.whereis(Repo) != nil
    assert Process.whereis(Postgres) != nil
    assert Process.whereis(EventStore) != nil

    # Stop all
    assert :ok = RepositoryManager.stop_all()
    Process.sleep(100)  # Allow time for shutdown

    # Verify all are stopped
    assert Process.whereis(Repo) == nil
    assert Process.whereis(Postgres) == nil
    assert Process.whereis(EventStore) == nil
  end

  # Helper functions

  defp stop_all_repositories do
    stop_repository(Repo)
    stop_repository(Postgres)
    stop_repository(EventStore)

    # Allow time for shutdown
    Process.sleep(100)
  end

  defp stop_repository(repo) do
    case Process.whereis(repo) do
      nil -> :ok
      pid ->
        try do
          GenServer.stop(pid, :normal, 5000)
        catch
          :exit, _ -> :ok
        end
    end
  end

  defp start_and_wait(repo) do
    config = Application.get_env(:game_bot, repo, [])
    {:ok, _} = repo.start_link(config)
    Process.sleep(100)  # Allow time for startup
  end
end
