defmodule VoiceBbsWeb.TestLive do
  use VoiceBbsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :refresh, 100)
    end

    {:ok, assign(socket, db_status: "checking...", mic_status: "-", post_count: 0, error_msg: nil)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply,
     socket
     |> assign(:db_status, check_db())
     |> assign(:post_count, count_posts())}
  end

  @impl true
  def handle_event("check-db", _params, socket) do
    {:noreply,
     socket
     |> assign(:db_status, check_db())
     |> assign(:post_count, count_posts())}
  end

  @impl true
  def handle_event("make-room", _params, socket) do
    png = minimal_png()
    device_id = "test-" <> Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)
    dur = 1.0

    case VoiceBbs.Posts.add_post(device_id, png, dur) do
      {:ok, _post} ->
        {:noreply, assign(socket, post_count: count_posts(), error_msg: nil)}

      {:error, :limit_reached} ->
        {:noreply, assign(socket, error_msg: "limit reached (4 per device)")}
    end
  end

  @impl true
  def handle_event("mic-test", _params, socket) do
    {:noreply, push_event(socket, "test-mic", %{})}
  end

  @impl true
  def handle_event("mic-result", %{"ok" => ok}, socket) do
    {:noreply, assign(socket, mic_status: if(ok, do: "OK", else: "NG"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="test-page" class="min-h-dvh bg-gradient-to-b from-purple-50 to-white font-sans p-4 max-w-md mx-auto select-none">
      <h1 class="text-xl font-bold text-purple-600 mb-4">test</h1>

      <div class="space-y-3">
        <div class="bg-white rounded-xl shadow-sm border border-purple-100/50 p-4">
          <h2 class="text-sm font-medium text-purple-500 mb-2">DB接続</h2>
          <p class={"text-sm " <> color(@db_status)}><%= @db_status %></p>
        </div>

        <div class="bg-white rounded-xl shadow-sm border border-purple-100/50 p-4">
          <h2 class="text-sm font-medium text-purple-500 mb-2">投稿数</h2>
          <p class="text-sm text-purple-400"><%= @post_count %>件</p>
        </div>

        <div class="bg-white rounded-xl shadow-sm border border-purple-100/50 p-4">
          <h2 class="text-sm font-medium text-purple-500 mb-2">マイク</h2>
          <p class={"text-sm " <> color(@mic_status)}><%= @mic_status %></p>
          <button phx-click="mic-test" class="mt-2 bg-purple-100 text-purple-600 text-xs px-3 py-1.5 rounded-full hover:bg-purple-200 transition">
            マイクテスト
          </button>
        </div>

        <button phx-click="make-room" class="w-full bg-purple-500 text-white text-sm py-2.5 rounded-lg hover:bg-purple-600 transition">
          new
        </button>

        <p :if={@error_msg} class="text-xs text-red-400 text-center"><%= @error_msg %></p>

        <button phx-click="check-db" class="w-full bg-purple-100 text-purple-500 text-xs py-2 rounded-lg hover:bg-purple-200 transition">
          全チェック
        </button>
      </div>
    </div>
    """
  end

  defp check_db do
    try do
      VoiceBbs.Repo.query!("SELECT 1")
      "接続OK"
    rescue
      _ -> "接続NG"
    end
  end

  defp count_posts do
    try do
      length(VoiceBbs.Posts.list_posts())
    rescue
      _ -> 0
    end
  end

  defp color("接続OK"), do: "text-green-500"
  defp color("OK"), do: "text-green-500"
  defp color(_), do: "text-red-400"

  defp minimal_png do
    <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
      0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0, 144, 119, 83, 222,
      0, 0, 0, 12, 73, 68, 65, 84, 8, 215, 99, 248, 207, 0, 0, 0,
      3, 0, 1, 55, 46, 48, 42, 0, 0, 0, 0, 73, 69, 78, 68, 174,
      66, 96, 130>>
  end
end
