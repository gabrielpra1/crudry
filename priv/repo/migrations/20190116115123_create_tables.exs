defmodule Crudry.Repo.Migrations.CreateTables do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :username, :string

      timestamps()
    end

    create table(:posts) do
      add :user_id, references(:users)
      add :title, :string

      timestamps()
    end
  end
end
