defmodule Mix.Tasks.GameBot.Migrate do
  @moduledoc """
  Runs all pending migrations for the application repositories and event store.
  """

  use Mix.Task
  import Mix.Ecto
  alias GameBot.Infrastructure.Persistence.EventStore, as: EventStoreDB

  @shortdoc "Runs all pending migrations"

  @impl Mix.Task
  def run(args) do
    # Start only the applications we need
    Application.ensure_all_started(:ssl)
    Application.ensure_all_started(:postgrex)
    Application.ensure_all_started(:ecto_sql)

    # Parse args
    {opts, _, _} = OptionParser.parse(args, switches: [
      step: :integer,
      repo: :string,
      quiet: :boolean
    ])

    # Run migrations for repositories (excluding EventStore)
    migrate_repo(opts)

    # Only migrate the event store in dev and prod environments
    if System.get_env("MIX_ENV") != "test" do
      # Run migrations for EventStore separately
      migrate_event_store()
      |> handle_migration_result()
    else
      # For test environment, just print status
      Mix.shell().info("Skipping EventStore migrations in test environment")
      {:ok, :skipped}
      |> handle_migration_result()
    end
  end

  defp migrate_repo(_opts) do
    # Get all repos excluding the EventStore
    repos = Application.fetch_env!(:game_bot, :ecto_repos)
    |> Enum.filter(fn repo ->
      repo != GameBot.Infrastructure.Persistence.EventStore
    end)

    Enum.each(repos, fn repo ->
      ensure_repo(repo, [])
      ensure_migrations_path(repo)
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end)
  end

  defp migrate_event_store do
    config = Application.get_env(:game_bot, EventStoreDB)

    case EventStore.Tasks.Create.exec(config) do
      :ok ->
        IO.puts("Created EventStore database")
        initialize_event_store(config)

      {:error, :already_created} ->
        IO.puts("The EventStore database already exists.")
        initialize_event_store(config)

      {:error, error} ->
        {:error, "Failed to create EventStore database: #{inspect(error)}"}
    end
  end

  defp initialize_event_store(config) do
    # Because EventStore.Tasks.Init.exec/1 will always return :ok and never :error,
    # we need to wrap this in a try-rescue to catch any potential errors
    try do
      case EventStore.Tasks.Init.exec(config) do
        :ok ->
          IO.puts("Initialized EventStore database")
          {:ok, :initialized}
      end
    rescue
      _e ->
        IO.puts("The EventStore database has already been initialized.")
        {:ok, :already_initialized}
    end
  end

  defp handle_migration_result({:ok, _}) do
    Mix.shell().info("Migrations already up")
  end

  defp handle_migration_result({:error, error}) do
    Mix.shell().error("Migration failed: #{error}")
    exit({:shutdown, 1})
  end

  defp ensure_migrations_path(_repo) do
    migrations_path = Path.join([Application.app_dir(:game_bot), "priv", "postgres", "migrations"])
    File.mkdir_p!(migrations_path)
  end
end
