defmodule GameBot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      GameBotWeb.Telemetry,
      GameBot.Repo,
      {DNSCluster, query: Application.get_env(:game_bot, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: GameBot.PubSub},
      # Start a worker by calling: GameBot.Worker.start_link(arg)
      # {GameBot.Worker, arg},
      # Start to serve requests, typically the last entry
      GameBotWeb.Endpoint
    ]

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
end
