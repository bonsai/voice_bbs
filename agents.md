# Voice BBS - Agent Context

## Architecture
- **Stack:** Elixir 1.17 + Phoenix 1.7.14 + LiveView + Ecto + Postgrex
- **DB:** PostgreSQL (Neon) + rooms.json (JSONL)
- **Deploy:** Cloud Run (asia-northeast1)
- **Repo:** https://github.com/bonsai/voice_bbs
- **Live:** https://bubblevoice-941146906074.asia-northeast1.run.app
- **GCP Project:** yok-ai-2026

## Data Model
- `posts` table: id(binary_id), device_id, url, duration, filename, source, room_id, inserted_at, updated_at
- `shiritori` table: id(binary_id), word, kana, audio_url, device_id, position, prev_id, inserted_at, updated_at
- `rooms.json`: id, name, type (voice/shiritori), open (boolean)

## API Endpoints
| Method | Path | Desc |
|--------|------|------|
| GET | /api/posts | All posts JSON |
| GET | /api/tree | Tree: rooms + sources |
| GET | /api/count/:device_id | Count by device |
| GET | /api/rooms | Rooms list JSON |
| GET | /api/tts?text=... | TTS (espeak) |
| POST | /api/upload | Upload audio (image_base64, duration, device_id, source, room_id) |
| POST | /api/new | Create room |
| POST | /api/migrate | Run DB migrations |
| DELETE | /api/posts/:id | Delete post |
| GET | /api/healthz | Health check |

## Pages
| Path | Type | Feature |
|------|------|---------|
| / | LandingLive | Step-by-step onboarding + room tiles (random positions) |
| /room/:id | RoomLive | Voice bubbles + recorder |
| /shiritori | ShiritoriLive | Word chain game with ASR + validation |
| /manage | ManageLive | Panel: posts/status/rooms tabs |

## Key Features
- **Audio:** Record WebM(Opus) → decode → trim silence → WAV → encode PNG → upload
- **Playback:** Fetch PNG → decode bytes → WAV blob → Audio()
- **Shiritori:** ASR input + kana validation + grayscale on error
- **UI:** Rainbow bubble shimmer, wobble animation, random room positions
- **Disconnect:** Grayscale overlay with "接続中..." text

## Infrastructure
- **Cloud Run:** 512Mi, 1vCPU, 0-2 instances, allow-unauthenticated
- **Neon DB:** bubblevoice project, aws-us-east-2
- **GCS:** bubblevoice-uploads (public read)
- **Auth:** Public mode (no token required for upload)

## Deploy
```bash
cd MEGA/voice_bbs
git add -A && git commit -m "message" && git push origin master
gcloud run deploy bubblevoice --source . --region asia-northeast1 --platform managed --allow-unauthenticated --project yok-ai-2026
```

## Known Issues
- [ ] マイクチェックがランディングページで動作しない (JS target要素問題)
- [ ] espeak未インストール (TTS API /api/tts は動作しない)
- [ ] モバイルPWA対応未実施
- [ ] 認証: publicモード (本格的な認証は未実装)
- [ ] HEExテンプレートのネスト引用符問題 (helper関数で回避済み)

## TODO
- [ ] TTS: espeak-ngをDockerfileに追加
- [ ] モバイルPWA対応
- [ ] カスタムドメイン
- [ ] 管理者認証
- [ ] 音声保存の永続化 (GCS)
