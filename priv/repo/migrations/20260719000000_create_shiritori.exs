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
      add :prev_id, :string

      timestamps()
    end

    create index(:shiritori, [:position])
  end
end
