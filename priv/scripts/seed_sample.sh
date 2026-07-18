#!/usr/bin/env bash
# サンプルデータ投入スクリプト
# Usage: ./seed_sample.sh [BASE_URL]
set -euo pipefail

BASE="${1:-http://localhost:4000}"
PNG_B64="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVQI12NgAAIABQABNjN9MAAAAABJRU5ErkJggg=="

echo "=== Seeding sample data to $BASE ==="

# テストデバイス
for i in 1 2 3; do
  echo "[$i/3] upload (board, device=test-seed-board)"
  curl -s -X POST "$BASE/api/upload" \
    -H "Content-Type: application/json" \
    -d "{\"image_base64\":\"$PNG_B64\",\"duration\":$(echo "1 + $i * 0.5" | bc),\"device_id\":\"test-seed-board\",\"source\":\"board\"}" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"  ok={d['ok']} id={d.get('id','')[:8]}...\")"
  sleep 0.1
done

# yon ソース
for i in 1 2; do
  echo "[$i/2] upload (yon, device=test-seed-yon)"
  curl -s -X POST "$BASE/api/upload" \
    -H "Content-Type: application/json" \
    -d "{\"image_base64\":\"$PNG_B64\",\"duration\":$(echo "2 + $i * 0.3" | bc),\"device_id\":\"test-seed-yon\",\"source\":\"yon\"}" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"  ok={d['ok']} id={d.get('id','')[:8]}...\")"
  sleep 0.1
done

# ルーム作成
echo "[room] create-room (test)"
curl -s -X POST "$BASE/api/create-room" \
  -H "Content-Type: application/json" \
  -d '{"source":"test","device_id":"test-seed-room"}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"  ok={d['ok']} room={d.get('room_id','')[:8]}...\")"

echo ""
echo "=== Seed complete ==="
echo ""
echo "Summary:"
curl -s "$BASE/api/posts" | python3 -c "
import sys, json
d = json.load(sys.stdin)
posts = d['posts']
sources = {}
for p in posts:
    s = p.get('source','?')
    sources[s] = sources.get(s, 0) + 1
print(f\"  Total posts: {len(posts)}\")
for s, c in sources.items():
    print(f\"  - {s}: {c}\")
"
