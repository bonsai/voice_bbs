#!/usr/bin/env bash
# API テストスクリプト
# Usage: ./test_api.sh [BASE_URL]
set -euo pipefail

BASE="${1:-http://localhost:4000}"
PASS=0
FAIL=0

assert() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ✓ $desc"
    PASS=$((PASS+1))
  else
    echo "  ✗ $desc (expected=$expected, got=$actual)"
    FAIL=$((FAIL+1))
  fi
}

echo "=== bubble-voice API Tests ==="
echo "Base: $BASE"
echo ""

# --- healthz ---
echo "[healthz]"
CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/api/healthz")
assert "GET /api/healthz → 200" "200" "$CODE"

# --- list posts ---
echo "[list posts]"
RESP=$(curl -s "$BASE/api/posts")
OK=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['ok'])" 2>/dev/null || echo "false")
assert "GET /api/posts → ok=true" "True" "$OK"

# --- count ---
echo "[count]"
RESP=$(curl -s "$BASE/api/count/test-device-001")
OK=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['ok'])" 2>/dev/null || echo "false")
COUNT=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['count'])" 2>/dev/null || echo "0")
assert "GET /api/count/:id → ok=true" "True" "$OK"
assert "GET /api/count/:id → count is int" "True" "$([[ "$COUNT" =~ ^[0-9]+$ ]] && echo True || echo False)"

# --- upload ---
echo "[upload]"
# 1x1 PNG (transparent pixel)
PNG_B64="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
RESP=$(curl -s -X POST "$BASE/api/upload" \
  -H "Content-Type: application/json" \
  -d "{\"image_base64\":\"$PNG_B64\",\"duration\":1.5,\"device_id\":\"test-api-script\",\"source\":\"test\"}")
OK=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['ok'])" 2>/dev/null || echo "false")
assert "POST /api/upload → ok=true" "True" "$OK"
POST_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null || echo "")
assert "POST /api/upload → returns id" "True" "$([[ -n "$POST_ID" ]] && echo True || echo False)"

# --- count after upload ---
echo "[count after upload]"
RESP=$(curl -s "$BASE/api/count/test-api-script")
COUNT=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['count'])" 2>/dev/null || echo "0")
assert "count increased after upload" "1" "$COUNT"

# --- delete ---
echo "[delete]"
if [ -n "$POST_ID" ]; then
  RESP=$(curl -s -X DELETE "$BASE/api/posts/$POST_ID")
  OK=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['ok'])" 2>/dev/null || echo "false")
  assert "DELETE /api/posts/:id → ok=true" "True" "$OK"
fi

# --- tree ---
echo "[tree]"
RESP=$(curl -s "$BASE/api/tree")
OK=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['ok'])" 2>/dev/null || echo "false")
assert "GET /api/tree → ok=true" "True" "$OK"

# --- create-room ---
echo "[create-room]"
RESP=$(curl -s -X POST "$BASE/api/create-room" \
  -H "Content-Type: application/json" \
  -d '{"source":"test","device_id":"test-room-script"}')
OK=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['ok'])" 2>/dev/null || echo "false")
ROOM_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['room_id'])" 2>/dev/null || echo "")
assert "POST /api/create-room → ok=true" "True" "$OK"
assert "POST /api/create-room → returns room_id" "True" "$([[ -n "$ROOM_ID" ]] && echo True || echo False)"

# --- migrate (idempotent) ---
echo "[migrate]"
RESP=$(curl -s -X POST "$BASE/api/migrate")
OK=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['ok'])" 2>/dev/null || echo "false")
assert "POST /api/migrate → ok=true" "True" "$OK"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
