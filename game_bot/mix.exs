defmodule GameBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :game_bot,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {GameBot.Application, []},
      extra_applications: [:logger, :runtime_tools, :eventstore],
      included_applications: (if Mix.env() == :test, do: [:nostrum], else: [])
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.10"},
      {:phoenix_ecto, "~> 4.4.3"},
      {:ecto_sql, "~> 3.10.2"},
      {:postgrex, "~> 0.17.4"},
      {:phoenix_html, "~> 3.3.3"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.20.2"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.8.0", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.3"},
      {:hackney, "~> 1.9"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.0-pre"},
      {:nostrum, "~> 0.10.0"},
      {:commanded, "~> 1.4.1"},
      {:commanded_eventstore_adapter, "~> 1.4.0"},
      {:eventstore, "~> 1.4.0"},
      {:telemetry, "~> 1.2.0"},
      {:telemetry_registry, "~> 0.3.0"},
      {:libgraph, "~> 0.16.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:mock, "~> 0.3.0", only: :test},
      {:benchee, "~> 1.1", only: [:dev, :test]},
      {:benchee_html, "~> 1.0", only: [:dev, :test]},
      {:stream_data, "~> 0.5", only: [:dev, :test]},
      {:mox, "~> 1.1", only: :test}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "event_store.setup", "assets.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],

      # Test aliases
      test: [
        "test.reset_db",
        "test"
      ],
      "test.reset_db": [
        "ecto.drop --quiet",
        "ecto.create --quiet",
        "ecto.migrate --quiet",
        "game_bot.event_store_setup"
      ],

      # Event store operations
      "event_store.setup": [
        "event_store.create",
        "event_store.init"
      ],
      "event_store.reset": ["event_store.drop", "event_store.setup"],

      # Asset operations
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end
