defmodule Mix.Tasks.GameBot.Migrate do
  @moduledoc """
  Runs all pending migrations for the application repositories.
  """

  use Mix.Task
  import Mix.Ecto

  @shortdoc "Runs pending migrations"

  @doc """
  Runs all pending migrations for the application.

  ## Command line options
    * `--step` or `-n` - runs a specific number of pending migrations
    * `--repo` - runs the migrations for a specific repository
    * `--quiet` - run migrations without logging output
  """
  def run(args) do
    repos = parse_repo(args)
    migrations_path = Path.join(["priv", "repo", "migrations"])

    # Get options from command line
    {opts, _, _} = OptionParser.parse(args, strict: [
      all: :boolean,
      step: :integer,
      to: :integer,
      quiet: :boolean,
      prefix: :string
    ], aliases: [n: :step])

    # Start all repositories
    {:ok, _} = Application.ensure_all_started(:ecto)
    {:ok, _} = Application.ensure_all_started(:ecto_sql)

    for repo <- repos do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, fn repo ->
        Ecto.Migrator.run(repo, migrations_path, :up, opts)
      end)
    end

    # Load the event store migration if available
    event_store_path = Path.join(["priv", "event_store", "migrations"])

    if File.dir?(event_store_path) do
      Mix.shell().info("Running EventStore migrations...")
      {:ok, _} = Application.ensure_all_started(:eventstore)
      config = EventStore.Config.parsed(Application.get_env(:game_bot, :event_store) || [])

      # Run EventStore migrations
      EventStore.Tasks.Migrate.run(config, event_store_path)
    end

    Mix.shell().info("All migrations completed successfully!")
  end
end
