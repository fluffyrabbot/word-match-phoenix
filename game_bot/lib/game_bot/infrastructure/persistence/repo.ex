defmodule GameBot.Infrastructure.Persistence.Repo do
  @moduledoc """
  Main repository for the GameBot application.

  This repository handles database operations for all non-event-store entities.
  """

  use Ecto.Repo,
    otp_app: :game_bot,
    adapter: Ecto.Adapters.Postgres,
    types: EventStore.PostgresTypes

end
