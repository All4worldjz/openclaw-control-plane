#!/usr/bin/env bash
set -e

echo "========================================="
echo " LiteLLM Local Gateway Bootstrap"
echo " MacOS Intel / OpenClaw Control Plane"
echo "========================================="

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LITELLM_DIR="$BASE_DIR/infra/litellm"

echo "Repo root: $BASE_DIR"
echo "LiteLLM dir: $LITELLM_DIR"

mkdir -p "$LITELLM_DIR"

########################################
echo
echo "Step 1: Checking Python"

if ! command -v python3 &> /dev/null
then
    echo "Python3 not found. Install via Homebrew:"
    echo "brew install python"
    exit 1
fi

python3 --version

########################################
echo
echo "Step 2: Installing LiteLLM"

pip3 install --upgrade pip
pip3 install 'litellm[proxy]' pyyaml

########################################
echo
echo "Step 3: Creating LiteLLM config"

CONFIG_FILE="$LITELLM_DIR/config.yaml"

cat > "$CONFIG_FILE" <<EOF
model_list:

  - model_name: qwen-coder
    litellm_params:
      model: openai/qwen-coder
      api_base: https://coding.dashscope.aliyuncs.com/v1
      api_key: \$BAILIAN_API_KEY

  - model_name: minimax-coder
    litellm_params:
      model: openai/minimax-text-01
      api_base: https://api.minimax.io/v1
      api_key: \$MINIMAX_API_KEY

  - model_name: gemini-pro
    litellm_params:
      model: gemini/gemini-1.5-pro
      api_key: \$GEMINI_API_KEY

router_settings:

  routing_strategy: simple-shuffle

  fallbacks:

    qwen-coder:
      - minimax-coder
      - gemini-pro

    minimax-coder:
      - qwen-coder

general_settings:

  master_key: local-dev
EOF

echo "Config created:"
echo "$CONFIG_FILE"

########################################
echo
echo "Step 4: Creating run script"

RUN_SCRIPT="$LITELLM_DIR/run.sh"

cat > "$RUN_SCRIPT" <<EOF
#!/usr/bin/env bash

BASE_DIR=\$(cd "\$(dirname "\$0")" && pwd)

echo "Starting LiteLLM proxy..."

litellm \
  --config \$BASE_DIR/config.yaml \
  --port 4000 \
  --host 0.0.0.0
EOF

chmod +x "$RUN_SCRIPT"

########################################
echo
echo "Step 5: Creating test script"

TEST_SCRIPT="$LITELLM_DIR/test.sh"

cat > "$TEST_SCRIPT" <<EOF
#!/usr/bin/env bash

echo "Testing LiteLLM gateway..."

curl http://localhost:4000/v1/models
EOF

chmod +x "$TEST_SCRIPT"

########################################
echo
echo "Step 6: Environment variable reminder"

echo
echo "Add these to ~/.zshrc:"
echo

echo "export BAILIAN_API_KEY=YOUR_KEY"
echo "export MINIMAX_API_KEY=YOUR_KEY"
echo "export GEMINI_API_KEY=YOUR_KEY"

echo
echo "Then run:"
echo "source ~/.zshrc"

########################################
echo
echo "Step 7: Starting LiteLLM"

cd "$LITELLM_DIR"

./run.sh &
sleep 4

########################################
echo
echo "Step 8: Testing endpoint"

curl -s http://localhost:4000/v1/models | head

echo
echo "========================================="
echo " LiteLLM bootstrap complete"
echo " Gateway: http://localhost:4000"
echo "========================================="
