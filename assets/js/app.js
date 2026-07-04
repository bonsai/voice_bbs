import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import {AudioRecorder} from "./hooks/audio_recorder"

let Hooks = { AudioRecorder }

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

liveSocket.connect()

window.liveSocket = liveSocket

async function decodePNGToAudio(url) {
  const img = new Image()
  img.crossOrigin = "anonymous"
  img.src = url
  await img.decode()

  const canvas = document.createElement("canvas")
  canvas.width = img.width
  canvas.height = img.height
  const ctx = canvas.getContext("2d", { willReadFrequently: true })
  ctx.drawImage(img, 0, 0)

  const imageData = ctx.getImageData(0, 0, img.width, img.height)
  const pixels = imageData.data

  const lenView = new DataView(new ArrayBuffer(4))
  lenView.setUint8(0, pixels[0])
  lenView.setUint8(1, pixels[1])
  lenView.setUint8(2, pixels[2])
  lenView.setUint8(3, pixels[4])

  const dataLength = lenView.getUint32(0, false)

  const audioBytes = new Uint8Array(dataLength)
  for (let i = 0; i < dataLength; i++) {
    const byteIdx = i + 4
    const pixelIdx = Math.floor(byteIdx / 3) * 4
    const channel = byteIdx % 3
    audioBytes[i] = pixels[pixelIdx + channel]
  }

  return new Blob([audioBytes], { type: "audio/wav" })
}

window.addEventListener("play-audio", async (e) => {
  const url = e.detail.url
  const blob = await decodePNGToAudio(url)
  const audioUrl = URL.createObjectURL(blob)
  const audio = new Audio(audioUrl)

  const btn = e.target?.closest?.('.bubble-wrapper')
  if (btn) btn.classList.add('playing')

  audio.addEventListener('ended', () => {
    if (btn) btn.classList.remove('playing')
  })

  audio.play()
})

window.addEventListener("speak-tts", (e) => {
  const text = e.detail.text
  if (!text) return
  speechSynthesis.cancel()
  const utterance = new SpeechSynthesisUtterance(text)
  utterance.rate = 1.0
  utterance.pitch = 1.0
  utterance.lang = "en-US"
  speechSynthesis.speak(utterance)
})

window.addEventListener("play-admin-audio", async (e) => {
  const url = e.detail.url
  const blob = await decodePNGToAudio(url)
  const audioUrl = URL.createObjectURL(blob)
  const audio = new Audio(audioUrl)
  audio.play()
})

window.addEventListener("speak-onboard", (e) => {
  if (localStorage.getItem("voice_bbs_onboarded")) return
  localStorage.setItem("voice_bbs_onboarded", "1")
  const text = e.detail.text
  if (!text) return
  speechSynthesis.cancel()
  const utterance = new SpeechSynthesisUtterance(text)
  utterance.rate = 0.9
  utterance.pitch = 1.0
  utterance.lang = "en-US"
  speechSynthesis.speak(utterance)
})

window.addEventListener("create-room", async () => {
  const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute('content')
  await fetch('/api/create-room', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-csrf-token': csrfToken },
    body: JSON.stringify({ source: "board" }),
  })
  window.location.reload()
})

window.addEventListener("test-mic", async () => {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    stream.getTracks().forEach(t => t.stop())
    window.liveSocket.execJS(document.getElementById("test-page"), [["push", { event: "mic-result", value: { ok: true } }]])
  } catch (_) {
    window.liveSocket.execJS(document.getElementById("test-page"), [["push", { event: "mic-result", value: { ok: false } }]])
  }
})

window.addEventListener("play-sequence", async (e) => {
  const urls = e.detail.urls
  for (const url of urls) {
    const blob = await decodePNGToAudio(url)
    const audioUrl = URL.createObjectURL(blob)
    const audio = new Audio(audioUrl)
    await new Promise(resolve => {
      audio.addEventListener('ended', resolve)
      audio.play()
    })
  }
})
