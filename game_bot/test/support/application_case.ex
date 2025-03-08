defmodule GameBot.ApplicationCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application without explicit database setup.

  Useful for integration tests that need the real application
  environment but want to control database lifecycle independently.
  """

  use ExUnit.CaseTemplate

  alias GameBot.Infrastructure.Persistence.RepositoryManager
  alias GameBot.Test.ConnectionHelper

  using do
    quote do
      # Application-level utilities
      import GameBot.ApplicationCase
    end
  end

  setup tags do
    if tags[:skip_checkout] do
      :ok
    else
      # Ensure repositories are started
      :ok = RepositoryManager.ensure_all_started()

      # Clean up when the test is done
      on_exit(fn ->
        # Don't stop repositories, just ensure connections are cleaned up
        ConnectionHelper.close_db_connections()
      end)
    end

    :ok
  end

  @doc """
  Gets the configured repository implementation.
  """
  def repository_implementation do
    Application.get_env(:game_bot, :repo_implementation, GameBot.Infrastructure.Persistence.Repo.Postgres)
  end

  @doc """
  Creates a unique identifier for testing.
  """
  def unique_id(prefix \\ "test") do
    "#{prefix}-#{System.unique_integer([:positive])}"
  end
end
