defmodule GameBot.Infrastructure.Persistence.PostgresTypes do
  @moduledoc false

  require Logger

  # Use Ecto's standard Postgres extensions
  Postgrex.Types.define(
    GameBot.Infrastructure.Persistence.PostgresTypes,
    Ecto.Adapters.Postgres.extensions(),
    json: Jason
  )
end
