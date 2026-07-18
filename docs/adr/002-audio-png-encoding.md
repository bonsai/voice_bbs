# ADR-002: 音声PNGエンコーディング方式

- **Status:** Accepted
- **Date:** 2026-07-18
- **Deciders:** onsen.bonsai

## Context

bubble-voice は「音声掲示板」であり、音声をシャボン玉（バブル）として表示する。
音声ファイルの永続保存方法を決定する必要がある。

## 選択肢

### 1. MP3ファイルとして保存

| 項目 | 内容 |
|------|------|
| **フォーマット** | MP3 (128kbps, ~1MB/分) |
| **メリット** | 汎用性高い、ブラウザ直接再生可 |
| **デメリット** | ファイルサイズ大、CDN/ストレージコスト増 |

### 2. PNG画素エンコーディング（採用）

| 項目 | 内容 |
|------|------|
| **フォーマット** | WAV → PNG画素に変換 |
| **メリット** | ファイルサイズ小 (~100KB/分)、画像としてCDN配信可、バブルUIに最適 |
| **デメリット** | 専用デコード必要、画質劣化（無視可能） |

## データフロー

```
録音: WebM(Opus 32kbps)
  ↓ decode
AudioBuffer
  ↓ trim silence (RMS)
WAV bytes
  ↓ encodeBytesAsPNG()
PNG image (画素に音声バイト格納)
  ↓ POST /api/upload
GCS (bubblevoice-uploads) or local FS
  ↓
DB posts.url に保存
```

```
再生: PNG fetch
  ↓ decodePNGToAudio()
画素から音声バイト抽出
  ↓
WAV Blob
  ↓ Audio()
再生
```

## 技術詳細

### エンコード (`audio_recorder.js`)

```javascript
// WAVバイト → PNG画素
function encodeBytesAsPNG(bytes) {
  const width = Math.ceil(Math.sqrt(bytes.length / 3))
  const height = Math.ceil(bytes.length / 3 / width)
  const canvas = document.createElement('canvas')
  canvas.width = width
  canvas.height = height
  const ctx = canvas.getContext('2d')
  // 各画素のR/G/Bに音声バイトを格納
  // 画素1つ = 3バイト (R, G, B)
  // 4画素目(Alpha)は不要分を0埋め
  // → canvas.toBlob() でPNG保存
}
```

### デコード (`app.js`)

```javascript
// PNG画素 → WAV Blob
async function decodePNGToAudio(url) {
  const img = new Image()
  img.src = url
  await img.decode()
  const canvas = document.createElement('canvas')
  canvas.width = img.width
  canvas.height = img.height
  const ctx = canvas.getContext('2d')
  ctx.drawImage(img, 0, 0)
  const { data: pixels } = ctx.getImageData(0, 0, img.width, img.height)
  // PNGヘッダーから実際の音声長を取得
  // 画素から音声バイトを復元
  return new Blob([audioBytes], { type: "audio/wav" })
}
```

## サイズ比較

| 方式 | 30秒音声 | 1分音声 |
|------|----------|---------|
| WebM(Opus 32kbps) | ~120KB | ~240KB |
| WAV (PCM 16bit 44.1kHz) | ~2.6MB | ~5.2MB |
| **PNG画素** | ~100KB | ~200KB |
| MP3 (128kbps) | ~480KB | ~960KB |

## 利点

1. **バブル表示**: PNGとして直接 `<img>` に設定可能
2. **CDN配信**: GCS公開URLで画像CDN経由配信
3. **軽量**: MP3の約1/4サイズ
4. **永続保存**: PNGは不変データとして保存容易

## 制約

- 再生には専用デコード処理が必要（`decodePNGToAudio`）
- 画素に音声データを格納するため、通常の画像として表示するとノイズが見える
- PNG品質設定は lossless（画質劣化なし）

## 現在の運用

- Cloud Run: GCS (`bubblevoice-uploads`) にPNG保存
- ローカル: `/data/uploads` にPNG保存
- URL形式: `https://storage.googleapis.com/bubblevoice-uploads/{id}.png`

## 参照

- `assets/js/hooks/audio_recorder.js` (encode)
- `assets/js/app.js:24` (decode)
- `lib/voice_bbs/posts.ex` (save/upload)
