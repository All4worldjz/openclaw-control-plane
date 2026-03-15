#!/usr/bin/env bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
set -a
source "$BASE_DIR/.env"
set +a

echo "== Bailian raw probe =="
curl -sS -m 20 \
  -H "Authorization: Bearer $BAILIAN_API_KEY" \
  "$BAILIAN_API_BASE/models" | head -c 500 ; echo
echo

echo "== MiniMax raw probe =="
curl -sS -m 20 \
  -H "Authorization: Bearer $MINIMAX_API_KEY" \
  "$MINIMAX_API_BASE/models" | head -c 500 ; echo
echo

echo "== Gemini raw probe =="
curl -sS -m 20 \
  "https://generativelanguage.googleapis.com/v1beta/models?key=$GEMINI_API_KEY" | head -c 500 ; echo
echo
