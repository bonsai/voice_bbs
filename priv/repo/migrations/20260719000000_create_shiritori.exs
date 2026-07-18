defmodule VoiceBbs.Repo.Migrations.CreateShiritori do
  use Ecto.Migration

  def change do
    create table(:shiritori, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :word, :string, null: false
      add :kana, :string, null: false
      add :audio_url, :string
      add :device_id, :string, null: false
      add :position, :integer, null: false, default: 0
      add :prev_id, references(:shiritori, type: :binary_id, on_delete: :nilify)

      timestamps()
    end

    create index(:shiritori, [:prev_id])
    create index(:shiritori, [:position])
  end
end
