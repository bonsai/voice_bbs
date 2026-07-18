defmodule VoiceBbs.Posts do
  use GenServer

  @pubsub VoiceBbs.PubSub
  @topic "board"
  @max_per_device 4

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def add_post(device_id, png_data, duration_sec, source \\ "board", room_id \\ nil) do
    GenServer.call(__MODULE__, {:add_post, device_id, png_data, duration_sec, source, room_id})
  end

  def list_posts do
    GenServer.call(__MODULE__, :list_posts)
  end

  def delete_post(id) do
    GenServer.call(__MODULE__, {:delete_post, id})
  end

  def get_post(id) do
    VoiceBbs.Repo.get(VoiceBbs.Post, id)
  end

  def count_by_device(device_id) do
    GenServer.call(__MODULE__, {:count_by_device, device_id})
  end

  def max_per_device, do: @max_per_device

  @impl true
  def init(state) do
    unless gcs_bucket() do
      uploads_dir = uploads_dir()
      File.mkdir_p!(uploads_dir)
    end
    {:ok, state}
  end

  import Ecto.Query, only: [where: 2, order_by: 2]

  @impl true
  def handle_call({:add_post, device_id, png_data, duration_sec, source, room_id}, _from, state) do
    count = VoiceBbs.Repo.aggregate(
      where(VoiceBbs.Post, device_id: ^device_id),
      :count,
      :id
    )

    if count >= @max_per_device do
      {:reply, {:error, :limit_reached}, state}
    else
      id = Ecto.UUID.generate()
      filename = "#{id}.png"

      url =
        if gcs_bucket() do
          upload_to_gcs(filename, png_data)
        else
          path = Path.join(uploads_dir(), filename)
          File.write!(path, png_data)
          "/uploads/#{filename}"
        end

      dur = round(duration_sec * 10) / 10

      {:ok, post_schema} = VoiceBbs.Repo.insert(%VoiceBbs.Post{
        id: id,
        device_id: device_id,
        url: url,
        duration: dur,
        filename: filename,
        source: source,
        room_id: room_id
      })

      Phoenix.PubSub.broadcast(@pubsub, @topic, {:new_post, post_schema})

      {:reply, {:ok, post_schema}, state}
    end
  end

  @impl true
  def handle_call(:list_posts, _from, state) do
    posts = VoiceBbs.Repo.all(order_by(VoiceBbs.Post, desc: :inserted_at))
    {:reply, posts, state}
  end

  @impl true
  def handle_call({:delete_post, id}, _from, state) do
    post = VoiceBbs.Repo.get!(VoiceBbs.Post, id)

    if gcs_bucket() do
      delete_from_gcs(post.filename)
    else
      path = Path.join(uploads_dir(), post.filename)
      File.rm(path)
    end

    VoiceBbs.Repo.delete!(post)
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:delete_post, id})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:count_by_device, device_id}, _from, state) do
    count = VoiceBbs.Repo.aggregate(
      where(VoiceBbs.Post, device_id: ^device_id),
      :count,
      :id
    )
    {:reply, count, state}
  end

  defp upload_to_gcs(filename, png_data) do
    bucket = gcs_bucket()
    url = "https://storage.googleapis.com/upload/storage/v1/b/#{bucket}/o?uploadType=media&name=#{filename}"

    {:ok, token} = Goth.Token.for_scope(VoiceBbs.Goth, "https://www.googleapis.com/auth/cloud-platform")

    {:ok, resp} =
      Req.post(url,
        body: png_data,
        headers: [
          {"authorization", "Bearer #{token.token}"},
          {"content-type", "image/png"}
        ]
      )

    "https://storage.googleapis.com/#{bucket}/#{filename}"
  end

  defp delete_from_gcs(filename) do
    bucket = gcs_bucket()
    url = "https://storage.googleapis.com/storage/v1/b/#{bucket}/o/#{filename}"

    {:ok, token} = Goth.Token.for_scope(VoiceBbs.Goth, "https://www.googleapis.com/auth/cloud-platform")
    Req.delete(url, headers: [{"authorization", "Bearer #{token.token}"}])
    :ok
  end

  defp gcs_bucket do
    System.get_env("GCS_BUCKET")
  end

  defp uploads_dir do
    System.get_env("UPLOADS_DIR") || Path.join(:code.priv_dir(:voice_bbs), "static/uploads")
  end
end
