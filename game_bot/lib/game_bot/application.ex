defmodule GameBot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = base_children() ++ word_service_child() ++ event_children()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GameBot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GameBotWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp base_children do
    # Start the Ecto repositories
    repos = [
      GameBot.Infrastructure.Repo,
      GameBot.Infrastructure.Persistence.Repo.Postgres
    ]

    # Add EventStore if not in test environment
    repos = if Mix.env() != :test do
      repos ++ [GameBot.Infrastructure.Persistence.EventStore]
    else
      # Add the test EventStore for test environment
      repos ++ [GameBot.TestEventStore]
    end

    repos ++ [
      # Start Commanded application (which manages its own EventStore)
      GameBot.Infrastructure.CommandedApp,

      # Start the Registry for dynamic process naming
      {Registry, keys: :unique, name: GameBot.Registry},

      # Start the Telemetry supervisor
      GameBotWeb.Telemetry,

      # Start the PubSub system
      {Phoenix.PubSub, name: GameBot.PubSub},

      # Start the Endpoint (http/https)
      GameBotWeb.Endpoint
    ]
  end

  defp word_service_child do
    case Application.get_env(:game_bot, :start_word_service, true) do
      true -> [GameBot.Domain.WordService]
      false -> []
    end
  end

  defp event_children do
    [
      # Start the Event Registry
      GameBot.Domain.Events.Registry,

      # Start the Event Cache
      GameBot.Domain.Events.Cache,

      # Start the Event Processor Task Supervisor
      {Task.Supervisor, name: GameBot.EventProcessor.TaskSupervisor}
    ]
  end
end
