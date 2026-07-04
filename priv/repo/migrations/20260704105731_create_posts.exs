defmodule VoiceBbs.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :device_id, :string, null: false
      add :url, :string, null: false
      add :duration, :float, null: false
      add :filename, :string, null: false

      timestamps()
    end

    create index(:posts, [:device_id])
  end
end
