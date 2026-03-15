#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LITELLM_DIR="$REPO_ROOT/infra/litellm"
LOG_DIR="$LITELLM_DIR/logs"
BIN_DIR="$LITELLM_DIR/bin"

mkdir -p "$LITELLM_DIR" "$LOG_DIR" "$BIN_DIR"

echo "=================================================="
echo " LiteLLM Router Bootstrap for macOS"
echo " Repo: $REPO_ROOT"
echo " Dir : $LITELLM_DIR"
echo "=================================================="
echo

# ---------- prerequisites ----------
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing command: $1"
    exit 1
  }
}

need_cmd python3
need_cmd pip3
need_cmd curl

echo "[1/9] Installing LiteLLM proxy dependencies ..."
python3 -m pip install --upgrade pip >/dev/null
python3 -m pip install --upgrade "litellm[proxy]" pyyaml requests >/dev/null

echo "[2/9] Collecting provider keys ..."
read -r -s -p "Alibaba Bailian API Key: " BAILIAN_API_KEY
echo
read -r -s -p "MiniMax Coding Plan API Key: " MINIMAX_API_KEY
echo
read -r -s -p "Google Gemini API Key: " GEMINI_API_KEY
echo

echo
echo "[3/9] Model defaults (press Enter to accept defaults)"
echo "Bailian defaults:"
read -r -p "  BAILIAN_FAST_MODEL     [qwen-flash]: " BAILIAN_FAST_MODEL
BAILIAN_FAST_MODEL="${BAILIAN_FAST_MODEL:-qwen-flash}"
read -r -p "  BAILIAN_BALANCED_MODEL [qwen-plus]: " BAILIAN_BALANCED_MODEL
BAILIAN_BALANCED_MODEL="${BAILIAN_BALANCED_MODEL:-qwen-plus}"
read -r -p "  BAILIAN_DEEP_MODEL     [qwen-max]: " BAILIAN_DEEP_MODEL
BAILIAN_DEEP_MODEL="${BAILIAN_DEEP_MODEL:-qwen-max}"
read -r -p "  BAILIAN_CODE_MODEL     [qwen3-coder-plus]: " BAILIAN_CODE_MODEL
BAILIAN_CODE_MODEL="${BAILIAN_CODE_MODEL:-qwen3-coder-plus}"

echo "MiniMax defaults:"
read -r -p "  MINIMAX_FAST_MODEL     [MiniMax-M2.5-highspeed]: " MINIMAX_FAST_MODEL
MINIMAX_FAST_MODEL="${MINIMAX_FAST_MODEL:-MiniMax-M2.5-highspeed}"
read -r -p "  MINIMAX_BALANCED_MODEL [MiniMax-M2.5]: " MINIMAX_BALANCED_MODEL
MINIMAX_BALANCED_MODEL="${MINIMAX_BALANCED_MODEL:-MiniMax-M2.5}"
read -r -p "  MINIMAX_CODE_MODEL     [MiniMax-M2.5]: " MINIMAX_CODE_MODEL
MINIMAX_CODE_MODEL="${MINIMAX_CODE_MODEL:-MiniMax-M2.5}"

echo "Gemini defaults:"
read -r -p "  GEMINI_FAST_MODEL      [gemini-2.5-flash]: " GEMINI_FAST_MODEL
GEMINI_FAST_MODEL="${GEMINI_FAST_MODEL:-gemini-2.5-flash}"
read -r -p "  GEMINI_DEEP_MODEL      [gemini-2.5-pro]: " GEMINI_DEEP_MODEL
GEMINI_DEEP_MODEL="${GEMINI_DEEP_MODEL:-gemini-2.5-pro}"

echo
echo "[4/9] Writing .env ..."
cat > "$LITELLM_DIR/.env" <<EOF
# Provider Keys
BAILIAN_API_KEY=${BAILIAN_API_KEY}
MINIMAX_API_KEY=${MINIMAX_API_KEY}
GEMINI_API_KEY=${GEMINI_API_KEY}

# Provider Endpoints
BAILIAN_API_BASE=https://dashscope.aliyuncs.com/compatible-mode/v1
MINIMAX_API_BASE=https://api.minimax.io/v1

# Model Defaults
BAILIAN_FAST_MODEL=${BAILIAN_FAST_MODEL}
BAILIAN_BALANCED_MODEL=${BAILIAN_BALANCED_MODEL}
BAILIAN_DEEP_MODEL=${BAILIAN_DEEP_MODEL}
BAILIAN_CODE_MODEL=${BAILIAN_CODE_MODEL}

MINIMAX_FAST_MODEL=${MINIMAX_FAST_MODEL}
MINIMAX_BALANCED_MODEL=${MINIMAX_BALANCED_MODEL}
MINIMAX_CODE_MODEL=${MINIMAX_CODE_MODEL}

GEMINI_FAST_MODEL=${GEMINI_FAST_MODEL}
GEMINI_DEEP_MODEL=${GEMINI_DEEP_MODEL}

# LiteLLM
LITELLM_MASTER_KEY=sk-local-litellm-admin
LITELLM_PORT=4000

# Soft budget placeholder (local-only; not hard-enforced by LiteLLM without DB-backed virtual keys)
SOFT_DAILY_BUDGET_USD=5.00
EOF
chmod 600 "$LITELLM_DIR/.env"

echo "[5/9] Writing production-grade LiteLLM config.yaml ..."
cat > "$LITELLM_DIR/config.yaml" <<'EOF'
model_list:
  # ------------------------------------------
  # chat_fast = low latency / cheap-first
  # order works with enable_pre_call_checks: true
  # ------------------------------------------
  - model_name: chat_fast
    litellm_params:
      model: openai/os.environ/BAILIAN_FAST_MODEL
      api_base: os.environ/BAILIAN_API_BASE
      api_key: os.environ/BAILIAN_API_KEY
      order: 1
      rpm: 300
      timeout: 25
    model_info:
      health_check_timeout: 8
      health_check_max_tokens: 2

  - model_name: chat_fast
    litellm_params:
      model: openai/os.environ/MINIMAX_FAST_MODEL
      api_base: os.environ/MINIMAX_API_BASE
      api_key: os.environ/MINIMAX_API_KEY
      order: 2
      rpm: 240
      timeout: 30
    model_info:
      health_check_timeout: 8
      health_check_max_tokens: 2

  - model_name: chat_fast
    litellm_params:
      model: gemini/os.environ/GEMINI_FAST_MODEL
      api_key: os.environ/GEMINI_API_KEY
      order: 3
      rpm: 120
      timeout: 35
    model_info:
      health_check_timeout: 10
      health_check_max_tokens: 2

  # ------------------------------------------
  # chat_balanced = general purpose
  # ------------------------------------------
  - model_name: chat_balanced
    litellm_params:
      model: openai/os.environ/BAILIAN_BALANCED_MODEL
      api_base: os.environ/BAILIAN_API_BASE
      api_key: os.environ/BAILIAN_API_KEY
      order: 1
      rpm: 180
      timeout: 45
    model_info:
      health_check_timeout: 10
      health_check_max_tokens: 3

  - model_name: chat_balanced
    litellm_params:
      model: openai/os.environ/MINIMAX_BALANCED_MODEL
      api_base: os.environ/MINIMAX_API_BASE
      api_key: os.environ/MINIMAX_API_KEY
      order: 2
      rpm: 150
      timeout: 45
    model_info:
      health_check_timeout: 10
      health_check_max_tokens: 3

  - model_name: chat_balanced
    litellm_params:
      model: gemini/os.environ/GEMINI_DEEP_MODEL
      api_key: os.environ/GEMINI_API_KEY
      order: 3
      rpm: 60
      timeout: 60
    model_info:
      health_check_timeout: 12
      health_check_max_tokens: 3

  # ------------------------------------------
  # reasoning_deep = strongest complex reasoning
  # ------------------------------------------
  - model_name: reasoning_deep
    litellm_params:
      model: openai/os.environ/BAILIAN_DEEP_MODEL
      api_base: os.environ/BAILIAN_API_BASE
      api_key: os.environ/BAILIAN_API_KEY
      order: 1
      rpm: 60
      timeout: 90
    model_info:
      health_check_timeout: 12
      health_check_max_tokens: 3

  - model_name: reasoning_deep
    litellm_params:
      model: openai/os.environ/MINIMAX_BALANCED_MODEL
      api_base: os.environ/MINIMAX_API_BASE
      api_key: os.environ/MINIMAX_API_KEY
      order: 2
      rpm: 60
      timeout: 90
    model_info:
      health_check_timeout: 12
      health_check_max_tokens: 3

  - model_name: reasoning_deep
    litellm_params:
      model: gemini/os.environ/GEMINI_DEEP_MODEL
      api_key: os.environ/GEMINI_API_KEY
      order: 3
      rpm: 30
      timeout: 90
    model_info:
      health_check_timeout: 15
      health_check_max_tokens: 3

  # ------------------------------------------
  # coding_primary = best coding path
  # ------------------------------------------
  - model_name: coding_primary
    litellm_params:
      model: openai/os.environ/BAILIAN_CODE_MODEL
      api_base: os.environ/BAILIAN_API_BASE
      api_key: os.environ/BAILIAN_API_KEY
      order: 1
      rpm: 120
      timeout: 90
    model_info:
      health_check_timeout: 12
      health_check_max_tokens: 3

  - model_name: coding_primary
    litellm_params:
      model: openai/os.environ/MINIMAX_CODE_MODEL
      api_base: os.environ/MINIMAX_API_BASE
      api_key: os.environ/MINIMAX_API_KEY
      order: 2
      rpm: 120
      timeout: 90
    model_info:
      health_check_timeout: 12
      health_check_max_tokens: 3

  - model_name: coding_primary
    litellm_params:
      model: gemini/os.environ/GEMINI_DEEP_MODEL
      api_key: os.environ/GEMINI_API_KEY
      order: 3
      rpm: 30
      timeout: 90
    model_info:
      health_check_timeout: 15
      health_check_max_tokens: 3

  # ------------------------------------------
  # coding_fast = quicker code turnarounds
  # ------------------------------------------
  - model_name: coding_fast
    litellm_params:
      model: openai/os.environ/MINIMAX_FAST_MODEL
      api_base: os.environ/MINIMAX_API_BASE
      api_key: os.environ/MINIMAX_API_KEY
      order: 1
      rpm: 180
      timeout: 45
    model_info:
      health_check_timeout: 8
      health_check_max_tokens: 2

  - model_name: coding_fast
    litellm_params:
      model: openai/os.environ/BAILIAN_CODE_MODEL
      api_base: os.environ/BAILIAN_API_BASE
      api_key: os.environ/BAILIAN_API_KEY
      order: 2
      rpm: 120
      timeout: 60
    model_info:
      health_check_timeout: 10
      health_check_max_tokens: 2

  - model_name: coding_fast
    litellm_params:
      model: gemini/os.environ/GEMINI_FAST_MODEL
      api_key: os.environ/GEMINI_API_KEY
      order: 3
      rpm: 60
      timeout: 60
    model_info:
      health_check_timeout: 10
      health_check_max_tokens: 2

  # ------------------------------------------
  # summary_economy = cheap summarize / classify
  # ------------------------------------------
  - model_name: summary_economy
    litellm_params:
      model: openai/os.environ/BAILIAN_FAST_MODEL
      api_base: os.environ/BAILIAN_API_BASE
      api_key: os.environ/BAILIAN_API_KEY
      order: 1
      rpm: 300
      timeout: 20
    model_info:
      health_check_timeout: 6
      health_check_max_tokens: 1

  - model_name: summary_economy
    litellm_params:
      model: gemini/os.environ/GEMINI_FAST_MODEL
      api_key: os.environ/GEMINI_API_KEY
      order: 2
      rpm: 120
      timeout: 25
    model_info:
      health_check_timeout: 8
      health_check_max_tokens: 1

router_settings:
  routing_strategy: simple-shuffle
  enable_pre_call_checks: true
  num_retries: 1
  fallbacks:
    - {"coding_primary": ["coding_fast", "chat_balanced", "reasoning_deep"]}
    - {"coding_fast": ["coding_primary", "chat_balanced"]}
    - {"reasoning_deep": ["chat_balanced", "chat_fast"]}
    - {"chat_balanced": ["chat_fast", "reasoning_deep"]}
    - {"summary_economy": ["chat_fast", "chat_balanced"]}

general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
  health_check_details: false
EOF

echo "[6/9] Writing helper scripts ..."

cat > "$BIN_DIR/run.sh" <<'EOF'
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
EOF
chmod +x "$BIN_DIR/run.sh"

cat > "$BIN_DIR/stop.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
pkill -f "litellm --config" || true
EOF
chmod +x "$BIN_DIR/stop.sh"

cat > "$BIN_DIR/probe_providers.sh" <<'EOF'
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
EOF
chmod +x "$BIN_DIR/probe_providers.sh"

cat > "$BIN_DIR/check_proxy.sh" <<'EOF'
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
EOF
chmod +x "$BIN_DIR/check_proxy.sh"

cat > "$BIN_DIR/bench.py" <<'EOF'
#!/usr/bin/env python3
import json
import os
import time
import requests

BASE_URL = f"http://127.0.0.1:{os.getenv('LITELLM_PORT', '4000')}/v1/chat/completions"
MODELS = [
    "chat_fast",
    "chat_balanced",
    "reasoning_deep",
    "coding_primary",
    "coding_fast",
    "summary_economy",
]

PROMPTS = {
    "chat_fast": "用一句话介绍你自己。",
    "chat_balanced": "请用三点总结 LiteLLM 的作用。",
    "reasoning_deep": "比较本地代理路由和直接调用多个 API 的优缺点，输出五点。",
    "coding_primary": "写一个 Python 函数，返回 1 到 n 中的质数列表。",
    "coding_fast": "写一个 bash 命令，统计当前目录下 .py 文件数量。",
    "summary_economy": "把这句话压缩成 8 个字：LiteLLM is a local model gateway."
}

def run_one(model):
    payload = {
        "model": model,
        "messages": [{"role": "user", "content": PROMPTS[model]}],
        "temperature": 0.2,
        "max_tokens": 180,
    }
    t0 = time.time()
    r = requests.post(BASE_URL, json=payload, timeout=120)
    elapsed = time.time() - t0
    result = {
        "model": model,
        "status_code": r.status_code,
        "elapsed_sec": round(elapsed, 3),
        "ok": False,
    }
    try:
        data = r.json()
    except Exception:
        result["error"] = r.text[:500]
        return result

    if r.status_code != 200:
        result["error"] = json.dumps(data)[:500]
        return result

    usage = data.get("usage", {}) or {}
    total_tokens = usage.get("total_tokens")
    output_tokens = usage.get("completion_tokens")
    result["ok"] = True
    result["total_tokens"] = total_tokens
    result["completion_tokens"] = output_tokens
    result["approx_total_tok_per_sec"] = round(total_tokens / elapsed, 2) if total_tokens and elapsed > 0 else None
    result["approx_output_tok_per_sec"] = round(output_tokens / elapsed, 2) if output_tokens and elapsed > 0 else None
    try:
        result["preview"] = data["choices"][0]["message"]["content"][:120]
    except Exception:
        result["preview"] = "<no preview>"
    return result

def main():
    print("=== LiteLLM Bench ===")
    rows = [run_one(m) for m in MODELS]
    print(json.dumps(rows, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
EOF
chmod +x "$BIN_DIR/bench.py"

echo "[7/9] Provider connectivity pre-check ..."
set +e
"$BIN_DIR/probe_providers.sh"
PROBE_RC=$?
set -e
if [ "$PROBE_RC" -ne 0 ]; then
  echo
  echo "WARNING: raw provider probe had at least one failure."
  echo "We'll still continue so you can inspect proxy startup behavior."
fi

echo "[8/9] Starting LiteLLM ..."
"$BIN_DIR/stop.sh" >/dev/null 2>&1 || true
nohup "$BIN_DIR/run.sh" > "$LOG_DIR/bootstrap.out" 2>&1 &
sleep 6

echo "[9/9] Proxy health checks ..."
set +e
"$BIN_DIR/check_proxy.sh"
CHECK_RC=$?
set -e

echo
echo "=================================================="
echo " LiteLLM bootstrap complete"
echo "=================================================="
echo "Directory : $LITELLM_DIR"
echo "Run       : $BIN_DIR/run.sh"
echo "Stop      : $BIN_DIR/stop.sh"
echo "Probe     : $BIN_DIR/probe_providers.sh"
echo "Bench     : $BIN_DIR/bench.py"
echo "Log       : $LOG_DIR/litellm.log"
echo
echo "OpenClaw should point to:"
echo "  base_url = http://127.0.0.1:4000/v1"
echo "  api_key  = sk-local-litellm-admin"
echo
if [ "$CHECK_RC" -ne 0 ]; then
  echo "Proxy health check did not fully pass."
  echo "Read logs:"
  echo "  tail -n 200 $LOG_DIR/litellm.log"
  exit 2
fi

echo "Next:"
echo "  python3 $BIN_DIR/bench.py"
