defmodule VoiceBbsWeb.LandingLive do
  use VoiceBbsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    rooms = list_rooms()

    {:ok,
     socket
     |> assign(:rooms, rooms)
     |> assign(:mic_ok, nil)
     |> assign(:show_create, false)
     |> assign(:step, 0)
     |> assign(:room_positions, generate_positions(rooms))}
  end

  @impl true
  def handle_event("next-step", _params, socket) do
    {:noreply, update(socket, :step, &(&1 + 1))}
  end

  def handle_event("mic-check", _params, socket) do
    {:noreply, push_event(socket, "test-mic", %{target: "landing-page"})}
  end

  def handle_event("mic-result", %{"ok" => ok}, socket) do
    {:noreply, assign(socket, :mic_ok, ok)}
  end

  def handle_event("toggle-create", _params, socket) do
    {:noreply, update(socket, :show_create, &(!&1))}
  end

  def handle_event("create-room", %{"name" => name}, socket) do
    name = String.trim(name)
    if name != "" do
      rooms = list_rooms()
      id = String.downcase(name) |> String.replace(~r/[^a-z0-9]/, "-") |> String.trim("-")
      new_room = %{"id" => id, "name" => name, "source" => "board"}

      if !Enum.any?(rooms, &(&1["id"] == id)) do
        write_rooms(rooms ++ [new_room])
      end

      {:noreply, redirect(socket, to: "/room/#{id}")}
    else
      {:noreply, socket}
    end
  end

  defp list_rooms do
    path = rooms_path()
    if File.exists?(path) do
      path |> File.read!() |> Jason.decode!() |> Map.get("rooms", [])
    else
      []
    end
  end

  defp write_rooms(rooms) do
    path = rooms_path()
    File.write!(path, Jason.encode!(%{"rooms" => rooms}, pretty: true))
  end

  defp rooms_path, do: Path.join(:code.priv_dir(:voice_bbs), "../rooms.json")

  defp generate_positions(rooms) do
    # Deterministic random-ish positions based on room name hash
    Enum.with_index(rooms, fn room, idx ->
      hash = :erlang.phash2(room["id"])
      x = 10 + rem(hash, 80)
      y = 10 + rem(div(hash, 100), 70)
      rotate = rem(hash, 30) - 15
      {room["id"], %{x: x, y: y, rotate: rotate, delay: idx * 0.15}}
    end)
    |> Map.new()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-b from-white via-purple-50/30 to-white flex flex-col items-center px-6 overflow-hidden">

      <%!-- Step 0: Logo + title only --%>
      <div :if={@step == 0} class="flex-1 flex flex-col items-center justify-center">
        <div class="text-5xl mb-3 animate-bounce">🫧</div>
        <h1 class="text-2xl font-bold text-purple-600/80 mb-6">bubble voice</h1>
        <button phx-click="next-step"
                class="px-6 py-3 bg-purple-500 text-white rounded-full text-sm font-medium hover:bg-purple-600 transition shadow-lg">
          はじめる
        </button>
      </div>

      <%!-- Step 1: Explanation --%>
      <div :if={@step == 1} class="flex-1 flex flex-col items-center justify-center">
        <div class="text-4xl mb-4">🎤</div>
        <p class="text-sm text-gray-500 text-center max-w-xs leading-relaxed mb-6">
          音声でバブルを飛ばす掲示板。<br/>ルームに入って録音してね。
        </p>
        <button phx-click="next-step"
                class="px-6 py-3 bg-purple-500 text-white rounded-full text-sm font-medium hover:bg-purple-600 transition shadow-lg">
          次
        </button>
      </div>

      <%!-- Step 2: Mic check --%>
      <div :if={@step == 2} id="landing-page" class="flex-1 flex flex-col items-center justify-center">
        <div class="text-4xl mb-4">🔊</div>
        <p class="text-sm text-gray-500 text-center mb-6">マイクをチェック</p>
        <button phx-click="mic-check"
                class={"w-48 py-4 rounded-2xl text-sm font-medium transition shadow-md #{mic_class(@mic_ok)}"}>
          <%= case @mic_ok do %>
            <% true -> %> ✓ OK
            <% false -> %> ✗ NG
            <% _ -> %> マイクチェック
          <% end %>
        </button>
        <div class="flex gap-3 mt-6">
          <button phx-click="next-step"
                  class="px-6 py-3 bg-purple-500 text-white rounded-full text-sm font-medium hover:bg-purple-600 transition shadow-lg">
            次
          </button>
          <button phx-click="next-step"
                  class="px-6 py-3 bg-gray-100 text-gray-400 rounded-full text-sm font-medium hover:bg-gray-200 transition">
            スキップ
          </button>
        </div>
      </div>

      <%!-- Step 3: Rooms (random positions) --%>
      <div :if={@step >= 3} class="flex-1 flex flex-col items-center w-full pt-8">
        <p class="text-xs text-gray-400 mb-4">ルームに入る</p>

        <div class="relative w-full max-w-sm" style="height: 60vh;">
          <%= for room <- @rooms do %>
            <% pos = Map.get(@room_positions, room["id"], %{x: 50, y: 50, rotate: 0, delay: 0}) %>
            <a href={"/room/#{room["id"]}"}
               class="absolute flex flex-col items-center justify-center w-24 h-24 bg-white/90 backdrop-blur-sm border border-purple-100 rounded-2xl shadow-md hover:shadow-xl hover:scale-110 transition-all duration-300"
               style={"left: #{pos.x}%; top: #{pos.y}%; transform: rotate(#{pos.rotate}deg); animation: pop-in 0.4s #{pos.delay}s both"}>
              <span class="text-2xl mb-1">🫧</span>
              <span class="text-[10px] font-medium text-gray-600 truncate px-1 max-w-[80px]"><%= room["name"] %></span>
            </a>
          <% end %>

          <%!-- +NEW button --%>
          <button phx-click="toggle-create"
                  class="absolute flex flex-col items-center justify-center w-20 h-20 bg-purple-50/90 border-2 border-dashed border-purple-200 rounded-2xl text-purple-400 hover:bg-purple-100 hover:scale-110 transition-all duration-300"
                  style="right: 8%; bottom: 15%; animation: pop-in 0.4s 0.5s both">
            <span class="text-2xl leading-none">+</span>
            <span class="text-[9px] font-medium mt-0.5">NEW</span>
          </button>
        </div>

        <%!-- Create room form --%>
        <div :if={@show_create} class="w-full max-w-xs mt-4 p-4 bg-white/90 backdrop-blur-sm rounded-2xl border border-purple-100 shadow-lg">
          <form phx-submit="create-room" class="space-y-3">
            <input type="text" name="name" placeholder="ルーム名"
                   class="w-full px-3 py-2 border border-purple-200 rounded-xl text-sm focus:outline-none focus:border-purple-400"
                   required />
            <div class="flex gap-2">
              <button type="button" phx-click="toggle-create"
                      class="flex-1 py-2.5 bg-gray-100 text-gray-500 rounded-xl text-sm font-medium hover:bg-gray-200 transition">
                やめる
              </button>
              <button type="submit"
                      class="flex-1 py-2.5 bg-purple-500 text-white rounded-xl text-sm font-medium hover:bg-purple-600 transition">
                つくる
              </button>
            </div>
          </form>
        </div>

        <%!-- Links --%>
        <div class="mt-6 flex gap-4 text-[10px] text-gray-400">
          <a href="/shiritori" class="hover:text-purple-500 transition">しりとり</a>
          <a href="/manage" class="hover:text-purple-500 transition">管理</a>
        </div>
      </div>
    </div>
    """
  end

  defp mic_class(true), do: "bg-green-50 text-green-600 border border-green-200"
  defp mic_class(false), do: "bg-red-50 text-red-500 border border-red-200"
  defp mic_class(_), do: "bg-white text-gray-500 border border-purple-200 hover:border-purple-300"
end
