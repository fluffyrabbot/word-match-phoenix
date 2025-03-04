defmodule GameBot.Infrastructure.EventStore do
  @moduledoc """
  EventStore implementation for GameBot.
  This module provides the event store process for event sourcing.
  """

  use EventStore, otp_app: :game_bot

  def init(config) do
    # You can modify config here if needed
    {:ok, config}
  end
end
