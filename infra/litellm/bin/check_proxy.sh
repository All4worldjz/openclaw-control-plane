#!/usr/bin/env bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
set -a
source "$BASE_DIR/.env"
set +a

PORT="${LITELLM_PORT:-4000}"

echo "== readiness =="
curl -sS "http://127.0.0.1:${PORT}/health/readiness" ; echo
echo

echo "== models =="
curl -sS "http://127.0.0.1:${PORT}/v1/models" ; echo
