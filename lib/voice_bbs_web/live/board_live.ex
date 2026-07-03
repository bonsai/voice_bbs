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
    <div class="sky-bg min-h-screen font-sans overflow-hidden relative">
      <%!-- decorative floating orbs --%>
      <div class="absolute top-20 left-[8%] w-32 h-32 rounded-full opacity-15 bubble-float-slow pointer-events-none"
           style="background:radial-gradient(circle,rgba(180,210,255,0.8),transparent 70%)">
      </div>
      <div class="absolute top-60 right-[10%] w-20 h-20 rounded-full opacity-10 bubble-float-reverse pointer-events-none"
           style="background:radial-gradient(circle,rgba(220,180,255,0.8),transparent 70%)">
      </div>
      <div class="absolute bottom-40 left-[25%] w-24 h-24 rounded-full opacity-10 bubble-float pointer-events-none"
           style="background:radial-gradient(circle,rgba(255,200,180,0.8),transparent 70%)">
      </div>

      <%!-- header: floating text --%>
      <div class="text-center pt-10 pb-2">
        <h1 class="text-2xl font-bold tracking-wide"
            style="background:linear-gradient(135deg,#7c3aed,#ec4899,#f59e0b);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text">
          voice bubble
        </h1>
        <p class="text-xs text-purple-400/40 mt-0.5 font-light">tap to listen</p>
      </div>

      <%!-- Floating bubbles --%>
      <div id="posts" phx-update="stream" class="max-w-2xl mx-auto px-8 pb-40 flex flex-wrap justify-center items-center gap-6">
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

        <div :if={@post_count == 0} class="text-center py-20 w-full">
          <div class="text-5xl mb-4 opacity-30">🫧</div>
          <p class="text-purple-400/30 text-sm font-light">blow a bubble</p>
        </div>
      </div>

      <%!-- Straw wand + preview bubble (fixed bottom) --%>
      <div id="recorder" phx-hook="AudioRecorder" class="fixed bottom-0 left-0 right-0 flex flex-col items-center pb-8 pointer-events-none">
        <%!-- preview bubble: grows in real-time during recording --%>
        <div id="preview-bubble" class="preview-bubble hidden pointer-events-none"
             style="width:0px;height:0px">
          <div class="bubble w-full h-full overflow-hidden opacity-60">
            <div class="w-full h-full rounded-full" style="background:radial-gradient(circle at 35% 35%,rgba(255,255,255,0.6),rgba(200,220,255,0.25) 50%,rgba(180,200,240,0.35) 100%)"></div>
          </div>
        </div>

        <%!-- bubble wand (straw + ring) --%>
        <div class="pointer-events-auto flex flex-col items-center">
          <div id="timer" class="text-center mb-2 text-purple-400/50 text-xs font-mono hidden">
            0:00 / 0:30
          </div>

          <button id="record-btn" class="wand">
            <div class="wand-ring">
              <div class="wand-film"></div>
            </div>
            <div class="wand-handle"></div>
          </button>

          <p class="text-[11px] text-purple-300/30 mt-2 font-light">hold to blow</p>
        </div>
      </div>
    </div>
    """
  end
end
