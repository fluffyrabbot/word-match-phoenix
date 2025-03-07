defmodule Mix.Tasks.GameBot.Migrate do
  @moduledoc """
  Runs all pending migrations for the application repositories.
  """

  use Mix.Task
  import Mix.Ecto

  @shortdoc "Runs all pending migrations"

  @doc """
  Runs all pending migrations for the application.

  ## Command line options
    * `--step` or `-n` - runs a specific number of pending migrations
    * `--repo` - runs the migrations for a specific repository
    * `--quiet` - run migrations without logging output
  """
  @impl Mix.Task
  def run(_args) do
    {:ok, _} = Application.ensure_all_started(:game_bot)

    # Run migrations for both repos
    migrate_repo()
    migrate_event_store()

    :ok
  end

  defp migrate_repo do
    repos = Application.fetch_env!(:game_bot, :ecto_repos)

    Enum.each(repos, fn repo ->
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end)
  end

  defp migrate_event_store do
    # Get event store path
    event_store_path = Application.app_dir(:game_bot, "priv/event_store")

    # Get event store config
    config = Application.get_env(:game_bot, :event_store) || []
    {:ok, conn} = EventStore.Config.parse(config, [])

    # Run migrations
    EventStore.Storage.Initializer.migrate(conn, event_store_path)
  end
end
