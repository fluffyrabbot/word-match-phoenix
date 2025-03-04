defmodule GameBot.Infrastructure.CommandedApp do
  @moduledoc """
  Commanded application for GameBot.
  Provides event sourcing and CQRS functionality using Commanded.
  """

  use Commanded.Application,
    otp_app: :game_bot

  # Runtime configuration callback
  def init(config) do
    {:ok, config}
  end
end
