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
      <%!-- dummy TTS bubbles (always floating) --%>
      <div class="absolute top-8 left-[5%] w-20 h-20 sm:w-24 sm:h-24">
        <div class="bubble-float-slow w-full h-full">
          <button class="bubble w-full h-full opacity-50 bubble-btn"
                  phx-click={JS.dispatch("speak-tts", detail: %{text: "hello"})}>
            <span class="bubble-text text-[12px] sm:text-[15px] font-medium text-purple-400/60">hello</span>
          </button>
        </div>
      </div>
      <div class="absolute top-32 right-[8%] w-12 h-12 sm:w-14 sm:h-14">
        <div class="bubble-float-reverse w-full h-full">
          <button class="bubble w-full h-full opacity-45 bubble-btn"
                  phx-click={JS.dispatch("speak-tts", detail: %{text: "nice"})}>
            <span class="bubble-text text-[10px] sm:text-[11px] font-medium text-pink-400/60">nice</span>
          </button>
        </div>
      </div>
      <div class="hidden sm:block absolute bottom-36 left-[12%] w-20 h-20">
        <div class="bubble-float w-full h-full">
          <button class="bubble w-full h-full opacity-50 bubble-btn"
                  phx-click={JS.dispatch("speak-tts", detail: %{text: "thanks"})}>
            <span class="bubble-text text-[13px] font-medium text-yellow-600/50">thanks</span>
          </button>
        </div>
      </div>
      <div class="hidden sm:block absolute bottom-24 right-[18%] w-10 h-10">
        <div class="bubble-float-slow w-full h-full">
          <button class="bubble w-full h-full opacity-40 bubble-btn"
                  phx-click={JS.dispatch("speak-tts", detail: %{text: "wow"})}>
            <span class="bubble-text text-[9px] font-medium text-emerald-400/60">wow</span>
          </button>
        </div>
      </div>

      <%!-- header --%>
      <div class="text-center pt-4 sm:pt-6 pb-1">
        <h1 class="text-lg sm:text-xl font-bold tracking-wide"
            style="background:linear-gradient(135deg,#7c3aed,#ec4899,#f59e0b);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text">
          voice bubble
        </h1>
        <p class="text-[10px] text-purple-400/30 mt-0.5 font-light">tap to listen</p>
      </div>

      <%!-- Floating bubbles --%>
      <div id="posts" phx-update="stream" class="max-w-lg mx-auto px-4 sm:px-6 pb-48 sm:pb-44 flex flex-wrap justify-center items-center gap-3 sm:gap-4">
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

      <%!-- Mic + preview bubble (fixed bottom) --%>
      <div id="recorder" phx-hook="AudioRecorder" class="fixed bottom-0 left-0 right-0 flex flex-col items-center pointer-events-none" style="padding-bottom:max(20px,env(safe-area-inset-bottom,16px))" data-source="board">
        <div id="preview-bubble" class="preview-bubble hidden pointer-events-none"
             style="width:0px;height:0px">
          <div class="bubble w-full h-full overflow-hidden opacity-60 flex items-center justify-center">
            <canvas id="waveform-canvas" class="w-full h-full rounded-full block"></canvas>
          </div>
        </div>

        <div class="pointer-events-auto flex flex-col items-center gap-1">
          <div id="timer" class="text-purple-400/40 text-[10px] font-mono hidden">
            0:00 / 0:30
          </div>

          <div id="slots" class="flex items-center justify-center gap-1.5 mb-1">
            <div class="slot-dot"></div>
            <div class="slot-dot"></div>
            <div class="slot-dot"></div>
            <div class="slot-dot"></div>
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
