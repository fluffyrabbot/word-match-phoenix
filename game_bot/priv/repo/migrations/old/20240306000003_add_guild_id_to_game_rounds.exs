defmodule GameBot.Repo.Migrations.AddGuildIdToGameRounds do
  use Ecto.Migration

  def change do
    alter table(:game_rounds) do
      add :guild_id, :string, null: false
    end
  end
end
