defmodule GameBot.Infrastructure.Persistence.RepositoryManager do
  @moduledoc """
  Manages repository initialization and setup for both runtime and tests.

  This module provides functions to ensure repositories are properly started
  and configured, especially in test environments where connection issues
  can be problematic.
  """

  require Logger

  # The list of repositories that need to be started
  @repositories [
    GameBot.Infrastructure.Persistence.Repo,
    GameBot.Infrastructure.Persistence.Repo.Postgres,
    GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
  ]

  @doc """
  Starts all required repositories if they are not already started.
  Returns :ok if successful or {:error, reason} if there was a problem.
  """
  def ensure_all_started do
    Enum.reduce_while(@repositories, :ok, fn repo, _acc ->
      case ensure_started(repo) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Ensures a single repository is started.
  """
  def ensure_started(repo) do
    case start_repo(repo) do
      {:ok, _pid} ->
        Logger.info("Started repository: #{inspect(repo)}")
        :ok
      {:error, {:already_started, _pid}} ->
        Logger.debug("Repository already started: #{inspect(repo)}")
        :ok
      {:error, reason} ->
        Logger.error("Failed to start repository #{inspect(repo)}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Stops all repositories.
  """
  def stop_all do
    Enum.each(@repositories, &stop_repo/1)
    :ok
  end

  @doc """
  Resets the state of repositories, useful for tests.
  """
  def reset_all do
    stop_all()
    ensure_all_started()
  end

  # Private functions

  defp start_repo(repo) do
    # Get configuration from application environment
    config = Application.get_env(:game_bot, repo, [])

    # Start the repository
    repo.start_link(config)
  end

  defp stop_repo(repo) do
    case Process.whereis(repo) do
      nil -> :ok
      pid ->
        # Try to stop the repository gracefully
        GenServer.stop(pid, :normal, 5000)
    end
  end
end
