defmodule GameBot.Infrastructure.Persistence.EventStore do
  @moduledoc """
  Event store implementation for GameBot.

  This module provides the main entry point for the event store functionality,
  implementing the EventStore behavior and delegating to the configured adapter.
  """

  use EventStore, otp_app: :game_bot

  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres

  @doc """
  Initializes the event store with the given configuration.
  Allows for runtime customization of configuration.
  """
  @impl true
  def init(config) do
    # You can modify config here if needed
    {:ok, config}
  end
end
