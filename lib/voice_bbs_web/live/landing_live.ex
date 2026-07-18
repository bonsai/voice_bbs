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
     |> assign(:new_room_name, "")
     |> assign(:new_room_ad, false)}
  end

  @impl true
  def handle_event("mic-check", _params, socket) do
    {:noreply, push_event(socket, "test-mic", %{})}
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-b from-white via-purple-50/30 to-white flex flex-col items-center justify-center px-6">

      <%!-- Logo / Title --%>
      <div class="text-center mb-8">
        <div class="text-4xl mb-2">🫧</div>
        <h1 class="text-xl font-bold text-purple-600/80">bubble voice</h1>
      </div>

      <%!-- Onboarding: 2 lines --%>
      <div class="text-center text-sm text-gray-500 mb-8 max-w-xs leading-relaxed">
        <p>音声でバブルを飛ばす掲示板。</p>
        <p>ルームに入って録音してね。</p>
      </div>

      <%!-- Mic check --%>
      <div class="w-full max-w-xs mb-6">
        <button phx-click="mic-check"
                class={"w-full py-3 rounded-xl text-sm font-medium transition shadow-sm #{mic_class(@mic_ok)}"}>
          <%= case @mic_ok do %>
            <% true -> %>
              ✓ マイクOK
            <% false -> %>
              ✗ マイクNG
            <% _ -> %>
              マイクチェック
          <% end %>
        </button>
      </div>

      <%!-- Enter room: square grid --%>
      <div class="w-full max-w-xs mb-4">
        <div class="text-[10px] text-gray-400 text-center mb-3">入る</div>
        <div class="grid grid-cols-3 gap-3">
          <%= for room <- @rooms do %>
            <a href={"/room/#{room["id"]}"}
               class="aspect-square flex flex-col items-center justify-center bg-white border border-purple-100 rounded-2xl text-sm text-gray-600 hover:border-purple-300 hover:shadow-md transition">
              <span class="text-lg mb-0.5">🫧</span>
              <span class="text-[10px] font-medium truncate px-1"><%= room["name"] %></span>
            </a>
          <% end %>

          <%!-- +NEW tile --%>
          <button phx-click="toggle-create"
                  class="aspect-square flex flex-col items-center justify-center bg-purple-50 border-2 border-dashed border-purple-200 rounded-2xl text-purple-400 hover:bg-purple-100 hover:border-purple-300 transition">
            <span class="text-2xl leading-none">+</span>
            <span class="text-[10px] font-medium mt-0.5">NEW</span>
          </button>
        </div>
      </div>

      <%!-- Create room form --%>
      <div :if={@show_create} class="w-full max-w-xs mt-4 p-4 bg-white rounded-2xl border border-purple-100 shadow-sm">
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
      <div class="mt-8 flex gap-4 text-[10px] text-gray-400">
        <a href="/shiritori" class="hover:text-purple-500 transition">しりとり</a>
        <a href="/manage" class="hover:text-purple-500 transition">管理</a>
      </div>
    </div>
    """
  end

  defp mic_class(true), do: "bg-green-50 text-green-600 border border-green-200"
  defp mic_class(false), do: "bg-red-50 text-red-500 border border-red-200"
  defp mic_class(_), do: "bg-white text-gray-500 border border-purple-200 hover:border-purple-300"
end
