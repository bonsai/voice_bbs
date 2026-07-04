const MAX_DURATION = 30

function encodeBytesAsPNG(bytes) {
  const dataLength = bytes.length
  const totalBytes = 4 + dataLength
  const numPixels = Math.ceil(totalBytes / 3)
  const width = Math.ceil(Math.sqrt(numPixels))
  const height = Math.ceil(numPixels / width)

  const canvas = document.createElement('canvas')
  canvas.width = width
  canvas.height = height
  const ctx = canvas.getContext('2d', { willReadFrequently: true })
  const imageData = ctx.createImageData(width, height)

  const lenBytes = new Uint8Array(4)
  new DataView(lenBytes.buffer).setUint32(0, dataLength, false)

  const allBytes = new Uint8Array(totalBytes)
  allBytes.set(lenBytes, 0)
  allBytes.set(bytes, 4)

  for (let i = 0; i < numPixels; i++) {
    const byteIdx = i * 3
    const pixelIdx = i * 4
    imageData.data[pixelIdx] = allBytes[byteIdx] || 0
    imageData.data[pixelIdx + 1] = allBytes[byteIdx + 1] || 0
    imageData.data[pixelIdx + 2] = allBytes[byteIdx + 2] || 0
    imageData.data[pixelIdx + 3] = 255
  }

  ctx.putImageData(imageData, 0, 0)

  return new Promise((resolve) => {
    canvas.toBlob((blob) => {
      const reader = new FileReader()
      reader.onloadend = () => resolve(reader.result.split(',')[1])
      reader.readAsDataURL(blob)
    }, 'image/png')
  })
}

function bubbleSizePx(duration) {
  const scale = Math.min(duration / MAX_DURATION, 1)
  return Math.round(56 + scale * 104)
}

function audioBufferToWav(buffer) {
  const numChannels = buffer.numberOfChannels
  const sampleRate = buffer.sampleRate
  const format = 1
  const bitsPerSample = 16
  const data = buffer.getChannelData(0)
  const byteRate = sampleRate * numChannels * bitsPerSample / 8
  const blockAlign = numChannels * bitsPerSample / 8
  const dataSize = data.length * blockAlign
  const headerSize = 44
  const totalSize = headerSize + dataSize

  const wav = new ArrayBuffer(totalSize)
  const view = new DataView(wav)

  function writeString(offset, s) {
    for (let i = 0; i < s.length; i++) view.setUint8(offset + i, s.charCodeAt(i))
  }

  writeString(0, 'RIFF')
  view.setUint32(4, totalSize - 8, true)
  writeString(8, 'WAVE')
  writeString(12, 'fmt ')
  view.setUint32(16, 16, true)
  view.setUint16(20, format, true)
  view.setUint16(22, numChannels, true)
  view.setUint32(24, sampleRate, true)
  view.setUint32(28, byteRate, true)
  view.setUint16(32, blockAlign, true)
  view.setUint16(34, bitsPerSample, true)
  writeString(36, 'data')
  view.setUint32(40, dataSize, true)

  let offset = 44
  for (let i = 0; i < data.length; i++) {
    const sample = Math.max(-1, Math.min(1, data[i]))
    const int16 = sample < 0 ? sample * 0x8000 : sample * 0x7FFF
    view.setInt16(offset, int16, true)
    offset += 2
  }

  return new Uint8Array(wav)
}

async function trimWebmToWav(arrayBuffer) {
  const audioCtx = new AudioContext()
  let buffer
  try {
    buffer = await audioCtx.decodeAudioData(arrayBuffer.slice(0))
  } finally {
    audioCtx.close()
  }

  const samples = buffer.getChannelData(0)
  const sampleRate = buffer.sampleRate
  const windowSize = Math.floor(sampleRate * 0.02)

  let rmsWindow = 0
  for (let i = 0; i < Math.min(windowSize, samples.length); i++) {
    rmsWindow += samples[i] * samples[i]
  }

  const silenceThreshold = 0.003

  let startSample = 0
  for (let i = 0; i < samples.length - windowSize; i++) {
    const rms = Math.sqrt(rmsWindow / windowSize)
    if (rms > silenceThreshold) {
      startSample = Math.max(0, i - Math.floor(sampleRate * 0.05))
      break
    }
    rmsWindow -= samples[i] * samples[i]
    rmsWindow += samples[i + windowSize] * samples[i + windowSize]
  }

  rmsWindow = 0
  for (let i = Math.max(0, samples.length - windowSize); i < samples.length; i++) {
    rmsWindow += samples[i] * samples[i]
  }

  let endSample = samples.length
  for (let i = samples.length - 1; i >= windowSize; i--) {
    const rms = Math.sqrt(rmsWindow / windowSize)
    if (rms > silenceThreshold) {
      endSample = Math.min(samples.length, i + Math.floor(sampleRate * 0.05))
      break
    }
    rmsWindow -= samples[i] * samples[i]
    rmsWindow += samples[i - windowSize] * samples[i - windowSize]
  }

  if (endSample <= startSample + sampleRate * 0.1) {
    endSample = samples.length
    startSample = 0
  }

  const trimmedLength = endSample - startSample
  const trimmed = buffer.copyFromChannel(new Float32Array(trimmedLength), 0, startSample)

  const outBuffer = new AudioContext().createBuffer(1, trimmedLength, sampleRate)
  outBuffer.copyToChannel(trimmed, 0, 0)

  return { wavBytes: audioBufferToWav(outBuffer), duration: trimmedLength / sampleRate }
}

export const AudioRecorder = {
  mounted() {
    this.mediaRecorder = null
    this.chunks = []
    this.stream = null
    this.startTime = 0
    this.timerInterval = null
    this.audioCtx = null
    this.analyser = null
    this.dataArray = null
    this.animFrameId = null
    this.maxVolume = 0
    this.deviceId = this.getDeviceId()

    this.btn = this.el.querySelector('#record-btn')
    this.timer = this.el.querySelector('#timer')
    this.preview = this.el.querySelector('#preview-bubble')
    this.canvas = this.el.querySelector('#waveform-canvas')
    this.slots = this.el.querySelector('#slots')

    this.fetchInitialCount()

    const onDown = (e) => {
      e.preventDefault()
      if (this.slots.querySelectorAll('.used').length >= 4) {
        this.btn.classList.add('recording')
        setTimeout(() => this.btn.classList.remove('recording'), 600)
        return
      }
      this.startRecording()
    }
    const onUp = (e) => {
      e.preventDefault()
      this.stopRecording()
    }

    this.btn.addEventListener('pointerdown', onDown)
    this.btn.addEventListener('pointerup', onUp)
    this.btn.addEventListener('pointerleave', () => {
      if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
        this.stopRecording()
      }
    })
    this.btn.addEventListener('touchstart', onDown)
    this.btn.addEventListener('touchend', onUp)
  },

  getDeviceId() {
    let id = localStorage.getItem('voice_bbs_device_id')
    if (!id) {
      id = crypto.randomUUID()
      localStorage.setItem('voice_bbs_device_id', id)
    }
    return id
  },

  async fetchInitialCount() {
    try {
      const res = await fetch(`/api/count/${this.deviceId}`)
      const data = await res.json()
      if (data.ok) this.updateSlots(data.count)
    } catch (_) {}
  },

  updateSlots(count) {
    const dots = this.slots.querySelectorAll('.slot-dot')
    dots.forEach((dot, i) => {
      dot.className = 'slot-dot'
      if (i < count) dot.classList.add('used')
    })
  },

  async startRecording() {
    if (this.mediaRecorder && this.mediaRecorder.state === 'recording') return
    clearInterval(this.timerInterval)
    this.timerInterval = null
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      const mimeType = MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
        ? 'audio/webm;codecs=opus'
        : 'audio/webm'

      this.mediaRecorder = new MediaRecorder(this.stream, {
        mimeType: mimeType,
        audioBitsPerSecond: 32000,
      })
      this.chunks = []

      this.mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) this.chunks.push(e.data)
      }

      this.mediaRecorder.onstop = async () => {
        this.cleanupAudio()
        this.stream.getTracks().forEach((t) => t.stop())
        this.btn.classList.remove('recording')
        this.timer.classList.add('hidden')
        this.preview.classList.add('hidden')
        this.preview.style.width = '0px'
        this.preview.style.height = '0px'
        clearInterval(this.timerInterval)

        if (this.chunks.length === 0) return

        if (this.maxVolume < 5) {
          this.btn.classList.add('shake')
          setTimeout(() => this.btn.classList.remove('shake'), 400)
          return
        }

        const blob = new Blob(this.chunks, { type: 'audio/webm' })
        const arrayBuffer = await blob.arrayBuffer()

        const { wavBytes, duration } = await trimWebmToWav(arrayBuffer)

        if (duration < 0.3) {
          this.btn.classList.add('shake')
          setTimeout(() => this.btn.classList.remove('shake'), 400)
          return
        }

        const base64 = await encodeBytesAsPNG(wavBytes)

        const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute('content')
        const res = await fetch('/api/upload', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'x-csrf-token': csrfToken,
          },
          body: JSON.stringify({ image_base64: base64, duration: duration, device_id: this.deviceId }),
        })
        const data = await res.json()
        if (data.ok && typeof data.remaining === 'number') {
          this.updateSlots(4 - data.remaining)
        }
      }

      this.mediaRecorder.start()
      this.startTime = Date.now()

      this.btn.classList.add('recording')
      this.timer.classList.remove('hidden')
      this.preview.classList.remove('hidden')
      this.preview.classList.add('visible')

      this.setupWaveform()

      const updateBubble = () => {
        if (!this.mediaRecorder || this.mediaRecorder.state !== 'recording') return
        const elapsed = Math.min((Date.now() - this.startTime) / 1000, MAX_DURATION)
        const size = bubbleSizePx(elapsed)
        this.preview.style.width = size + 'px'
        this.preview.style.height = size + 'px'
        this.timer.textContent = `0:${String(Math.floor(elapsed)).padStart(2, '0')} / 0:30`
      }

      updateBubble()
      this.timerInterval = setInterval(updateBubble, 100)
    } catch (err) {
      console.error('Mic access denied', err)
    }
  },

  setupWaveform() {
    try {
      this.audioCtx = new AudioContext()
      const source = this.audioCtx.createMediaStreamSource(this.stream)
      this.analyser = this.audioCtx.createAnalyser()
      this.analyser.fftSize = 128
      this.dataArray = new Uint8Array(this.analyser.frequencyBinCount)
      source.connect(this.analyser)
      this.drawWaveform()
    } catch (err) {
      console.warn('Waveform unavailable', err)
    }
  },

  drawWaveform() {
    if (!this.analyser || !this.canvas) return
    this.animFrameId = requestAnimationFrame(() => this.drawWaveform())

    this.analyser.getByteFrequencyData(this.dataArray)

    const frameMax = Math.max(...this.dataArray)
    if (frameMax > this.maxVolume) this.maxVolume = frameMax

    const rect = this.canvas.getBoundingClientRect()
    const w = rect.width
    const h = rect.height
    if (w === 0 || h === 0) return

    this.canvas.width = w * devicePixelRatio
    this.canvas.height = h * devicePixelRatio
    const ctx = this.canvas.getContext('2d')
    ctx.scale(devicePixelRatio, devicePixelRatio)

    ctx.clearRect(0, 0, w, h)

    const barCount = this.dataArray.length
    const barW = w / barCount
    const halfH = h / 2

    for (let i = 0; i < barCount; i++) {
      const val = this.dataArray[i] / 255
      const barH = val * halfH * 0.9
      const x = i * barW
      const y = halfH - barH / 2

      const t = i / barCount
      const r = Math.round(168 + t * 68)
      const g = Math.round(85 - t * 13)
      const b = Math.round(247 - t * 108)
      ctx.fillStyle = `rgba(${r},${g},${b},0.7)`
      ctx.fillRect(x + 0.5, y, Math.max(barW - 1, 1), barH)
    }
  },

  cleanupAudio() {
    if (this.animFrameId) {
      cancelAnimationFrame(this.animFrameId)
      this.animFrameId = null
    }
    if (this.audioCtx) {
      this.audioCtx.close()
      this.audioCtx = null
    }
    this.analyser = null
    this.dataArray = null
    if (this.canvas) {
      const ctx = this.canvas.getContext('2d')
      if (ctx) ctx.clearRect(0, 0, this.canvas.width, this.canvas.height)
    }
  },

  stopRecording() {
    if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
      this.mediaRecorder.stop()
    }
  },

  destroyed() {
    this.cleanupAudio()
    clearInterval(this.timerInterval)
    if (this.stream) {
      this.stream.getTracks().forEach((t) => t.stop())
    }
  },
}
