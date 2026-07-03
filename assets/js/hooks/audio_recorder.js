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

export const AudioRecorder = {
  mounted() {
    this.mediaRecorder = null
    this.chunks = []
    this.stream = null
    this.startTime = 0
    this.timerInterval = null

    this.btn = this.el.querySelector('#record-btn')
    this.timer = this.el.querySelector('#timer')
    this.preview = this.el.querySelector('#preview-bubble')

    const onDown = (e) => {
      e.preventDefault()
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

  async startRecording() {
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      const mimeType = MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
        ? 'audio/webm;codecs=opus'
        : 'audio/webm'

      this.mediaRecorder = new MediaRecorder(this.stream, { mimeType })
      this.chunks = []

      this.mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) this.chunks.push(e.data)
      }

      this.mediaRecorder.onstop = async () => {
        this.stream.getTracks().forEach((t) => t.stop())
        this.btn.classList.remove('recording')
        this.timer.classList.add('hidden')
        this.preview.classList.add('hidden')
        this.preview.style.width = '0px'
        this.preview.style.height = '0px'
        clearInterval(this.timerInterval)

        if (this.chunks.length === 0) return

        const duration = Math.min((Date.now() - this.startTime) / 1000, MAX_DURATION)

        const blob = new Blob(this.chunks, { type: 'audio/webm' })
        const arrayBuffer = await blob.arrayBuffer()
        const bytes = new Uint8Array(arrayBuffer)

        const base64 = await encodeBytesAsPNG(bytes)

        const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute('content')
        await fetch('/api/upload', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'x-csrf-token': csrfToken,
          },
          body: JSON.stringify({ image_base64: base64, duration: duration }),
        })
      }

      this.mediaRecorder.start()
      this.startTime = Date.now()

      this.btn.classList.add('recording')
      this.timer.classList.remove('hidden')
      this.preview.classList.remove('hidden')
      this.preview.classList.add('visible')

      const updateBubble = () => {
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

  stopRecording() {
    if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
      this.mediaRecorder.stop()
    }
  },

  destroyed() {
    clearInterval(this.timerInterval)
    if (this.stream) {
      this.stream.getTracks().forEach((t) => t.stop())
    }
  },
}
