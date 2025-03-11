defmodule GameBot.Infrastructure.Persistence.EventStore do
  @moduledoc """
  EventStore implementation for the application.
  Provides event storage and retrieval capabilities.
  """

  use EventStore, otp_app: :game_bot

  @doc """
  Initializes the event store with the given configuration.
  Allows for runtime customization of configuration.
  """
  @impl true
  def init(config) do
    # You can modify config here if needed
    {:ok, config}
  end

  # Additional functions can be added here to extend EventStore functionality
end
