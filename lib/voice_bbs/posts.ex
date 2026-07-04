defmodule VoiceBbs.Posts do
  use GenServer

  @pubsub VoiceBbs.PubSub
  @topic "board"
  @max_per_device 4

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def add_post(device_id, png_data, duration_sec) do
    GenServer.call(__MODULE__, {:add_post, device_id, png_data, duration_sec})
  end

  def list_posts do
    GenServer.call(__MODULE__, :list_posts)
  end

  def count_by_device(device_id) do
    GenServer.call(__MODULE__, {:count_by_device, device_id})
  end

  def max_per_device, do: @max_per_device

  @impl true
  def init(state) do
    uploads_dir = uploads_dir()
    File.mkdir_p!(uploads_dir)
    {:ok, state}
  end

  import Ecto.Query, only: [where: 2, order_by: 2]

  @impl true
  def handle_call({:add_post, device_id, png_data, duration_sec}, _from, state) do
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
      path = Path.join(uploads_dir(), filename)
      File.write!(path, png_data)

      dur = round(duration_sec * 10) / 10

      {:ok, post_schema} = VoiceBbs.Repo.insert(%VoiceBbs.Post{
        id: id,
        device_id: device_id,
        url: "/uploads/#{filename}",
        duration: dur,
        filename: filename
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
  def handle_call({:count_by_device, device_id}, _from, state) do
    count = VoiceBbs.Repo.aggregate(
      where(VoiceBbs.Post, device_id: ^device_id),
      :count,
      :id
    )
    {:reply, count, state}
  end

  defp uploads_dir do
    Path.join(:code.priv_dir(:voice_bbs), "static/uploads")
  end
end
