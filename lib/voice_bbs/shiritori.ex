defmodule VoiceBbs.Shiritori do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "shiritori" do
    field :word, :string
    field :kana, :string
    field :audio_url, :string
    field :device_id, :string
    field :position, :integer, default: 0
    field :prev_id, :string

    timestamps()
  end

  def changeset(shiritori, attrs) do
    import Ecto.Changeset

    shiritori
    |> cast(attrs, [:word, :kana, :audio_url, :device_id, :position, :prev_id])
    |> validate_required([:word, :kana, :device_id, :position])
  end
end
