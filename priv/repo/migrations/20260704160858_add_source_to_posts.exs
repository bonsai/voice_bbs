defmodule VoiceBbs.Repo.Migrations.AddSourceToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :source, :string, default: "board", null: false
    end
  end
end
