defmodule VoiceBbsWeb.ApiLive do
  use VoiceBbsWeb, :live_view

  @apis [
    %{method: "GET", path: "/api/posts", desc: "全投稿一覧"},
    %{method: "GET", path: "/api/tree", desc: "room別ツリー構造"},
    %{method: "POST", path: "/api/upload", desc: "音声アップロード", body: "image_base64, duration, device_id, source"},
    %{method: "POST", path: "/api/create-room", desc: "部屋作成", body: "source(任意)"},
    %{method: "POST", path: "/api/migrate", desc: "DBマイグレーション実行"},
    %{method: "DELETE", path: "/api/posts/:id", desc: "投稿削除"},
    %{method: "GET", path: "/api/count/:device_id", desc: "デバイス別投稿数"},
    %{method: "GET", path: "/healthz", desc: "ヘルスチェック"},
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, apis: @apis)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-dvh bg-gradient-to-b from-purple-50 to-white font-sans p-4 max-w-xl mx-auto select-none">
      <h1 class="text-xl font-bold text-purple-600 mb-4">API一覧</h1>
      <div class="space-y-1.5">
        <%= for api <- @apis do %>
          <div class="bg-white rounded-lg shadow-sm border border-purple-100/50 p-3 flex items-center gap-3">
            <span class={[
              "text-[10px] font-bold px-2 py-0.5 rounded-full flex-shrink-0",
              method_color(api.method)
            ]}>
              <%= api.method %>
            </span>
            <code class="text-xs text-purple-600 flex-1 break-all"><%= api.path %></code>
            <span class="text-[10px] text-purple-300/50 text-right flex-shrink-0"><%= api.desc %></span>
          </div>
        <% end %>
      </div>
      <div :if={@apis == []} class="text-center text-purple-300/40 text-sm mt-20">APIなし</div>
    </div>
    """
  end

  defp method_color("GET"), do: "bg-green-100 text-green-600"
  defp method_color("POST"), do: "bg-blue-100 text-blue-600"
  defp method_color("DELETE"), do: "bg-red-100 text-red-600"
  defp method_color(_), do: "bg-purple-100 text-purple-600"
end
