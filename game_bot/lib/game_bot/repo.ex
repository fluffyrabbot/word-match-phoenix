defmodule GameBot.Repo do
  use Ecto.Repo,
    otp_app: :game_bot,
    adapter: Ecto.Adapters.Postgres
end
