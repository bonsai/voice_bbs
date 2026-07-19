defmodule VoiceBbsWeb.ManageLive do
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
     |> assign(:db_status, "checking...")
     |> assign(:mic_status, "-")
     |> assign(:panel_open, false)
     |> assign(:error_msg, nil)
     |> assign(:active_tab, "posts")
     |> assign(:rooms, list_rooms())
     |> refresh_stats()}
  end

  @impl true
  def handle_event("toggle-panel", _params, socket) do
    {:noreply, update(socket, :panel_open, &(!&1))}
  end

  @impl true
  def handle_event("switch-tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("check-db", _params, socket) do
    {:noreply, refresh_stats(socket)}
  end

  @impl true
  def handle_event("mic-test", _params, socket) do
    {:noreply, push_event(socket, "test-mic", %{})}
  end

  @impl true
  def handle_event("mic-result", %{"ok" => ok}, socket) do
    {:noreply, assign(socket, :mic_status, if(ok, do: "OK", else: "NG"))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    VoiceBbs.Posts.delete_post(id)
    posts = VoiceBbs.Posts.list_posts()
    {:noreply, assign(socket, :posts, posts)}
  end

  @impl true
  def handle_event("play-all", _params, socket) do
    urls = Enum.map(socket.assigns.posts, & &1.url)
    {:noreply, push_event(socket, "play-sequence", %{urls: urls})}
  end

  @impl true
  def handle_event("toggle-room", %{"id" => id}, socket) do
    rooms = list_rooms()
    rooms = Enum.map(rooms, fn r ->
      if r["id"] == id, do: Map.update(r, "open", true, &(!&1)), else: r
    end)
    write_rooms(rooms)
    {:noreply, assign(socket, :rooms, rooms)}
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

  defp refresh_stats(socket) do
    socket
    |> assign(:db_status, check_db())
    |> assign(:post_count, count_posts())
  end

  defp check_db do
    VoiceBbs.Repo.query!("SELECT 1")
    "OK"
  rescue
    _ -> "NG"
  end

  defp count_posts do
    length(VoiceBbs.Posts.list_posts())
  rescue
    _ -> 0
  end

  defp tab_class(active, tab) when active == tab,
    do: "flex-1 py-2.5 text-xs font-medium transition text-purple-600 border-b-2 border-purple-500"
  defp tab_class(_, _),
    do: "flex-1 py-2.5 text-xs font-medium transition text-purple-400/50"

  defp status_color("OK"), do: "text-[11px] font-medium text-green-500"
  defp status_color(_), do: "text-[11px] font-medium text-red-400"

  defp list_rooms do
    path = Path.join(:code.priv_dir(:voice_bbs), "../rooms.json")
    if File.exists?(path) do
      path |> File.read!() |> Jason.decode!() |> Map.get("rooms", [])
    else
      []
    end
  end

  defp write_rooms(rooms) do
    path = Path.join(:code.priv_dir(:voice_bbs), "../rooms.json")
    File.write!(path, Jason.encode!(%{"rooms" => rooms}, pretty: true))
  end

  defp room_icon(%{"type" => "shiritori"}), do: "🔗"
  defp room_icon(_), do: "🫧"

  defp room_color(_idx, false), do: "border-gray-200 bg-gray-50/50 opacity-50"
  defp room_color(0, _), do: "border-purple-100 bg-purple-50/50"
  defp room_color(1, _), do: "border-pink-100 bg-pink-50/50"
  defp room_color(2, _), do: "border-blue-100 bg-blue-50/50"
  defp room_color(3, _), do: "border-yellow-100 bg-yellow-50/50"
  defp room_color(4, _), do: "border-green-100 bg-green-50/50"
  defp room_color(_, _), do: "border-purple-100 bg-purple-50/50"

  defp chevron_class(true), do: "w-3 h-3 text-purple-400 transition-transform duration-300 rotate-180"
  defp chevron_class(_), do: "w-3 h-3 text-purple-400 transition-transform duration-300"

  defp panel_class(true), do: "manage-content bg-white/95 backdrop-blur-sm rounded-t-2xl shadow-[0_-4px_24px_rgba(0,0,0,0.08)] border-t border-purple-100/50 transition-all duration-300 max-h-[70vh] overflow-y-auto"
  defp panel_class(_), do: "manage-content bg-white/95 backdrop-blur-sm rounded-t-2xl shadow-[0_-4px_24px_rgba(0,0,0,0.08)] border-t border-purple-100/50 transition-all duration-300 max-h-0 overflow-hidden"

  @impl true
  def render(assigns) do
    ~H"""
    <div id="manage-panel" class="fixed bottom-0 left-0 right-0 z-50 select-none"
         style="padding-bottom:max(8px,env(safe-area-inset-bottom,8px))">

      <%!-- Toggle button --%>
      <div class="flex justify-center mb-1">
        <button phx-click="toggle-panel"
                class="manage-toggle w-10 h-5 rounded-full flex items-center justify-center transition-all duration-300">
          <svg class={chevron_class(@panel_open)}
               viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
            <path d="M6 9l6 6 6-6"/>
          </svg>
        </button>
      </div>

      <%!-- Panel --%>
      <div class={panel_class(@panel_open)}>
        <%!-- Tabs --%>
        <div class="flex border-b border-purple-100/50 sticky top-0 bg-white/95 backdrop-blur-sm z-10">
          <button phx-click="switch-tab" phx-value-tab="posts"
                  class={tab_class(@active_tab, "posts")}>
            posts <span class="text-[10px] opacity-60">(<%= @post_count %>)</span>
          </button>
          <button phx-click="switch-tab" phx-value-tab="status"
                  class={tab_class(@active_tab, "status")}>
            status
          </button>
          <button phx-click="switch-tab" phx-value-tab="rooms"
                  class={tab_class(@active_tab, "rooms")}>
            rooms
          </button>
        </div>

        <div class="p-3">
          <%!-- Posts tab --%>
          <div :if={@active_tab == "posts"}>
            <div :if={@posts != []} class="flex justify-end mb-2">
              <button phx-click="play-all"
                      class="text-[10px] bg-purple-100 text-purple-500 px-2.5 py-1 rounded-full hover:bg-purple-200 transition">
                play all
              </button>
            </div>

            <div class="space-y-1.5 max-h-[50vh] overflow-y-auto">
              <%= for {post, idx} <- Enum.with_index(@posts) do %>
                <div class="flex items-center gap-2 py-1.5 px-2 rounded-lg hover:bg-purple-50/50 transition">
                  <span class="text-[9px] text-purple-300/50 w-4 text-right"><%= idx + 1 %></span>
                  <button
                    phx-click={JS.dispatch("play-admin-audio", detail: %{url: post.url})}
                    class="w-6 h-6 rounded-full bg-purple-100 flex items-center justify-center hover:bg-purple-200 transition flex-shrink-0"
                  >
                    <svg class="w-2.5 h-2.5 text-purple-500" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M8 5v14l11-7z"/>
                    </svg>
                  </button>
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center gap-1.5">
                      <span class="text-[10px] text-purple-400/60"><%= post.duration %>s</span>
                      <span class="text-[9px] bg-purple-100 text-purple-400 px-1 rounded"><%= post.source || "board" %></span>
                      <span class="text-[9px] text-purple-300/40 truncate"><%= String.slice(post.device_id, 0..7) %></span>
                    </div>
                  </div>
                  <button
                    phx-click="delete"
                    phx-value-id={post.id}
                    data-confirm="delete?"
                    class="w-5 h-5 rounded-full bg-red-50 flex items-center justify-center hover:bg-red-100 transition flex-shrink-0"
                  >
                    <svg class="w-2.5 h-2.5 text-red-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                      <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
                    </svg>
                  </button>
                </div>
              <% end %>
            </div>

            <div :if={@posts == []} class="text-center text-purple-300/40 text-xs py-8">no posts</div>
          </div>

          <%!-- Status tab --%>
          <div :if={@active_tab == "status"} class="space-y-3">
            <div class="flex items-center justify-between py-2 px-2 rounded-lg bg-purple-50/50">
              <span class="text-[11px] text-purple-500">DB</span>
              <span class={status_color(@db_status)}>
                <%= @db_status %>
              </span>
            </div>
            <div class="flex items-center justify-between py-2 px-2 rounded-lg bg-purple-50/50">
              <span class="text-[11px] text-purple-500">posts</span>
              <span class="text-[11px] text-purple-400"><%= @post_count %>件</span>
            </div>
            <div class="flex items-center justify-between py-2 px-2 rounded-lg bg-purple-50/50">
              <span class="text-[11px] text-purple-500">mic</span>
              <span class={status_color(@mic_status)}>
                <%= @mic_status %>
              </span>
            </div>
            <button phx-click="mic-test"
                    class="w-full py-2 bg-purple-100 text-purple-500 text-[11px] rounded-lg hover:bg-purple-200 transition">
              mic test
            </button>
            <button phx-click="check-db"
                    class="w-full py-2 bg-purple-50 text-purple-400 text-[11px] rounded-lg hover:bg-purple-100 transition">
              refresh
            </button>
          </div>

          <%!-- Rooms tab --%>
          <div :if={@active_tab == "rooms"}>
            <div class="grid grid-cols-3 gap-2">
              <%= for {room, idx} <- Enum.with_index(@rooms) do %>
                <div class={"flex flex-col items-center justify-center aspect-square rounded-2xl border transition #{room_color(idx, room["open"])}"}>
                  <span class="text-lg mb-0.5"><%= room_icon(room) %></span>
                  <span class="text-[9px] font-medium truncate px-1 max-w-[60px]"><%= room["name"] %></span>
                  <button phx-click="toggle-room" phx-value-id={room["id"]}
                          class={"mt-1 text-[8px] px-1.5 py-0.5 rounded-full transition #{if room["open"] != false, do: "bg-green-100 text-green-600", else: "bg-gray-100 text-gray-400"}"}>
                    <%= if room["open"] != false, do: "公開", else: "非公開" %>
                  </button>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
