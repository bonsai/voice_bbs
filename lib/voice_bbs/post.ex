defmodule VoiceBbs.Post do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "posts" do
    field :device_id, :string
    field :url, :string
    field :duration, :float
    field :filename, :string

    timestamps()
  end

  def changeset(post, attrs) do
    import Ecto.Changeset

    post
    |> cast(attrs, [:device_id, :url, :duration, :filename])
    |> validate_required([:device_id, :url, :duration, :filename])
  end
end
