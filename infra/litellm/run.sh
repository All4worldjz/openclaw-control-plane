#!/usr/bin/env bash

BASE_DIR=$(cd "$(dirname "$0")" && pwd)

echo "Starting LiteLLM proxy..."

litellm   --config $BASE_DIR/config.yaml   --port 4000   --host 0.0.0.0
