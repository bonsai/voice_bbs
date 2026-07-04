defmodule VoiceBbsWeb.YonLive do
  use VoiceBbsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :now, DateTime.utc_now() |> DateTime.to_string())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-dvh bg-gradient-to-b from-purple-100 to-white font-sans flex flex-col items-center justify-center p-4 select-none">
      <h1 class="text-4xl font-bold text-purple-600 tracking-wide">yon</h1>
      <p class="text-purple-400/60 mt-2 text-sm"><%= @now %></p>
    </div>
    """
  end
end
