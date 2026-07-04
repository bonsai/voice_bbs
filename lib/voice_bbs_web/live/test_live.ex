defmodule VoiceBbsWeb.TestLive do
  use VoiceBbsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :db_status, check_db())}
  end

  @impl true
  def handle_event("check-db", _params, socket) do
    {:noreply, assign(socket, :db_status, check_db())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-dvh bg-gradient-to-b from-purple-50 to-white font-sans p-4 max-w-md mx-auto select-none">
      <h1 class="text-xl font-bold text-purple-600 mb-4">test</h1>

      <div class="space-y-3">
        <div class="bg-white rounded-xl shadow-sm border border-purple-100/50 p-4">
          <h2 class="text-sm font-medium text-purple-500 mb-2">DB接続</h2>
          <p class={"text-sm " <> status_color(@db_status)}><%= @db_status %></p>
        </div>

        <button phx-click="check-db" class="w-full bg-purple-500 text-white text-sm py-2 rounded-lg hover:bg-purple-600 transition">
          再チェック
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

  defp status_color("接続OK"), do: "text-green-500"
  defp status_color(_), do: "text-red-500"
end
