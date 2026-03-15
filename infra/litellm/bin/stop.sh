#!/usr/bin/env bash
set -euo pipefail
pkill -f "litellm --config" || true
