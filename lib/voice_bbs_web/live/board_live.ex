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
      <%!-- decorative floating orbs --%>
      <div class="absolute top-16 left-[5%] w-28 h-28 rounded-full opacity-20 bubble-float-slow pointer-events-none"
           style="background:radial-gradient(circle,rgba(192,132,252,0.5),transparent 70%)">
      </div>
      <div class="absolute top-48 right-[8%] w-16 h-16 rounded-full opacity-15 bubble-float-reverse pointer-events-none"
           style="background:radial-gradient(circle,rgba(244,114,182,0.5),transparent 70%)">
      </div>
      <div class="absolute bottom-48 left-[20%] w-20 h-20 rounded-full opacity-10 bubble-float pointer-events-none"
           style="background:radial-gradient(circle,rgba(251,191,36,0.4),transparent 70%)">
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

      <%!-- Straw wand + preview bubble (fixed bottom) --%>
      <div id="recorder" phx-hook="AudioRecorder" class="fixed bottom-0 left-0 right-0 flex flex-col items-center pb-6 pointer-events-none">
        <div id="preview-bubble" class="preview-bubble hidden pointer-events-none"
             style="width:0px;height:0px">
          <div class="bubble w-full h-full overflow-hidden opacity-60">
            <div class="w-full h-full rounded-full" style="background:radial-gradient(circle at 35% 35%,rgba(255,255,255,0.6),rgba(200,220,255,0.25) 50%,rgba(180,200,240,0.35) 100%)"></div>
          </div>
        </div>

        <div class="pointer-events-auto flex flex-col items-center">
          <div id="timer" class="text-center mb-1 text-purple-400/40 text-[10px] font-mono hidden">
            0:00 / 0:30
          </div>

          <button id="record-btn" class="wand">
            <div class="wand-ring">
              <div class="wand-film"></div>
            </div>
            <div class="wand-handle"></div>
          </button>

          <p class="text-[10px] text-purple-300/20 mt-1 font-light">hold to blow</p>
        </div>
      </div>
    </div>
    """
  end
end
