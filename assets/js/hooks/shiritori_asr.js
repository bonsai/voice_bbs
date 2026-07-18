export const ShiritoriASR = {
  mounted() {
    const btn = document.getElementById("asr-btn")
    const status = document.getElementById("asr-status")
    const resultEl = document.getElementById("asr-result")

    if (!btn || !("webkitSpeechRecognition" in window || "SpeechRecognition" in window)) {
      if (status) status.textContent = "このブラウザはASRに対応していません"
      if (btn) btn.disabled = true
      return
    }

    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
    this.recognition = new SpeechRecognition()
    this.recognition.lang = "ja-JP"
    this.recognition.continuous = false
    this.recognition.interimResults = false

    let listening = false

    this.recognition.onstart = () => {
      listening = true
      if (btn) {
        btn.textContent = "🔴 聞いてる..."
        btn.classList.add("animate-pulse")
      }
      if (status) status.textContent = "音声を認識中..."
    }

    this.recognition.onresult = (event) => {
      const text = event.results[0][0].transcript
      if (status) status.textContent = "認識: " + text
      if (resultEl) {
        resultEl.dataset.asrText = text
        this.pushEvent("asr-result", { text })
      }
    }

    this.recognition.onerror = (event) => {
      console.warn("ASR error:", event.error)
      if (status) {
        if (event.error === "no-speech") {
          status.textContent = "音声が聞こえませんでした"
        } else if (event.error === "not-allowed") {
          status.textContent = "マイクの権限がありません"
        } else {
          status.textContent = "エラー: " + event.error
        }
      }
    }

    this.recognition.onend = () => {
      listening = false
      if (btn) {
        btn.textContent = "🎤 押して話して"
        btn.classList.remove("animate-pulse")
      }
    }

    btn?.addEventListener("click", () => {
      if (listening) {
        this.recognition.stop()
      } else {
        this.recognition.start()
      }
    })
  },

  destroyed() {
    if (this.recognition) {
      this.recognition.abort()
    }
  }
}
