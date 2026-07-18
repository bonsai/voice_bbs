defmodule VoiceBbsWeb.YonLive do
  use VoiceBbsWeb, :live_view

  @topic "board"

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(VoiceBbs.PubSub, @topic)
    end

    posts = VoiceBbs.Posts.list_posts() |> Enum.filter(&(&1.source == "yon"))

    {:ok,
     socket
     |> stream(:posts, posts)
     |> assign(:post_count, length(posts))}
  end

  @impl true
  def handle_info({:new_post, post}, socket) do
    if post.source == "yon" do
      {:noreply,
       socket
       |> stream_insert(:posts, post, at: 0)
       |> update(:post_count, &(&1 + 1))}
    else
      {:noreply, socket}
    end
  end

  defp bubble_size(duration) do
    base = 56
    scale = (duration / 30) |> min(1)
    round(base + scale * 104)
  end

  defp float_class(id) do
    num = :erlang.phash2(id)
    case rem(num, 4) do
      0 -> "bubble-float"
      1 -> "bubble-float-reverse"
      2 -> "bubble-float-slow"
      _ -> "bubble-float"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-gradient-to-b from-white via-purple-50/30 to-pink-50/20 min-h-dvh font-sans overflow-hidden relative select-none">

      <%!-- Header --%>
      <div class="text-center pt-3 pb-1">
        <h1 class="text-lg font-bold tracking-wide"
            style="background:linear-gradient(135deg,#7c3aed,#ec4899,#f59e0b);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text">
          yon
        </h1>
        <p class="text-[10px] text-purple-400/30 mt-0.5 font-light">tap to listen</p>
      </div>

      <%!-- Floating bubbles --%>
      <div id="posts" phx-update="stream"
           class="max-w-lg mx-auto px-3 pb-36 flex flex-wrap justify-center items-center gap-2">
        <button
          :for={{id, post} <- @streams.posts}
          id={id}
          class="bubble-pop-in bubble-wrapper cursor-pointer"
          style={"width:#{bubble_size(post.duration)}px;height:#{bubble_size(post.duration)}px;animation-delay:#{rem(:erlang.phash2(post.id), 5) * 0.3}s"}
          phx-click={JS.dispatch("play-audio", detail: %{url: post.url})}
        >
          <div class={"#{float_class(post.id)} w-full h-full"}>
            <div class="bubble w-full h-full overflow-hidden">
              <img src={post.url} alt="voice" class="bubble-img w-full h-full" />
            </div>
          </div>
        </button>
      </div>

      <div :if={@post_count == 0}
           class="absolute inset-0 flex items-center justify-center pointer-events-none">
        <p class="text-purple-300/30 text-sm">hold mic to record</p>
      </div>

      <%!-- Mic --%>
      <div id="recorder" phx-hook="AudioRecorder"
           class="fixed bottom-0 left-0 right-0 flex flex-col items-center pointer-events-none z-40"
           style="padding-bottom:max(12px,env(safe-area-inset-bottom,12px))"
           data-source="yon">
        <div id="preview-bubble" class="preview-bubble hidden pointer-events-none"
             style="width:0px;height:0px">
          <div class="bubble w-full h-full overflow-hidden opacity-60 flex items-center justify-center">
            <canvas id="waveform-canvas" class="w-full h-full rounded-full block"></canvas>
          </div>
        </div>
        <div class="pointer-events-auto flex flex-col items-center gap-0.5">
          <div id="timer" class="text-purple-400/40 text-[10px] font-mono hidden">0:00 / 0:30</div>
          <div id="slots" class="flex items-center justify-center gap-1 mb-0.5">
            <div class="slot-dot"></div><div class="slot-dot"></div><div class="slot-dot"></div><div class="slot-dot"></div>
          </div>
          <button id="record-btn" class="mic-btn">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mic-icon">
              <path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"/>
              <path d="M19 10v2a7 7 0 0 1-14 0v-2"/>
              <line x1="12" y1="19" x2="12" y2="23"/>
              <line x1="8" y1="23" x2="16" y2="23"/>
            </svg>
          </button>
        </div>
      </div>

      <%!-- Manage panel --%>
      <div id="manage-mount" phx-hook="ManagePanel">
        <%= live_render(@socket, VoiceBbsWeb.ManageLive, id: "manage-yon") %>
      </div>
    </div>
    """
  end
end
