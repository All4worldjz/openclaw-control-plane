#!/usr/bin/env bash
#
# 测试卸载脚本的覆盖范围
# 用途：验证所有 OpenClaw 可能使用的目录都被包含在清理列表中
#

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==> 测试卸载脚本覆盖范围${NC}"
echo

# OpenClaw 可能使用的所有目录
EXPECTED_DIRS=(
    "$HOME/.openclaw"
    "$HOME/.config/openclaw"
    "$HOME/.config/OpenClaw"
    "$HOME/.cache/openclaw"
    "$HOME/.local/share/openclaw"
    "$HOME/.local/share/OpenClaw"
    "$HOME/Library/Application Support/OpenClaw"
    "$HOME/Library/Application Support/openclaw"
    "$HOME/Library/Caches/openclaw"
    "$HOME/Library/Caches/OpenClaw"
    "$HOME/Library/Logs/openclaw"
    "$HOME/Library/Logs/OpenClaw"
)

echo "检查卸载脚本是否包含所有预期目录..."
echo

echo "检查卸载脚本是否包含所有预期目录..."
echo

missing=0
for dir in "${EXPECTED_DIRS[@]}"; do
    # 将 $HOME 替换为实际路径用于显示，但搜索时使用模式
    display_dir="$dir"
    search_pattern=$(echo "$dir" | sed "s|$HOME|\\\$HOME|g" | sed 's/[\/&]/\\&/g')
    
    if grep -q "$search_pattern" uninstall-openclaw.sh; then
        echo -e "${GREEN}✓${NC} $display_dir"
    else
        echo -e "${YELLOW}✗${NC} $display_dir (未在卸载脚本中)"
        missing=$((missing + 1))
    fi
done

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $missing -eq 0 ]]; then
    echo -e "${GREEN}✓ 所有预期目录都已覆盖${NC}"
    echo
    echo "注意：卸载脚本已包含自动验证功能，无需单独的验证脚本。"
    exit 0
else
    echo -e "${YELLOW}发现 $missing 个目录未在卸载脚本中${NC}"
    echo
    echo "建议更新脚本以包含这些目录"
    exit 1
fi
