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
     |> stream(:posts, posts)}
  end

  @impl true
  def handle_info({:new_post, post}, socket) do
    {:noreply, stream_insert(socket, :posts, post, at: 0)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="sky-bg min-h-screen font-sans overflow-hidden relative">
      <%!-- decorative floating orbs --%>
      <div class="absolute top-20 left-[10%] w-32 h-32 rounded-full opacity-20 bubble-float-slow"
           style="background:radial-gradient(circle,rgba(180,210,255,0.8),transparent 70%)">
      </div>
      <div class="absolute top-40 right-[15%] w-24 h-24 rounded-full opacity-15 bubble-float-reverse"
           style="background:radial-gradient(circle,rgba(220,180,255,0.8),transparent 70%)">
      </div>
      <div class="absolute bottom-32 left-[20%] w-20 h-20 rounded-full opacity-15 bubble-float"
           style="background:radial-gradient(circle,rgba(255,200,180,0.8),transparent 70%)">
      </div>

      <header class="text-center pt-10 pb-6">
        <h1 class="text-3xl font-bold tracking-wide"
            style="background:linear-gradient(135deg,#7c3aed,#ec4899,#f59e0b);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text">
          Voice Bubble
        </h1>
        <p class="text-sm text-purple-400/60 mt-1">tap a bubble to listen</p>
      </header>

      <%!-- Record button --%>
      <div id="recorder" phx-hook="AudioRecorder" class="flex flex-col items-center mb-10">
        <button id="record-btn" class="record-btn">🎤</button>
        <div id="timer" class="text-center mt-4 text-purple-400/70 text-sm font-mono hidden">
          0:00 / 0:30
        </div>
        <p class="text-xs text-purple-300/50 mt-2">press &amp; hold — max 30s</p>
      </div>

      <%!-- Bubble posts --%>
      <div id="posts" phx-update="stream" class="max-w-lg mx-auto px-6 pb-24 flex flex-wrap justify-center gap-6">
        <div
          :for={{id, post} <- @streams.posts}
          id={id}
          class="bubble-pop-in flex flex-col items-center gap-2"
        >
          <button
            class="bubble w-20 h-20 overflow-hidden cursor-pointer"
            phx-click={JS.dispatch("play-audio", detail: %{url: post.url})}
            style={"animation-delay:#{rem(post.id, 5) * 0.3}s"}
          >
            <img
              src={post.url}
              alt="voice"
              class="bubble-img w-full h-full"
            />
          </button>
          <span class="text-[10px] text-purple-300/50 font-mono">
            #<%= post.id %>
          </span>
        </div>

        <div :if={Enum.empty?(@streams.posts)} class="text-center py-20 w-full">
          <div class="text-6xl mb-4 shimmer" style="animation:shimmer 2s ease-in-out infinite">🫧</div>
          <p class="text-purple-400/50 text-sm">press the mic to speak</p>
        </div>
      </div>
    </div>
    """
  end
end
