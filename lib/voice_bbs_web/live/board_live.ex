defmodule VoiceBbsWeb.BoardLive do
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
     |> stream(:posts, posts)
     |> assign(:post_count, length(posts))}
  end

  @impl true
  def handle_info({:new_post, post}, socket) do
    {:noreply,
     socket
     |> stream_insert(:posts, post, at: 0)
     |> update(:post_count, & &1 + 1)}
  end

  defp bubble_size(duration) do
    base = 56
    scale = (duration / 30) |> min(1)
    round(base + scale * 104)
  end

  defp float_class(id) do
    case rem(id, 4) do
      0 -> "bubble-float"
      1 -> "bubble-float-reverse"
      2 -> "bubble-float-slow"
      _ -> "bubble-float"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-gradient-to-b from-white via-purple-50/30 to-pink-50/20 min-h-dvh font-sans overflow-hidden relative">
      <%!-- dummy bubbles (always floating) --%>
      <div class="absolute top-12 left-[6%] w-24 h-24 bubble-float-slow pointer-events-none">
        <div class="bubble w-full h-full opacity-25">
          <div class="w-full h-full rounded-full" style="background:radial-gradient(circle at 35% 35%,rgba(200,220,255,0.3),rgba(200,180,240,0.15) 60%,transparent 100%)"></div>
        </div>
      </div>
      <div class="absolute top-36 right-[12%] w-14 h-14 bubble-float-reverse pointer-events-none">
        <div class="bubble w-full h-full opacity-20">
          <div class="w-full h-full rounded-full" style="background:radial-gradient(circle at 35% 35%,rgba(255,200,220,0.3),rgba(240,180,200,0.15) 60%,transparent 100%)"></div>
        </div>
      </div>
      <div class="absolute bottom-36 left-[15%] w-20 h-20 bubble-float pointer-events-none">
        <div class="bubble w-full h-full opacity-20">
          <div class="w-full h-full rounded-full" style="background:radial-gradient(circle at 35% 35%,rgba(255,230,180,0.3),rgba(240,210,170,0.15) 60%,transparent 100%)"></div>
        </div>
      </div>
      <div class="absolute bottom-20 right-[20%] w-10 h-10 bubble-float-slow pointer-events-none">
        <div class="bubble w-full h-full opacity-15">
          <div class="w-full h-full rounded-full" style="background:radial-gradient(circle at 35% 35%,rgba(180,240,220,0.3),rgba(160,220,200,0.15) 60%,transparent 100%)"></div>
        </div>
      </div>

      <%!-- header --%>
      <div class="text-center pt-6 pb-1">
        <h1 class="text-xl font-bold tracking-wide"
            style="background:linear-gradient(135deg,#7c3aed,#ec4899,#f59e0b);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text">
          voice bubble
        </h1>
        <p class="text-[10px] text-purple-400/30 mt-0.5 font-light">tap to listen</p>
      </div>

      <%!-- Floating bubbles --%>
      <div id="posts" phx-update="stream" class="max-w-lg mx-auto px-6 pb-44 flex flex-wrap justify-center items-center gap-4">
        <button
          :for={{id, post} <- @streams.posts}
          id={id}
          class={"bubble-pop-in bubble-wrapper cursor-pointer #{float_class(post.id)}"}
          style={"width:#{bubble_size(post.duration)}px;height:#{bubble_size(post.duration)}px;animation-delay:#{rem(post.id, 5) * 0.3}s"}
          phx-click={JS.dispatch("play-audio", detail: %{url: post.url})}
        >
          <div class="bubble w-full h-full overflow-hidden">
            <img src={post.url} alt="voice" class="bubble-img w-full h-full" />
          </div>
        </button>

        <div :if={@post_count == 0} class="text-center py-16 w-full">
          <div class="text-4xl mb-3 opacity-25">🫧</div>
          <p class="text-purple-400/20 text-sm font-light">blow a bubble</p>
        </div>
      </div>

      <%!-- Mic + preview bubble (fixed bottom) --%>
      <div id="recorder" phx-hook="AudioRecorder" class="fixed bottom-0 left-0 right-0 flex flex-col items-center pb-8 pointer-events-none">
        <div id="preview-bubble" class="preview-bubble hidden pointer-events-none"
             style="width:0px;height:0px">
          <div class="bubble w-full h-full overflow-hidden opacity-60">
            <div class="w-full h-full rounded-full" style="background:radial-gradient(circle at 35% 35%,rgba(255,255,255,0.6),rgba(200,220,255,0.25) 50%,rgba(180,200,240,0.35) 100%)"></div>
          </div>
        </div>

        <div class="pointer-events-auto flex flex-col items-center gap-1">
          <div id="timer" class="text-purple-400/40 text-[10px] font-mono hidden">
            0:00 / 0:30
          </div>

          <button id="record-btn" class="mic-btn">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mic-icon">
              <path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"/>
              <path d="M19 10v2a7 7 0 0 1-14 0v-2"/>
              <line x1="12" y1="19" x2="12" y2="23"/>
              <line x1="8" y1="23" x2="16" y2="23"/>
            </svg>
          </button>

          <p class="text-[10px] text-purple-300/20 font-light">hold to record</p>
        </div>
      </div>
    </div>
    """
  end
end
