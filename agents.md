# Voice BBS - Agent Context

## Architecture
- **Stack:** Elixir 1.17 + Phoenix 1.7.14 + LiveView + Ecto + Postgrex
- **DB:** PostgreSQL (Ecto)
- **Deploy:** Railway (Docker + mix release)
- **Repo:** https://github.com/bonsai/voice_bbs
- **Live:** https://bubblevoice.up.railway.app

## Data Model
- `posts` table: id(binary_id), device_id, url, duration, filename, source, room_id, inserted_at, updated_at
- Source values: "board", "yon", "test"
- room_id: UUID for grouping posts into rooms (nullable)

## API Endpoints
| Method | Path | Desc |
|--------|------|------|
| GET | /api/posts | All posts JSON |
| GET | /api/tree | Tree: rooms + sources |
| GET | /api/count/:device_id | Count by device |
| POST | /api/upload | Upload audio (image_base64, duration, device_id, source) |
| POST | /api/new | Create room (returns room_id) |
| POST | /api/migrate | Run DB migrations |
| DELETE | /api/posts/:id | Delete post (DB + file) |
| GET | /healthz | Health check |

## Pages
| Path | Type | Feature |
|------|------|---------|
| / | BoardLive | Main: command bubbles + voice bubbles + recorder |
| /yon | YonLive | Same as / but source=yon |
| /admin | AdminLive | Manage: list, play, delete (shows source/room tags) |
| /test | TestLive | DB check, mic test, post count, create room |
| /api-list | ApiLive | HTML API reference |

## Key Features
- **Audio:** Record WebM(Opus 32kbps) → decode → trim silence(RMS) → WAV → encode PNG → upload
- **Playback:** Fetch PNG → decode bytes → WAV blob → Audio()
- **Command bubbles:** Purple-pink gradient circles for nav (test, yon, new, admin)
- **Voice bubbles:** Soap-bubble style for recorded audio
- **Onboarding:** TTS welcome on first visit (localStorage flag)
- **Max 4 posts per device_id**

## Infrastructure
- **Railway:** Docker multi-stage build (builder → debian:bookworm-slim)
- **Volume:** `/data` mounted for persistent uploads (UPLOADS_DIR=/data/uploads)
- **SSL:** Disabled for internal Railway DB (RAILWAY_SERVICE_ID detected)
- **Migrations:** Manual via `POST /api/migrate` after deploy

## CI/CD
- GitHub Actions: `.github/workflows/deploy.yml` (auto-deploy on push to master via flyctl)
- Railway auto-deploys on push to master

## TODO / Known Issues
- [ ] Old uploads 404 after deploy without volume (expected: lost on ephemeral FS)
- [ ] DB migration must run manually after deploy: `POST /api/migrate`
- [ ] 4-post limit per device_id may need admin override
- [ ] mix voice CLI only works locally (Elixir version mismatch 1.14 vs 1.17)
- [ ] No auth on admin page / API delete
