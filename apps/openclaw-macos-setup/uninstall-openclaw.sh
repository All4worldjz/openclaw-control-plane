#!/usr/bin/env bash
# =============================================================================
# OpenClaw macOS 完整卸载脚本
# 四阶段：备份 → 停止服务 → 删除 → 验证
# 支持：env var 覆盖、多 profile、自定义 workspace 路径
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

# ── 安全检查 ──────────────────────────────────────────────────────────────────
if [[ "$(uname -s)" != "Darwin" ]]; then
  err "此脚本仅适用于 macOS"; exit 1
fi
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  err "请勿使用 sudo 运行此脚本"; exit 1
fi

# ── 路径解析（尊重 env var 覆盖）─────────────────────────────────────────────
OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"
OPENCLAW_CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-$OPENCLAW_STATE_DIR/openclaw.json}"

# 从 LaunchAgent plist 推断安装器 install_root
INSTALLER_INSTALL_ROOT=""
_detect_install_root() {
  local plist
  for plist in "$HOME/Library/LaunchAgents"/ai.openclaw.*.plist; do
    [[ -f "$plist" ]] || continue
    local wd
    wd=$(plutil -extract WorkingDirectory raw "$plist" 2>/dev/null || true)
    if [[ -n "$wd" && -d "$wd" ]]; then
      INSTALLER_INSTALL_ROOT="$wd"
      return
    fi
  done
}
_detect_install_root

# 从 openclaw.jsonc 读取自定义 workspace 路径
CUSTOM_WORKSPACE=""
_detect_custom_workspace() {
  local cfg
  for cfg in \
    "$OPENCLAW_CONFIG_PATH" \
    "$OPENCLAW_STATE_DIR/openclaw.json" \
    "$OPENCLAW_STATE_DIR/openclaw.jsonc" \
    "${INSTALLER_INSTALL_ROOT:+$INSTALLER_INSTALL_ROOT/config/prod-mac/openclaw.jsonc}"; do
    [[ -f "$cfg" ]] || continue
    local ws
    ws=$(grep -o '"workspace"[[:space:]]*:[[:space:]]*"[^"]*"' "$cfg" 2>/dev/null \
         | head -1 | sed 's/.*"workspace"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    if [[ -n "$ws" && "$ws" != "$OPENCLAW_STATE_DIR"* ]]; then
      CUSTOM_WORKSPACE="$ws"
    fi
    break
  done
}
_detect_custom_workspace

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_ROOT="$HOME/openclaw_backup_$TIMESTAMP"

# ── 预览 ──────────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║         OpenClaw macOS 完整卸载脚本                         ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo
echo -e "  状态目录:    ${CYAN}$OPENCLAW_STATE_DIR${RESET}"
[[ -n "$INSTALLER_INSTALL_ROOT" ]] && \
echo -e "  安装根目录:  ${CYAN}$INSTALLER_INSTALL_ROOT${RESET}"
[[ -n "$CUSTOM_WORKSPACE" ]] && \
echo -e "  自定义工作区: ${CYAN}$CUSTOM_WORKSPACE${RESET}"
echo -e "  备份目录:    ${CYAN}$BACKUP_ROOT${RESET}"
echo
echo -e "  ${YELLOW}⚠  备份文件可能包含 API 密钥等敏感信息，请妥善保管${RESET}"
echo
read -r -p "  确认执行完整卸载？[y/N]: " _ans
case "$_ans" in [yY][eE][sS]|[yY]) ;; *) echo "已取消。"; exit 0 ;; esac

# =============================================================================
# 阶段 1：备份
# =============================================================================
section "阶段 1/4  备份重要数据"

mkdir -p "$BACKUP_ROOT"

_backup_dir() {
  local src="$1" dest="$2"
  [[ -d "$src" ]] || return 0
  mkdir -p "$(dirname "$dest")"
  cp -R "$src" "$dest" 2>/dev/null && ok "已备份目录: $src → $dest" || warn "备份失败: $src"
}

_backup_file() {
  local src="$1" dest="$2"
  [[ -f "$src" ]] || return 0
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest" 2>/dev/null && ok "已备份文件: $src" || warn "备份失败: $src"
}

# 完整 state 目录
if [[ -d "$OPENCLAW_STATE_DIR" ]]; then
  _backup_dir "$OPENCLAW_STATE_DIR" "$BACKUP_ROOT/state/openclaw"
  info "⚠  state 备份含 credentials/ 目录（OAuth token、API key），请保密"
fi

# 安装器 install_root
if [[ -n "$INSTALLER_INSTALL_ROOT" && -d "$INSTALLER_INSTALL_ROOT" ]]; then
  _backup_dir "$INSTALLER_INSTALL_ROOT" "$BACKUP_ROOT/install_root"
fi

# 多 profile 目录 ~/.openclaw-*
for _pdir in "$HOME"/.openclaw-*; do
  [[ -d "$_pdir" ]] || continue
  _pname=$(basename "$_pdir")
  _backup_dir "$_pdir" "$BACKUP_ROOT/profiles/$_pname"
done

# 自定义 workspace（如果在 state dir 之外）
if [[ -n "$CUSTOM_WORKSPACE" && -d "$CUSTOM_WORKSPACE" ]]; then
  _backup_dir "$CUSTOM_WORKSPACE" "$BACKUP_ROOT/workspace"
fi

# 重要配置文件单独备份
_backup_file "$OPENCLAW_CONFIG_PATH"                                    "$BACKUP_ROOT/configs/openclaw.json"
_backup_file "$OPENCLAW_STATE_DIR/openclaw.jsonc"                       "$BACKUP_ROOT/configs/openclaw.jsonc"
_backup_file "$OPENCLAW_STATE_DIR/.env"                                 "$BACKUP_ROOT/configs/.env"
[[ -n "$INSTALLER_INSTALL_ROOT" ]] && {
  _backup_file "$INSTALLER_INSTALL_ROOT/config/prod-mac/openclaw.jsonc" "$BACKUP_ROOT/configs/prod-mac/openclaw.jsonc"
  _backup_file "$INSTALLER_INSTALL_ROOT/config/prod-mac/.env"           "$BACKUP_ROOT/configs/prod-mac/.env"
  _backup_file "$INSTALLER_INSTALL_ROOT/config/prod-mac/litellm.yaml"   "$BACKUP_ROOT/configs/prod-mac/litellm.yaml"
}

# Shell 配置文件备份 + 提取 openclaw 相关行
mkdir -p "$BACKUP_ROOT/shell_configs"
for _rc in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.bashrc" "$HOME/.bash_profile"; do
  [[ -f "$_rc" ]] || continue
  cp "$_rc" "$BACKUP_ROOT/shell_configs/$(basename "$_rc").bak"
  if grep -qi 'openclaw\|open-claw' "$_rc" 2>/dev/null; then
    grep -ni 'openclaw\|open-claw' "$_rc" > "$BACKUP_ROOT/shell_configs/$(basename "$_rc").openclaw_lines" 2>/dev/null || true
    ok "已备份 shell 配置: $_rc"
  fi
done

# 生成备份清单
{
  echo "OpenClaw 卸载备份清单"
  echo "时间: $(date)"
  echo "主机: $(hostname)"
  echo "用户: $USER"
  echo ""
  echo "⚠  此备份可能包含 API 密钥、OAuth token 等敏感信息，请妥善保管"
  echo ""
  find "$BACKUP_ROOT" -not -name "BACKUP_MANIFEST.txt" 2>/dev/null | sort | \
    while read -r f; do
      [[ -f "$f" ]] && printf "  %-60s %s\n" "${f#$BACKUP_ROOT/}" "$(du -sh "$f" 2>/dev/null | cut -f1)"
    done
} > "$BACKUP_ROOT/BACKUP_MANIFEST.txt"

ok "备份完成 → $BACKUP_ROOT"

# =============================================================================
# 阶段 2：停止服务 & 删除
# =============================================================================
section "阶段 2/4  停止服务并删除文件"

# 通过 openclaw CLI 优雅停止（官方推荐顺序）
if command -v openclaw >/dev/null 2>&1; then
  info "尝试 openclaw gateway stop..."
  openclaw gateway stop 2>/dev/null && ok "openclaw gateway stop 成功" || warn "openclaw gateway stop 失败（继续）"
  info "尝试 openclaw gateway uninstall..."
  openclaw gateway uninstall 2>/dev/null && ok "openclaw gateway uninstall 成功" || warn "openclaw gateway uninstall 失败（继续）"
fi

# 手动卸载 LaunchAgent
_unload_label() {
  local label="$1"
  if launchctl list "$label" >/dev/null 2>&1; then
    launchctl bootout "gui/$(id -u)/$label" 2>/dev/null \
      || launchctl unload -w "$HOME/Library/LaunchAgents/${label}.plist" 2>/dev/null \
      || true
    ok "已卸载 LaunchAgent: $label"
  fi
}

_unload_label "ai.openclaw.litellm"
_unload_label "ai.openclaw.runtime"
_unload_label "ai.openclaw.gateway"

# 多 profile labels
for _plist in "$HOME/Library/LaunchAgents"/ai.openclaw.*.plist; do
  [[ -f "$_plist" ]] || continue
  _unload_label "$(basename "$_plist" .plist)"
done

# 遗留 labels: com.openclaw.*
for _plist in "$HOME/Library/LaunchAgents"/com.openclaw.*.plist; do
  [[ -f "$_plist" ]] || continue
  _unload_label "$(basename "$_plist" .plist)"
done

# 删除 plist 文件
for _plist in \
  "$HOME/Library/LaunchAgents"/ai.openclaw.*.plist \
  "$HOME/Library/LaunchAgents"/com.openclaw.*.plist; do
  [[ -f "$_plist" ]] || continue
  rm -f "$_plist" && ok "已删除 plist: $_plist"
done

if [[ -n "$INSTALLER_INSTALL_ROOT" ]]; then
  for _plist in "$INSTALLER_INSTALL_ROOT/launch-agents"/*.plist; do
    [[ -f "$_plist" ]] || continue
    rm -f "$_plist" && ok "已删除 plist: $_plist"
  done
fi

# 终止残留进程（排除 IDE）
info "终止 openclaw/litellm 进程..."
pkill -f 'openclaw' 2>/dev/null | grep -v -i 'cursor\|code\|extension-host' || true
pkill -f 'litellm' 2>/dev/null || true
sleep 1

# 删除目录和文件
_rm() {
  local p="$1"
  if [[ -e "$p" || -L "$p" ]]; then
    rm -rf "$p" && ok "已删除: $p" || warn "删除失败: $p"
  fi
}

_rm "$OPENCLAW_STATE_DIR"

for _pdir in "$HOME"/.openclaw-*; do
  [[ -d "$_pdir" ]] || continue
  _rm "$_pdir"
done

[[ -n "$INSTALLER_INSTALL_ROOT" ]] && _rm "$INSTALLER_INSTALL_ROOT"
[[ -n "$CUSTOM_WORKSPACE" ]] && _rm "$CUSTOM_WORKSPACE"

_rm "$HOME/Library/Application Support/OpenClaw"
_rm "$HOME/Library/Application Support/openclaw"
_rm "$HOME/Library/Caches/OpenClaw"
_rm "$HOME/Library/Caches/openclaw"
_rm "$HOME/Library/Logs/openclaw"
_rm "$HOME/Library/Preferences/com.openclaw.plist"
_rm "$HOME/.config/openclaw"
_rm "$HOME/.cache/openclaw"
_rm "$HOME/.local/share/openclaw"

if [[ -d "/Applications/OpenClaw.app" ]]; then
  warn "发现 /Applications/OpenClaw.app"
  read -r -p "  是否删除 /Applications/OpenClaw.app？[y/N]: " _ans
  case "$_ans" in [yY][eE][sS]|[yY]) _rm "/Applications/OpenClaw.app" ;; *) info "跳过 App 删除" ;; esac
fi

# =============================================================================
# 阶段 3：清理包和 Shell 配置
# =============================================================================
section "阶段 3/4  清理包和 Shell 配置"

info "卸载 npm 全局包 openclaw..."
if npm list -g openclaw >/dev/null 2>&1; then
  npm rm -g openclaw 2>&1 | tail -5 && ok "npm: openclaw 已卸载" || warn "npm 卸载失败"
else
  info "npm: openclaw 未安装，跳过"
fi

command -v pnpm >/dev/null 2>&1 && { pnpm remove -g openclaw 2>/dev/null && ok "pnpm: openclaw 已卸载" || true; }
command -v bun  >/dev/null 2>&1 && { bun remove -g openclaw 2>/dev/null && ok "bun: openclaw 已卸载" || true; }

if pip3 show litellm >/dev/null 2>&1; then
  read -r -p "  是否卸载 LiteLLM（pip3 uninstall litellm）？[y/N]: " _ans
  case "$_ans" in
    [yY][eE][sS]|[yY]) pip3 uninstall -y litellm 2>&1 | tail -3 && ok "LiteLLM 已卸载" || warn "LiteLLM 卸载失败" ;;
    *) info "跳过 LiteLLM 卸载" ;;
  esac
fi

info "清理 Shell 配置文件中的 openclaw 相关行..."
for _rc in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.bashrc" "$HOME/.bash_profile"; do
  [[ -f "$_rc" ]] || continue
  if grep -qi 'openclaw\|open-claw\|OPENCLAW' "$_rc" 2>/dev/null; then
    perl -ni -e 'print unless /openclaw|open-claw|OPENCLAW/i' "$_rc"
    ok "已清理 shell 配置: $_rc"
  fi
done

# =============================================================================
# 阶段 4：验证
# =============================================================================
section "阶段 4/4  验证清理结果"

PASS=0; FAIL=0

_check() {
  local name="$1" result="$2" detail="${3:-}"
  if [[ "$result" == "ok" ]]; then
    ok "✓ $name${detail:+  ($detail)}"
    ((PASS++))
  else
    err "✗ $name${detail:+  ($detail)}"
    ((FAIL++))
  fi
}

command -v openclaw >/dev/null 2>&1 \
  && _check "openclaw 命令已移除" "fail" "仍在: $(command -v openclaw)" \
  || _check "openclaw 命令已移除" "ok"

[[ -d "$OPENCLAW_STATE_DIR" ]] \
  && _check "状态目录已删除 ($OPENCLAW_STATE_DIR)" "fail" \
  || _check "状态目录已删除 ($OPENCLAW_STATE_DIR)" "ok"

_profile_remain=()
for _pdir in "$HOME"/.openclaw-*; do [[ -d "$_pdir" ]] && _profile_remain+=("$_pdir"); done
[[ ${#_profile_remain[@]} -gt 0 ]] \
  && _check "Profile 目录已删除" "fail" "${_profile_remain[*]}" \
  || _check "Profile 目录已删除" "ok"

[[ -n "$INSTALLER_INSTALL_ROOT" && -d "$INSTALLER_INSTALL_ROOT" ]] \
  && _check "安装根目录已删除 ($INSTALLER_INSTALL_ROOT)" "fail" \
  || _check "安装根目录已删除" "ok"

_la_running=$(launchctl list 2>/dev/null | grep -i 'openclaw' || true)
[[ -n "$_la_running" ]] \
  && _check "LaunchAgent 已卸载" "fail" "$_la_running" \
  || _check "LaunchAgent 已卸载" "ok"

_plist_remain=$(ls "$HOME/Library/LaunchAgents"/ai.openclaw.*.plist "$HOME/Library/LaunchAgents"/com.openclaw.*.plist 2>/dev/null || true)
[[ -n "$_plist_remain" ]] \
  && _check "LaunchAgent plist 已删除" "fail" "$_plist_remain" \
  || _check "LaunchAgent plist 已删除" "ok"

_procs=$(pgrep -fl 'openclaw' 2>/dev/null | grep -v -i 'cursor\|code\|extension-host\|kiro' || true)
[[ -n "$_procs" ]] \
  && _check "无残留进程" "fail" "$_procs" \
  || _check "无残留进程" "ok"

npm list -g openclaw >/dev/null 2>&1 \
  && _check "npm 包已卸载" "fail" \
  || _check "npm 包已卸载" "ok"

_shell_dirty=()
for _rc in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.bashrc" "$HOME/.bash_profile"; do
  [[ -f "$_rc" ]] || continue
  grep -qi 'openclaw\|OPENCLAW' "$_rc" 2>/dev/null && _shell_dirty+=("$_rc")
done
[[ ${#_shell_dirty[@]} -gt 0 ]] \
  && _check "Shell 配置已清理" "fail" "${_shell_dirty[*]}" \
  || _check "Shell 配置已清理" "ok"

# ── 最终结果 ──────────────────────────────────────────────────────────────────
echo
if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${GREEN}${BOLD}║  ✓ 卸载成功！系统已完全清理 OpenClaw  ($PASS/$((PASS+FAIL)) 项通过)  ║${RESET}"
  echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
  echo
  echo -e "  备份位置: ${CYAN}$BACKUP_ROOT${RESET}"
  echo -e "  ${YELLOW}⚠  备份含敏感信息，请妥善保管或安全删除${RESET}"
  echo
  echo "  后续步骤："
  echo "    1. 重启终端以清除环境变量:  exec \$SHELL -l"
  echo "    2. 现在可以重新安装 OpenClaw 进行调试了"
else
  echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${YELLOW}${BOLD}║  ⚠  发现 $FAIL 个残留项（$PASS/$((PASS+FAIL)) 项通过）                        ║${RESET}"
  echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
  echo
  echo "  建议："
  echo "    1. 查看上方 [ERR] 行了解具体残留项"
  echo "    2. 重新运行此脚本: ./uninstall-openclaw.sh"
  echo "    3. 或手动清理上述残留项后重启终端"
fi
echo
