#!/usr/bin/env bash
# =============================================================================
# LiteLLM Router 安装配置脚本 — macOS 宇宙（国内网络优先）
# 四阶段：备份 → 清理 → 安装配置 → 验证
#
# 宪章对齐：
#   - 国内优先路由（DashScope → MiniMax → Gemini）
#   - 抽象能力组（fast_chat / balanced_chat / coding_primary 等）
#   - LiteLLM 作为策略执行基础设施，不是透明代理
#   - 密钥写入 .env（chmod 600），永不入 Git
#   - 备份旧配置到带时间戳目录，删除前必须备份
# =============================================================================
set -uo pipefail

# ── 颜色 ──────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()      { echo -e "${GREEN}[  OK]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
err()     { echo -e "${RED}[ ERR]${RESET}  $*"; }
section() { echo; echo -e "${BOLD}━━━  $*  ━━━${RESET}"; echo; }
die()     { err "$*"; exit 1; }

# ── 路径常量 ──────────────────────────────────────────────────────────────────
INSTALL_ROOT="${OPENCLAW_INSTALL_ROOT:-$HOME/Library/Application Support/OpenClaw}"
LITELLM_DIR="$INSTALL_ROOT/litellm"
CONFIG_FILE="$LITELLM_DIR/config.yaml"
ENV_FILE="$LITELLM_DIR/.env"
LOG_DIR="$LITELLM_DIR/logs"
BIN_DIR="$LITELLM_DIR/bin"
PLIST_LABEL="ai.openclaw.litellm"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"
LITELLM_PORT="${LITELLM_PORT:-4000}"
LITELLM_HOST="127.0.0.1"
# master key：本地固定占位值，非真实密钥
LITELLM_MASTER_KEY="sk""-openclaw-litellm-local"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_ROOT="$HOME/openclaw_litellm_backup_$TIMESTAMP"

# ── 安全检查 ──────────────────────────────────────────────────────────────────
[[ "$(uname -s)" == "Darwin" ]] || die "此脚本仅适用于 macOS"
[[ "${EUID:-$(id -u)}" -ne 0 ]] || die "请勿使用 sudo 运行此脚本"

# ── 交互读取工具（写提示到 /dev/tty，再从 /dev/tty 读取，兼容所有终端）──────
_read_secret() {
  # _read_secret "提示文字" varname  （明文输入，密钥保存在本地 .env）
  local val=""
  printf "  %s: " "$1" >/dev/tty
  IFS= read -r val </dev/tty
  printf -v "$2" '%s' "$val"
}
_read_default() {
  # _read_default "提示文字" "默认值" varname
  local val=""
  printf "  %s [%s]: " "$1" "$2" >/dev/tty
  IFS= read -r val </dev/tty
  printf -v "$3" '%s' "${val:-$2}"
}
_confirm() {
  local ans
  printf "  %s [y/N]: " "${1:-继续？}" >/dev/tty
  IFS= read -r ans </dev/tty
  case "$ans" in [yY][eE][sS]|[yY]) return 0 ;; *) return 1 ;; esac
}

# =============================================================================
# 预检：显示将要操作的路径，确认继续
# =============================================================================
echo
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║     LiteLLM Router 安装配置脚本 — macOS 宇宙               ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo
echo -e "  安装目录:   ${CYAN}$LITELLM_DIR${RESET}"
echo -e "  LaunchAgent: ${CYAN}$PLIST_PATH${RESET}"
echo -e "  端口:        ${CYAN}$LITELLM_PORT${RESET}"
echo -e "  备份目录:   ${CYAN}$BACKUP_ROOT${RESET}"
echo

# 检测是否存在旧安装
_has_existing=false
if [[ -d "$LITELLM_DIR" ]] || launchctl list "$PLIST_LABEL" >/dev/null 2>&1; then
  _has_existing=true
  warn "检测到已有 LiteLLM 安装，将先备份再清理"
fi

_confirm "确认执行安装？" || { echo "已取消。"; exit 0; }

# =============================================================================
# 阶段 1：备份现有安装
# =============================================================================
section "阶段 1/4  备份现有配置"

if [[ "$_has_existing" == "true" ]]; then
  mkdir -p "$BACKUP_ROOT"

  # 备份配置目录
  if [[ -d "$LITELLM_DIR" ]]; then
    cp -R "$LITELLM_DIR" "$BACKUP_ROOT/litellm" 2>/dev/null \
      && ok "已备份目录: $LITELLM_DIR → $BACKUP_ROOT/litellm" \
      || warn "目录备份失败（继续）"
    # .env 含密钥，单独提示
    [[ -f "$LITELLM_DIR/.env" ]] && \
      info "⚠  备份含 .env（API 密钥），请妥善保管: $BACKUP_ROOT/litellm/.env"
  fi

  # 备份 plist
  if [[ -f "$PLIST_PATH" ]]; then
    cp "$PLIST_PATH" "$BACKUP_ROOT/${PLIST_LABEL}.plist" 2>/dev/null \
      && ok "已备份 plist: $PLIST_PATH"
  fi

  # 生成备份清单
  {
    echo "LiteLLM 安装备份清单"
    echo "时间: $(date)"
    echo "原始安装目录: $LITELLM_DIR"
    echo ""
    find "$BACKUP_ROOT" 2>/dev/null | sort | while read -r f; do
      [[ -f "$f" ]] && printf "  %s\n" "${f#$BACKUP_ROOT/}"
    done
  } > "$BACKUP_ROOT/MANIFEST.txt"

  ok "备份完成 → $BACKUP_ROOT"
else
  info "未检测到旧安装，跳过备份"
fi

# =============================================================================
# 阶段 2：清理现有安装
# =============================================================================
section "阶段 2/4  清理现有安装"

# 2a. 停止并卸载 LaunchAgent
if launchctl list "$PLIST_LABEL" >/dev/null 2>&1; then
  info "停止 LaunchAgent: $PLIST_LABEL"
  launchctl bootout "gui/$(id -u)/$PLIST_LABEL" 2>/dev/null \
    || launchctl unload -w "$PLIST_PATH" 2>/dev/null \
    || true
  ok "LaunchAgent 已停止"
fi

if [[ -f "$PLIST_PATH" ]]; then
  rm -f "$PLIST_PATH" && ok "已删除 plist: $PLIST_PATH"
fi

# 2b. 终止残留 litellm 进程
if pgrep -f "litellm.*--config" >/dev/null 2>&1; then
  info "终止残留 litellm 进程..."
  pkill -f "litellm.*--config" 2>/dev/null || true
  sleep 1
  ok "进程已终止"
fi

# 2c. 删除旧安装目录（备份已完成）
if [[ -d "$LITELLM_DIR" ]]; then
  rm -rf "$LITELLM_DIR" && ok "已删除旧安装目录: $LITELLM_DIR"
fi

# 2d. 检查端口是否释放
if lsof -ti ":$LITELLM_PORT" >/dev/null 2>&1; then
  warn "端口 $LITELLM_PORT 仍被占用，尝试释放..."
  lsof -ti ":$LITELLM_PORT" | xargs kill -9 2>/dev/null || true
  sleep 1
fi

ok "清理完成，环境已就绪"

# =============================================================================
# 阶段 3：安装与配置
# =============================================================================
section "阶段 3/4  安装与配置"

# ── 3a. 前置依赖检查 ──────────────────────────────────────────────────────────
info "检查前置依赖..."
_missing=()
for _cmd in python3 pip3 curl; do
  if command -v "$_cmd" >/dev/null 2>&1; then
    ok "$_cmd: $(command -v "$_cmd")"
  else
    err "缺少必要工具: $_cmd"
    _missing+=("$_cmd")
  fi
done
[[ ${#_missing[@]} -eq 0 ]] || die "请先安装缺失工具后重试: ${_missing[*]}"

# ── 3b. 安装 LiteLLM ──────────────────────────────────────────────────────────
info "安装 litellm[proxy] pyyaml requests..."
python3 -m pip install --upgrade --quiet pip
python3 -m pip install --upgrade --quiet "litellm[proxy]" pyyaml requests \
  && ok "LiteLLM 安装成功" \
  || die "LiteLLM 安装失败，请检查 pip 输出"

# 确认 litellm 命令可用
LITELLM_BIN=$(python3 -c "import shutil; print(shutil.which('litellm') or '')" 2>/dev/null)
if [[ -z "$LITELLM_BIN" ]]; then
  # 尝试从 pip 用户目录找
  LITELLM_BIN=$(python3 -m site --user-base 2>/dev/null)/bin/litellm
  [[ -x "$LITELLM_BIN" ]] || LITELLM_BIN=""
fi
[[ -n "$LITELLM_BIN" ]] && ok "litellm 命令: $LITELLM_BIN" \
  || die "litellm 命令未找到，请检查 PATH（pip install 可能写入了 ~/.local/bin）"

# ── 3c. 收集 API 密钥 ─────────────────────────────────────────────────────────
echo
echo -e "  ${BOLD}填写 API 密钥${RESET}（至少填写一个，留空跳过）"
echo -e "  ${YELLOW}密钥只保存在本机 .env 文件中，不会上传任何服务器${RESET}"
echo

_read_secret "阿里云百炼 Bailian API Key" DASHSCOPE_API_KEY
_read_secret "MiniMax API Key" MINIMAX_API_KEY
_read_secret "Gemini API Key" GEMINI_API_KEY

# 至少一个密钥非空
if [[ -z "$DASHSCOPE_API_KEY" && -z "$MINIMAX_API_KEY" && -z "$GEMINI_API_KEY" ]]; then
  die "至少需要填写一个 API 密钥"
fi

# ── 3d. 模型名称（可接受默认值）──────────────────────────────────────────────
echo
echo -e "  ${BOLD}模型名称配置${RESET}（直接回车使用默认值）"
echo

_read_default "DashScope 快速模型" "qwen3.5-plus"            DASHSCOPE_FAST_MODEL
_read_default "DashScope 均衡模型" "qwen3.5-plus"            DASHSCOPE_BALANCED_MODEL
_read_default "DashScope 编程模型" "qwen3-coder-plus"        DASHSCOPE_CODE_MODEL
_read_default "MiniMax 快速模型"   "MiniMax-M2.5"            MINIMAX_FAST_MODEL
_read_default "MiniMax 均衡模型"   "MiniMax-M2.5"            MINIMAX_BALANCED_MODEL
_read_default "Gemini 快速模型"    "gemini-3.1-flash-lite-preview" GEMINI_FAST_MODEL
_read_default "Gemini 深度模型"    "gemini-3.1-pro-preview"  GEMINI_DEEP_MODEL

# ── 3e. 创建目录结构 ──────────────────────────────────────────────────────────
mkdir -p "$LITELLM_DIR" "$LOG_DIR" "$BIN_DIR"
ok "目录结构已创建: $LITELLM_DIR"

# ── 3f. 写入 .env（chmod 600，密钥安全）──────────────────────────────────────
cat > "$ENV_FILE" <<EOF
# LiteLLM Router — macOS 宇宙配置
# 生成时间: $(date)
# ⚠  此文件含 API 密钥，请勿提交到 Git

# Provider API Keys
DASHSCOPE_API_KEY=${DASHSCOPE_API_KEY}
MINIMAX_API_KEY=${MINIMAX_API_KEY}
GEMINI_API_KEY=${GEMINI_API_KEY}

# Provider Endpoints
DASHSCOPE_API_BASE=https://coding.dashscope.aliyuncs.com/v1
MINIMAX_API_BASE=https://api.minimax.io/v1

# Model Names
DASHSCOPE_FAST_MODEL=${DASHSCOPE_FAST_MODEL}
DASHSCOPE_BALANCED_MODEL=${DASHSCOPE_BALANCED_MODEL}
DASHSCOPE_CODE_MODEL=${DASHSCOPE_CODE_MODEL}
MINIMAX_FAST_MODEL=${MINIMAX_FAST_MODEL}
MINIMAX_BALANCED_MODEL=${MINIMAX_BALANCED_MODEL}
GEMINI_FAST_MODEL=${GEMINI_FAST_MODEL}
GEMINI_DEEP_MODEL=${GEMINI_DEEP_MODEL}

# LiteLLM Proxy
LITELLM_MASTER_KEY=${LITELLM_MASTER_KEY}
LITELLM_PORT=${LITELLM_PORT}
LITELLM_HOST=${LITELLM_HOST}

# 生产模式：关闭 load_dotenv 自动加载（由 run.sh 显式 source）
LITELLM_MODE=PRODUCTION
# 只输出 ERROR 级别日志
LITELLM_LOG=ERROR
EOF
chmod 600 "$ENV_FILE"
ok ".env 已写入（权限 600）: $ENV_FILE"

# ── 3g. 写入 config.yaml ──────────────────────────────────────────────────────
# 使用 os.environ/ 引用，密钥不硬编码在 yaml 中
# 路由策略：simple-shuffle（官方生产推荐）
# 能力组：fast_chat / balanced_chat / coding_primary / coding_fast / summary_economy
# 国内优先顺序：DashScope(order:1) → MiniMax(order:2) → Gemini(order:3)
cat > "$CONFIG_FILE" <<'YAML_EOF'
# LiteLLM Router config — macOS 宇宙（国内网络优先）
# 能力组设计：agent 只认抽象组名，provider 绑定在此层
# 参考：https://docs.litellm.ai/docs/proxy/reliability

model_list:

  # ── fast_chat：低延迟、低成本，国内优先 ──────────────────────────────────
  - model_name: fast_chat
    litellm_params:
      model: openai/os.environ/DASHSCOPE_FAST_MODEL
      api_base: os.environ/DASHSCOPE_API_BASE
      api_key: os.environ/DASHSCOPE_API_KEY
      order: 1
      timeout: 25
      rpm: 300
    model_info:
      health_check_timeout: 8
      health_check_max_tokens: 1

  - model_name: fast_chat
    litellm_params:
      model: minimax/os.environ/MINIMAX_FAST_MODEL
      api_base: os.environ/MINIMAX_API_BASE
      api_key: os.environ/MINIMAX_API_KEY
      order: 2
      timeout: 30
      rpm: 200
    model_info:
      health_check_timeout: 8
      health_check_max_tokens: 1

  - model_name: fast_chat
    litellm_params:
      model: gemini/os.environ/GEMINI_FAST_MODEL
      api_key: os.environ/GEMINI_API_KEY
      order: 3
      timeout: 35
      rpm: 60
    model_info:
      health_check_timeout: 10
      health_check_max_tokens: 1

  # ── balanced_chat：通用对话，国内优先 ────────────────────────────────────
  - model_name: balanced_chat
    litellm_params:
      model: openai/os.environ/DASHSCOPE_BALANCED_MODEL
      api_base: os.environ/DASHSCOPE_API_BASE
      api_key: os.environ/DASHSCOPE_API_KEY
      order: 1
      timeout: 45
      rpm: 180
    model_info:
      health_check_timeout: 10
      health_check_max_tokens: 2

  - model_name: balanced_chat
    litellm_params:
      model: minimax/os.environ/MINIMAX_BALANCED_MODEL
      api_base: os.environ/MINIMAX_API_BASE
      api_key: os.environ/MINIMAX_API_KEY
      order: 2
      timeout: 45
      rpm: 150
    model_info:
      health_check_timeout: 10
      health_check_max_tokens: 2

  - model_name: balanced_chat
    litellm_params:
      model: gemini/os.environ/GEMINI_DEEP_MODEL
      api_key: os.environ/GEMINI_API_KEY
      order: 3
      timeout: 60
      rpm: 30
    model_info:
      health_check_timeout: 12
      health_check_max_tokens: 2

  # ── coding_primary：最强编程路径 ─────────────────────────────────────────
  - model_name: coding_primary
    litellm_params:
      model: openai/os.environ/DASHSCOPE_CODE_MODEL
      api_base: os.environ/DASHSCOPE_API_BASE
      api_key: os.environ/DASHSCOPE_API_KEY
      order: 1
      timeout: 90
      rpm: 120
    model_info:
      health_check_timeout: 12
      health_check_max_tokens: 2

  - model_name: coding_primary
    litellm_params:
      model: minimax/os.environ/MINIMAX_BALANCED_MODEL
      api_base: os.environ/MINIMAX_API_BASE
      api_key: os.environ/MINIMAX_API_KEY
      order: 2
      timeout: 90
      rpm: 100
    model_info:
      health_check_timeout: 12
      health_check_max_tokens: 2

  - model_name: coding_primary
    litellm_params:
      model: gemini/os.environ/GEMINI_DEEP_MODEL
      api_key: os.environ/GEMINI_API_KEY
      order: 3
      timeout: 90
      rpm: 20
    model_info:
      health_check_timeout: 15
      health_check_max_tokens: 2

  # ── coding_fast：快速代码补全 ─────────────────────────────────────────────
  - model_name: coding_fast
    litellm_params:
      model: openai/os.environ/DASHSCOPE_FAST_MODEL
      api_base: os.environ/DASHSCOPE_API_BASE
      api_key: os.environ/DASHSCOPE_API_KEY
      order: 1
      timeout: 45
      rpm: 300
    model_info:
      health_check_timeout: 8
      health_check_max_tokens: 1

  - model_name: coding_fast
    litellm_params:
      model: minimax/os.environ/MINIMAX_FAST_MODEL
      api_base: os.environ/MINIMAX_API_BASE
      api_key: os.environ/MINIMAX_API_KEY
      order: 2
      timeout: 45
      rpm: 200
    model_info:
      health_check_timeout: 8
      health_check_max_tokens: 1

  # ── summary_economy：低成本摘要/分类 ─────────────────────────────────────
  - model_name: summary_economy
    litellm_params:
      model: openai/os.environ/DASHSCOPE_FAST_MODEL
      api_base: os.environ/DASHSCOPE_API_BASE
      api_key: os.environ/DASHSCOPE_API_KEY
      order: 1
      timeout: 20
      rpm: 300
    model_info:
      health_check_timeout: 6
      health_check_max_tokens: 1

  - model_name: summary_economy
    litellm_params:
      model: gemini/os.environ/GEMINI_FAST_MODEL
      api_key: os.environ/GEMINI_API_KEY
      order: 2
      timeout: 25
      rpm: 60
    model_info:
      health_check_timeout: 8
      health_check_max_tokens: 1

router_settings:
  # simple-shuffle：官方生产推荐，性能最优
  routing_strategy: simple-shuffle
  # 调用前检查 context window，防止超限
  enable_pre_call_checks: true
  num_retries: 2
  # 失败 fallback 链（按能力组降级）
  fallbacks:
    - {"coding_primary": ["coding_fast", "balanced_chat"]}
    - {"coding_fast":    ["coding_primary", "balanced_chat"]}
    - {"balanced_chat":  ["fast_chat"]}
    - {"summary_economy": ["fast_chat"]}
  # 默认兜底：任何组失败都降到 fast_chat
  default_fallbacks: ["fast_chat"]
  # 模型冷却：60s 内失败超过 3 次则冷却 30s
  allowed_fails: 3
  cooldown_time: 30

litellm_settings:
  # 生产模式：关闭 debug 日志
  set_verbose: false
  json_logs: true
  # 全局请求超时（秒）
  request_timeout: 120

general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
  # 不暴露 endpoint URL 等内部细节
  health_check_details: false
  # 后台定期健康检查（每 5 分钟），避免每次 /health 都实际调用模型
  background_health_checks: true
  health_check_interval: 300
YAML_EOF
ok "config.yaml 已写入: $CONFIG_FILE"

# ── 3h. 写入 run.sh ───────────────────────────────────────────────────────────
cat > "$BIN_DIR/run.sh" <<'SH_EOF'
#!/usr/bin/env bash
# LiteLLM 启动脚本 — 由 LaunchAgent 或手动调用
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 显式 source .env，不依赖 LITELLM_MODE=PRODUCTION 的 load_dotenv
set -a
# shellcheck source=/dev/null
source "$BASE_DIR/.env"
set +a

mkdir -p "$BASE_DIR/logs"

# 找到 litellm 可执行文件（兼容 pip --user 安装路径）
_find_litellm() {
  local candidates=(
    "$(command -v litellm 2>/dev/null || true)"
    "$HOME/.local/bin/litellm"
    "$(python3 -m site --user-base 2>/dev/null)/bin/litellm"
    "/usr/local/bin/litellm"
  )
  for c in "${candidates[@]}"; do
    [[ -x "$c" ]] && echo "$c" && return
  done
  echo ""
}
LITELLM_CMD="$(_find_litellm)"
[[ -n "$LITELLM_CMD" ]] || { echo "ERROR: litellm 命令未找到" >&2; exit 1; }

exec "$LITELLM_CMD" \
  --config "$BASE_DIR/config.yaml" \
  --host "${LITELLM_HOST:-127.0.0.1}" \
  --port "${LITELLM_PORT:-4000}" \
  >> "$BASE_DIR/logs/litellm.stdout.log" \
  2>> "$BASE_DIR/logs/litellm.stderr.log"
SH_EOF
chmod 755 "$BIN_DIR/run.sh"
ok "run.sh 已写入: $BIN_DIR/run.sh"

# ── 3i. 写入 stop.sh ──────────────────────────────────────────────────────────
cat > "$BIN_DIR/stop.sh" <<'SH_EOF'
#!/usr/bin/env bash
# 停止 LiteLLM（兼容 LaunchAgent 和手动启动两种方式）
PLIST_LABEL="ai.openclaw.litellm"
if launchctl list "$PLIST_LABEL" >/dev/null 2>&1; then
  launchctl bootout "gui/$(id -u)/$PLIST_LABEL" 2>/dev/null || true
fi
pkill -f "litellm.*--config" 2>/dev/null || true
echo "LiteLLM 已停止"
SH_EOF
chmod 755 "$BIN_DIR/stop.sh"
ok "stop.sh 已写入: $BIN_DIR/stop.sh"

# ── 3j. 写入 LaunchAgent plist ────────────────────────────────────────────────
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST_PATH" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${PLIST_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${BIN_DIR}/run.sh</string>
  </array>
  <key>RunAtLoad</key>
  <false/>
  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key>
    <false/>
  </dict>
  <key>WorkingDirectory</key>
  <string>${LITELLM_DIR}</string>
  <key>StandardOutPath</key>
  <string>${LOG_DIR}/launchd.stdout.log</string>
  <key>StandardErrorPath</key>
  <string>${LOG_DIR}/launchd.stderr.log</string>
  <key>ThrottleInterval</key>
  <integer>10</integer>
</dict>
</plist>
PLIST_EOF
chmod 644 "$PLIST_PATH"
ok "LaunchAgent plist 已写入: $PLIST_PATH"

# ── 3k. 注册 LaunchAgent（bootstrap，不自动启动）─────────────────────────────
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null \
  && ok "LaunchAgent 已注册（未启动）" \
  || warn "LaunchAgent 注册失败（可能已注册，继续）"

# =============================================================================
# 阶段 4：验证
# =============================================================================
section "阶段 4/4  验证"

PASS=0; FAIL=0
_check() {
  if [[ "$2" == "ok" ]]; then
    ok "✓ $1${3:+  ($3)}"; PASS=$((PASS+1))
  else
    err "✗ $1${3:+  ($3)}"; FAIL=$((FAIL+1))
  fi
}

# ── 4a. 文件完整性检查 ────────────────────────────────────────────────────────
info "检查配置文件..."
[[ -f "$CONFIG_FILE" ]] && _check "config.yaml 存在" "ok" || _check "config.yaml 存在" "fail"
[[ -f "$ENV_FILE" ]]    && _check ".env 存在" "ok"        || _check ".env 存在" "fail"
[[ -f "$BIN_DIR/run.sh" ]]  && _check "run.sh 存在" "ok"  || _check "run.sh 存在" "fail"
[[ -f "$BIN_DIR/stop.sh" ]] && _check "stop.sh 存在" "ok" || _check "stop.sh 存在" "fail"
[[ -f "$PLIST_PATH" ]]  && _check "plist 存在" "ok"       || _check "plist 存在" "fail"

# .env 权限必须是 600
_env_perm=$(stat -f "%OLp" "$ENV_FILE" 2>/dev/null || echo "000")
[[ "$_env_perm" == "600" ]] \
  && _check ".env 权限 600" "ok" \
  || _check ".env 权限 600" "fail" "当前: $_env_perm"

# ── 4b. Provider 直连测试（原始 API，不经过 LiteLLM）────────────────────────
info "测试 Provider 直连..."
# source .env 获取密钥
set -a; source "$ENV_FILE"; set +a

_test_provider() {
  local name="$1" url="$2" key="$3"
  [[ -z "$key" ]] && { info "跳过 $name（未配置密钥）"; return; }
  local http_code="000"
  http_code=$(curl -sS -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $key" \
    --max-time 15 "$url" 2>/dev/null) || http_code="000"
  if [[ "$http_code" == "200" ]]; then
    _check "$name 直连" "ok" "HTTP $http_code"
  else
    warn "$name 直连返回 HTTP $http_code（可能是网络问题，不阻断安装）"
  fi
}

_test_provider "DashScope" \
  "https://coding.dashscope.aliyuncs.com/v1/models" \
  "${DASHSCOPE_API_KEY:-}"

_test_provider "MiniMax" \
  "https://api.minimax.io/v1/models" \
  "${MINIMAX_API_KEY:-}"

# Gemini 用不同的 endpoint 格式
if [[ -n "${GEMINI_API_KEY:-}" ]]; then
  _gemini_code="000"
  _gemini_code=$(curl -sS -o /dev/null -w "%{http_code}" \
    "https://generativelanguage.googleapis.com/v1beta/models?key=${GEMINI_API_KEY}" \
    --max-time 15 2>/dev/null) || _gemini_code="000"
  if [[ "$_gemini_code" == "200" ]]; then
    _check "Gemini 直连" "ok" "HTTP $_gemini_code"
  else
    warn "Gemini 直连返回 HTTP $_gemini_code（可能是网络问题，不阻断安装）"
  fi
else
  info "跳过 Gemini（未配置密钥）"
fi

# ── 4c. 启动 LiteLLM 服务 ─────────────────────────────────────────────────────
info "启动 LiteLLM 服务..."
launchctl kickstart "gui/$(id -u)/$PLIST_LABEL" 2>/dev/null \
  || { nohup "$BIN_DIR/run.sh" >/dev/null 2>&1 & }

# 轮询 /health/readiness，最多等 30 秒
info "等待 LiteLLM 就绪（最多 30 秒）..."
_ready=false
for _i in $(seq 1 30); do
  _code=$(curl -sS -o /dev/null -w "%{http_code}" \
    "http://${LITELLM_HOST}:${LITELLM_PORT}/health/readiness" \
    --max-time 2 2>/dev/null || echo "000")
  if [[ "$_code" == "200" ]]; then
    _ready=true; break
  fi
  sleep 1
done

if [[ "$_ready" == "true" ]]; then
  _check "LiteLLM 服务就绪 (/health/readiness)" "ok"
else
  _check "LiteLLM 服务就绪 (/health/readiness)" "fail" "30s 内未响应，查看日志: $LOG_DIR"
fi

# ── 4d. 模型端点测试（通过 LiteLLM proxy 发送真实请求）──────────────────────
if [[ "$_ready" == "true" ]]; then
  info "测试模型端点（通过 LiteLLM proxy）..."

  _test_model() {
    local group="$1" prompt="$2"
    local resp="000" http_code="000"
    resp=$(curl -sS -w "\n%{http_code}" \
      -X POST "http://${LITELLM_HOST}:${LITELLM_PORT}/v1/chat/completions" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
      --max-time 30 \
      -d "{\"model\":\"${group}\",\"messages\":[{\"role\":\"user\",\"content\":\"${prompt}\"}],\"max_tokens\":10,\"temperature\":0}" \
      2>/dev/null) || resp=$'\n000'
    http_code=$(echo "$resp" | tail -1)
    if [[ "$http_code" == "200" ]]; then
      _check "模型组 ${group}" "ok"
    else
      local body; body=$(echo "$resp" | head -1)
      warn "模型组 ${group} 返回 HTTP ${http_code}: ${body:0:120}"
      FAIL=$((FAIL+1))
    fi
  }

  # 只测试有密钥的 provider 对应的组
  [[ -n "${DASHSCOPE_API_KEY:-}" || -n "${MINIMAX_API_KEY:-}" || -n "${GEMINI_API_KEY:-}" ]] && \
    _test_model "fast_chat"       "hi"
  [[ -n "${DASHSCOPE_API_KEY:-}" || -n "${MINIMAX_API_KEY:-}" || -n "${GEMINI_API_KEY:-}" ]] && \
    _test_model "balanced_chat"   "hi"
  [[ -n "${DASHSCOPE_API_KEY:-}" || -n "${MINIMAX_API_KEY:-}" || -n "${GEMINI_API_KEY:-}" ]] && \
    _test_model "coding_primary"  "hi"
fi

# ── 4e. 服务停止验证 ──────────────────────────────────────────────────────────
info "验证服务停止能力..."
"$BIN_DIR/stop.sh" >/dev/null 2>&1
sleep 2

# 确认端口已释放
if lsof -ti ":$LITELLM_PORT" >/dev/null 2>&1; then
  _check "服务停止后端口释放" "fail" "端口 $LITELLM_PORT 仍被占用"
else
  _check "服务停止后端口释放" "ok"
fi

# ── 4f. 重新启动验证 ──────────────────────────────────────────────────────────
info "验证服务重新启动能力..."
launchctl kickstart "gui/$(id -u)/$PLIST_LABEL" 2>/dev/null \
  || { nohup "$BIN_DIR/run.sh" >/dev/null 2>&1 & }

_ready2=false
for _i in $(seq 1 20); do
  _code=$(curl -sS -o /dev/null -w "%{http_code}" \
    "http://${LITELLM_HOST}:${LITELLM_PORT}/health/readiness" \
    --max-time 2 2>/dev/null || echo "000")
  if [[ "$_code" == "200" ]]; then _ready2=true; break; fi
  sleep 1
done

[[ "$_ready2" == "true" ]] \
  && _check "服务重启后就绪" "ok" \
  || _check "服务重启后就绪" "fail" "查看日志: $LOG_DIR"

# ── 4g. LaunchAgent 注册状态 ──────────────────────────────────────────────────
if launchctl list "$PLIST_LABEL" >/dev/null 2>&1; then
  _check "LaunchAgent 已注册" "ok"
else
  _check "LaunchAgent 已注册" "fail"
fi

# =============================================================================
# 最终结果
# =============================================================================
echo
if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${GREEN}${BOLD}║  ✓ LiteLLM 安装成功！($PASS/$((PASS+FAIL)) 项通过)                    ║${RESET}"
  echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
else
  echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${YELLOW}${BOLD}║  ⚠  $FAIL 项未通过（$PASS/$((PASS+FAIL)) 通过）                           ║${RESET}"
  echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
fi
echo
echo "  配置目录:  $LITELLM_DIR"
echo "  日志目录:  $LOG_DIR"
echo "  .env 文件: $ENV_FILE"
echo
echo "  OpenClaw 接入参数："
echo -e "    base_url = ${CYAN}http://${LITELLM_HOST}:${LITELLM_PORT}/v1${RESET}"
echo -e "    api_key  = ${CYAN}${LITELLM_MASTER_KEY}${RESET}"
echo
echo "  常用命令："
echo "    启动服务:  launchctl kickstart gui/\$(id -u)/$PLIST_LABEL"
echo "    停止服务:  $BIN_DIR/stop.sh"
echo "    查看日志:  tail -f $LOG_DIR/litellm.stdout.log"
echo "    健康检查:  curl http://${LITELLM_HOST}:${LITELLM_PORT}/health/readiness"
echo "    模型列表:  curl -H 'Authorization: Bearer ${LITELLM_MASTER_KEY}' http://${LITELLM_HOST}:${LITELLM_PORT}/v1/models"
echo
[[ $FAIL -gt 0 ]] && echo "  查看日志排查问题: tail -n 100 $LOG_DIR/litellm.stderr.log"
echo
