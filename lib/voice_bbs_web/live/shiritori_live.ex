defmodule VoiceBbsWeb.ShiritoriLive do
  use VoiceBbsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(VoiceBbs.PubSub, "shiritori")
    end

    ensure_table()

    chain = VoiceBbs.Shiritoris.list_chain()
    last = VoiceBbs.Shiritoris.last_word()

    {:ok,
     socket
     |> assign(:chain, chain)
     |> assign(:last, last)
     |> assign(:device_id, generate_device_id())
     |> assign(:input_mode, :asr)
     |> assign(:recording, false)
     |> assign(:pending_word, nil)
     |> assign(:pending_kana, nil)
     |> assign(:error_msg, nil)
     |> assign(:game_over, false)
     |> assign(:expected_kana, expected_kana(last))}
  end

  @impl true
  def handle_event("toggle-mode", _params, socket) do
    mode = if socket.assigns.input_mode == :asr, do: :record, else: :asr
    {:noreply, assign(socket, :input_mode, mode)}
  end

  def handle_event("asr-result", %{"text" => text}, socket) do
    text = String.trim(text)
    kana = VoiceBbs.Shiritoris.normalize_kana(text)

    case VoiceBbs.Shiritoris.add_word(text, kana, socket.assigns.device_id) do
      {:ok, _word} ->
        send(self(), :refresh_chain)
        {:noreply, socket |> assign(:error_msg, nil) |> assign(:pending_word, nil)}

      {:error, reason} ->
        {:noreply, assign(socket, :error_msg, error_msg(reason))}
    end
  end

  def handle_event("manual-submit", %{"word" => word, "kana" => kana}, socket) do
    word = String.trim(word)
    kana = String.trim(kana)

    cond do
      word == "" ->
        {:noreply, assign(socket, :error_msg, "word is empty")}

      kana == "" ->
        {:noreply, assign(socket, :error_msg, "kana is empty")}

      true ->
        case VoiceBbs.Shiritoris.add_word(word, kana, socket.assigns.device_id) do
          {:ok, _word} ->
            send(self(), :refresh_chain)
            {:noreply, socket |> assign(:error_msg, nil)}

          {:error, reason} ->
            {:noreply, assign(socket, :error_msg, error_msg(reason))}
        end
    end
  end

  def handle_event("reset", _params, socket) do
    VoiceBbs.Shiritoris.reset_chain()
    send(self(), :refresh_chain)
    {:noreply, socket |> assign(:game_over, false)}
  end

  def handle_event("tts-speak", %{"text" => text}, socket) do
    {:noreply, push_event(socket, "tts-speak", %{text: text})}
  end

  @impl true
  def handle_info(:refresh_chain, socket) do
    chain = VoiceBbs.Shiritoris.list_chain()
    last = VoiceBbs.Shiritoris.last_word()

    game_over = last != nil && VoiceBbs.Shiritoris.last_kana(last.kana) == "ん"

    {:noreply,
     socket
     |> assign(:chain, chain)
     |> assign(:last, last)
     |> assign(:game_over, game_over)
     |> assign(:expected_kana, expected_kana(last))
     |> assign(:error_msg, nil)}
  end

  defp expected_kana(nil), do: "あ"
  defp expected_kana(last), do: VoiceBbs.Shiritoris.last_kana(last.kana)

  defp ensure_table do
    Ecto.Migrator.run(VoiceBbs.Repo, :up, all: true)
  rescue
    _ -> :ok
  end

  defp generate_device_id do
    "shiritori-" <> Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)
  end

  defp error_msg("game_over_n"), do: "「ん」で終わったら負け！ゲームオーバー"
  defp error_msg("expected_tsu"), do: "「っ」の次は「っ」で始まる言葉！"
  defp error_msg({"mismatch", expected, got}), do: "「#{expected}」で始まる言葉を言って！（拾った: 「#{got}」）"
  defp error_msg(reason), do: "エラー: #{inspect(reason)}"

  defp main_class(nil), do: "min-h-screen bg-gradient-to-b from-pink-50 via-purple-50 to-blue-50 flex flex-col"
  defp main_class(_), do: "min-h-screen bg-gradient-to-b from-pink-50 via-purple-50 to-blue-50 flex flex-col grayscale-[0.6] opacity-80 transition-all duration-300"

  @impl true
  def render(assigns) do
    ~H"""
    <div class={main_class(@error_msg)}>

      <%!-- Header --%>
      <div class="text-center pt-6 pb-2 px-4">
        <h1 class="text-lg font-bold text-purple-600/80 tracking-wide">しりとり</h1>
        <div :if={@expected_kana && !@game_over} class="mt-1 text-xs text-purple-400/60">
          「<span class="text-purple-500 font-bold text-sm"><%= @expected_kana %></span>」で始まる言葉を！
        </div>
        <div :if={@game_over} class="mt-1 text-xs text-red-400 font-medium">
          ゲームオーバー！「ん」で終わってしまった
        </div>
      </div>

      <%!-- Chain visualization: balloons connected by thread --%>
      <div class="flex-1 overflow-y-auto px-4 pb-40">
        <div :if={@chain == []} class="flex items-center justify-center h-64">
          <div class="text-center text-purple-300/50 text-sm">
            <div class="text-3xl mb-2">🎈</div>
            最初の言葉を入力してね
          </div>
        </div>

        <div :if={@chain != []} class="relative">
          <%!-- Thread line --%>
          <div class="absolute left-1/2 top-0 bottom-0 w-px bg-gradient-to-b from-purple-200 via-pink-200 to-blue-200 transform -translate-x-1/2" style={"height: #{length(@chain) * 80}px"}></div>

          <%= for {word, idx} <- Enum.with_index(@chain) do %>
            <div class={"relative flex #{if rem(idx, 2) == 0, do: "justify-start pl-4", else: "justify-end pr-4"} mb-2"} style="margin-top: 2px;">
              <%!-- Thread connector dot --%>
              <div class="absolute left-1/2 top-4 w-2.5 h-2.5 rounded-full bg-white border-2 border-purple-300 transform -translate-x-1/2 z-10"></div>

              <%!-- Balloon --%>
              <div class={"relative px-4 py-2.5 rounded-2xl max-w-[65%] shadow-sm cursor-pointer hover:shadow-md transition-shadow #{balloon_color(idx)}"}
                   phx-click="tts-speak"
                   phx-value-text={word.kana}>
                <div class="text-sm font-medium text-gray-700"><%= word.word %></div>
                <div class="text-[10px] text-gray-400/70 mt-0.5"><%= word.kana %></div>
                <%!-- Balloon tail --%>
                <div class={"absolute top-4 w-3 h-3 transform rotate-45 #{tail_class(idx)}"} style={tail_style(idx)}></div>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <%!-- Input area --%>
      <div class="fixed bottom-0 left-0 right-0 bg-white/95 backdrop-blur-sm border-t border-purple-100/50"
           style="padding-bottom:max(12px,env(safe-area-inset-bottom,12px))">

        <div :if={@game_over} class="p-4 text-center">
          <button phx-click="reset"
                  class="px-6 py-2.5 bg-purple-500 text-white rounded-full text-sm font-medium hover:bg-purple-600 transition shadow-md">
            もう一度
          </button>
        </div>

        <div :if={!@game_over} class="p-4">
          <%!-- Mode toggle --%>
          <div class="flex justify-center mb-3">
            <button phx-click="toggle-mode"
                    class="text-[10px] text-purple-400/60 hover:text-purple-500 transition">
              <%= if @input_mode == :asr, do: "🎤 ASRモード（タップで書き換え）", else: "✍️ 手入力モード（タップで書き換え）" %>
            </button>
          </div>

          <%!-- ASR mode --%>
          <div :if={@input_mode == :asr} id="asr-container"
               phx-hook="ShiritoriASR" data-device-id={@device_id}>
            <div class="flex items-center gap-3">
              <button id="asr-btn"
                      class="flex-1 py-3 bg-gradient-to-r from-purple-500 to-pink-500 text-white rounded-full text-sm font-medium hover:from-purple-600 hover:to-pink-600 transition shadow-md active:scale-95">
                🎤 押して話して
              </button>
            </div>
            <div id="asr-status" class="text-center text-[10px] text-purple-400/60 mt-2 h-4"></div>
            <div id="asr-result" class="hidden" data-device-id={@device_id}></div>
          </div>

          <%!-- Manual input mode --%>
          <div :if={@input_mode == :record}>
            <form phx-submit="manual-submit" class="space-y-2">
              <input type="text" name="word" placeholder="言葉（漢字・かな）"
                     class="w-full px-4 py-2.5 rounded-xl border border-purple-200 text-sm focus:outline-none focus:border-purple-400"
                     required />
              <input type="text" name="kana" placeholder="読み（ひらがな）"
                     class="w-full px-4 py-2.5 rounded-xl border border-purple-200 text-sm focus:outline-none focus:border-purple-400"
                     required />
              <button type="submit"
                      class="w-full py-2.5 bg-gradient-to-r from-purple-500 to-pink-500 text-white rounded-full text-sm font-medium hover:from-purple-600 hover:to-pink-600 transition shadow-md">
                送る
              </button>
            </form>
          </div>

          <div :if={@error_msg} class="mt-2 text-center text-xs text-red-400">
            <%= @error_msg %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp balloon_color(idx) do
    colors = [
      "bg-purple-50 border border-purple-100",
      "bg-pink-50 border border-pink-100",
      "bg-blue-50 border border-blue-100",
      "bg-yellow-50 border border-yellow-100",
      "bg-green-50 border border-green-100"
    ]

    Enum.at(colors, rem(idx, length(colors)))
  end

  defp tail_class(idx) do
    colors = [
      "bg-purple-50 border-b border-r border-purple-100",
      "bg-pink-50 border-b border-r border-pink-100",
      "bg-blue-50 border-b border-r border-blue-100",
      "bg-yellow-50 border-b border-r border-yellow-100",
      "bg-green-50 border-b border-r border-green-100"
    ]

    Enum.at(colors, rem(idx, length(colors)))
  end

  defp tail_style(idx) do
    if rem(idx, 2) == 0 do
      "left: -4px;"
    else
      "right: -4px;"
    end
  end
end
