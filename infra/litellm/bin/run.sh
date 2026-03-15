#!/usr/bin/env bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
set -a
source "$BASE_DIR/.env"
set +a

mkdir -p "$BASE_DIR/logs"

exec litellm \
  --config "$BASE_DIR/config.yaml" \
  --port "${LITELLM_PORT:-4000}" \
  --host 127.0.0.1 \
  2>&1 | tee -a "$BASE_DIR/logs/litellm.log"
