defmodule VoiceBbs.Repo.Migrations.AddRoomIdToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :room_id, :binary_id
    end
    create index(:posts, [:room_id])
  end
end
