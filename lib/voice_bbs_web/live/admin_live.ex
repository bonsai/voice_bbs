defmodule VoiceBbsWeb.AdminLive do
  use VoiceBbsWeb, :live_view

  @topic "board"

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(VoiceBbs.PubSub, @topic)
    end

    posts = VoiceBbs.Posts.list_posts()

    {:ok,
     socket
     |> assign(:posts, posts)
     |> assign(:playing, nil)
     |> assign(:current_index, nil)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    VoiceBbs.Posts.delete_post(id)
    posts = VoiceBbs.Posts.list_posts()
    {:noreply, assign(socket, :posts, posts)}
  end

  @impl true
  def handle_event("play-all", _params, socket) do
    {:noreply, push_event(socket, "play-sequence", %{urls: Enum.map(socket.assigns.posts, & &1.url)})}
  end

  @impl true
  def handle_info({:new_post, _post}, socket) do
    posts = VoiceBbs.Posts.list_posts()
    {:noreply, assign(socket, :posts, posts)}
  end

  @impl true
  def handle_info({:delete_post, _id}, socket) do
    posts = VoiceBbs.Posts.list_posts()
    {:noreply, assign(socket, :posts, posts)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-dvh bg-gradient-to-b from-purple-50 to-white font-sans p-4 max-w-2xl mx-auto select-none">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-xl font-bold text-purple-600">admin</h1>
        <div class="flex gap-2">
          <button phx-click="play-all" class="text-xs bg-purple-500 text-white px-3 py-1.5 rounded-full hover:bg-purple-600 transition">
            全再生
          </button>
          <span class="text-xs text-purple-400/50 self-center"><%= length(@posts) %>件</span>
        </div>
      </div>

      <div id="posts-list" class="space-y-2">
        <%= for {post, idx} <- Enum.with_index(@posts) do %>
          <div class="bg-white rounded-xl shadow-sm border border-purple-100/50 p-3 flex items-center gap-3">
            <span class="text-[10px] text-purple-300/50 w-5 text-right"><%= idx + 1 %></span>

            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <button
                  phx-click={JS.dispatch("play-admin-audio", detail: %{url: post.url})}
                  class="w-8 h-8 rounded-full bg-purple-100 flex items-center justify-center hover:bg-purple-200 transition flex-shrink-0"
                >
                  <svg class="w-4 h-4 text-purple-500" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M8 5v14l11-7z"/>
                  </svg>
                </button>
                <span class="text-xs text-purple-400/70 truncate"><%= post.url %></span>
              </div>
              <div class="text-[10px] text-purple-300/40 mt-0.5 flex gap-3">
                <span><%= post.duration %>s</span>
                <span class="truncate"><%= String.slice(post.device_id, 0..7) %></span>
                <span><%= post.inserted_at %></span>
              </div>
            </div>

            <button
              phx-click="delete"
              phx-value-id={post.id}
              data-confirm="削除する?"
              class="w-7 h-7 rounded-full bg-red-50 flex items-center justify-center hover:bg-red-100 transition flex-shrink-0"
            >
              <svg class="w-3.5 h-3.5 text-red-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>
        <% end %>
      </div>

      <div :if={@posts == []} class="text-center text-purple-300/40 text-sm mt-20">投稿なし</div>
    </div>
    """
  end
end
