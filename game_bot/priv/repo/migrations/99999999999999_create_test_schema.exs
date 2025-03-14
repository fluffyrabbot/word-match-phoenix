defmodule GameBot.Repo.Migrations.CreateTestSchema do
  use Ecto.Migration

  def change do
    # Create a test schema table that test cases are looking for
    create table(:test_schema) do
      add :name, :string
      add :value, :string
      timestamps()
    end
  end
end
