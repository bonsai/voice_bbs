defmodule VoiceBbs.Posts do
  use GenServer

  @pubsub VoiceBbs.PubSub
  @topic "board"

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{posts: [], counter: 0}, name: __MODULE__)
  end

  def add_post(png_data) do
    GenServer.call(__MODULE__, {:add_post, png_data})
  end

  def list_posts do
    GenServer.call(__MODULE__, :list_posts)
  end

  @impl true
  def init(state) do
    uploads_dir = uploads_dir()
    File.mkdir_p!(uploads_dir)
    {:ok, state}
  end

  @impl true
  def handle_call({:add_post, png_data}, _from, state) do
    id = state.counter + 1
    filename = "#{id}.png"
    path = Path.join(uploads_dir(), filename)
    File.write!(path, png_data)

    post = %{
      id: id,
      url: "/uploads/#{filename}",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    Phoenix.PubSub.broadcast(@pubsub, @topic, {:new_post, post})

    {:reply, post, %{posts: [post | state.posts], counter: id}}
  end

  @impl true
  def handle_call(:list_posts, _from, state) do
    {:reply, state.posts, state}
  end

  defp uploads_dir do
    Path.join(:code.priv_dir(:voice_bbs), "static/uploads")
  end
end
