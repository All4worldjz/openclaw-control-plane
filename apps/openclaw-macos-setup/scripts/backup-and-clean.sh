#!/usr/bin/env bash
#
# OpenClaw 配置备份与清理脚本
# 用途：备份重要配置文件后清理 ~/.openclaw 目录
#

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        OpenClaw 配置备份与清理脚本                        ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo

# 生成时间戳
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/openclaw_backup_${TIMESTAMP}"
OPENCLAW_DIR="$HOME/.openclaw"

# 检查 ~/.openclaw 是否存在
if [[ ! -d "$OPENCLAW_DIR" ]]; then
    echo -e "${YELLOW}~/.openclaw 目录不存在，无需清理${NC}"
    exit 0
fi

echo -e "${BLUE}==> 发现 ~/.openclaw 目录${NC}"
echo "    路径: $OPENCLAW_DIR"
echo

# 显示目录大小
DIR_SIZE=$(du -sh "$OPENCLAW_DIR" 2>/dev/null | cut -f1)
echo "    大小: $DIR_SIZE"
echo

# 列出目录内容
echo -e "${BLUE}==> 目录内容预览${NC}"
if command -v tree >/dev/null 2>&1; then
    tree -L 2 -a "$OPENCLAW_DIR" 2>/dev/null || ls -la "$OPENCLAW_DIR"
else
    ls -la "$OPENCLAW_DIR"
fi
echo

# 确认是否继续
read -r -p "$(echo -e ${YELLOW}是否继续备份和清理？${NC}) [y/N]: " answer
if [[ ! "$answer" =~ ^[yY]$ ]]; then
    echo -e "${YELLOW}已取消${NC}"
    exit 0
fi

echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}                    开始备份流程                            ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# 创建备份目录
echo -e "${BLUE}==> [1/4] 创建备份目录${NC}"
mkdir -p "$BACKUP_DIR"
echo "    备份目录: $BACKUP_DIR"
echo

# 备份重要配置文件
echo -e "${BLUE}==> [2/4] 备份重要配置文件${NC}"

# 定义需要备份的重要文件和目录
IMPORTANT_ITEMS=(
    "config"
    "state"
    "workspace"
    ".env"
    "*.yaml"
    "*.yml"
    "*.json"
    "*.jsonc"
    "*.toml"
    "*.conf"
    "*.md"
)

BACKUP_COUNT=0

# 备份整个目录结构
echo "  正在备份完整目录结构..."
cp -R "$OPENCLAW_DIR" "$BACKUP_DIR/openclaw_full_backup" 2>/dev/null || true
if [[ -d "$BACKUP_DIR/openclaw_full_backup" ]]; then
    echo -e "${GREEN}  ✓ 完整备份已创建${NC}"
    BACKUP_COUNT=$((BACKUP_COUNT + 1))
fi
echo

# 单独备份重要文件（便于查找）
echo "  正在提取重要配置文件..."
IMPORTANT_DIR="$BACKUP_DIR/important_configs"
mkdir -p "$IMPORTANT_DIR"

for pattern in "${IMPORTANT_ITEMS[@]}"; do
    # 查找匹配的文件和目录
    while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        
        # 获取相对路径
        rel_path="${item#$OPENCLAW_DIR/}"
        target_dir="$IMPORTANT_DIR/$(dirname "$rel_path")"
        
        # 创建目标目录
        mkdir -p "$target_dir"
        
        # 复制文件或目录
        if [[ -d "$item" ]]; then
            cp -R "$item" "$target_dir/" 2>/dev/null && echo "    ✓ $rel_path (目录)"
        elif [[ -f "$item" ]]; then
            cp "$item" "$target_dir/" 2>/dev/null && echo "    ✓ $rel_path"
        fi
        
        BACKUP_COUNT=$((BACKUP_COUNT + 1))
    done < <(find "$OPENCLAW_DIR" -maxdepth 3 -name "$pattern" 2>/dev/null || true)
done

echo
echo -e "${GREEN}  已备份 $BACKUP_COUNT 个项目${NC}"
echo

# 创建备份清单
echo -e "${BLUE}==> [3/4] 创建备份清单${NC}"
MANIFEST="$BACKUP_DIR/BACKUP_MANIFEST.txt"

cat > "$MANIFEST" <<EOF
OpenClaw 配置备份清单
=====================

备份时间: $(date '+%Y-%m-%d %H:%M:%S')
原始路径: $OPENCLAW_DIR
备份路径: $BACKUP_DIR
目录大小: $DIR_SIZE

备份内容:
---------

1. 完整备份
   路径: openclaw_full_backup/
   说明: ~/.openclaw 目录的完整副本

2. 重要配置文件
   路径: important_configs/
   说明: 提取的重要配置文件，便于查找

目录结构:
---------

EOF

# 添加目录树到清单
if command -v tree >/dev/null 2>&1; then
    tree -a "$BACKUP_DIR" >> "$MANIFEST" 2>/dev/null || ls -laR "$BACKUP_DIR" >> "$MANIFEST"
else
    ls -laR "$BACKUP_DIR" >> "$MANIFEST"
fi

echo "  清单文件: $MANIFEST"
echo -e "${GREEN}  ✓ 备份清单已创建${NC}"
echo

# 备份 Shell 配置中的 OpenClaw 相关行
echo -e "${BLUE}==> [4/4] 备份 Shell 配置${NC}"
SHELL_BACKUP="$BACKUP_DIR/shell_configs"
mkdir -p "$SHELL_BACKUP"

SHELL_FILES=(
    "$HOME/.zshrc"
    "$HOME/.zprofile"
    "$HOME/.bashrc"
    "$HOME/.bash_profile"
    "$HOME/.profile"
)

for f in "${SHELL_FILES[@]}"; do
    if [[ -f "$f" ]] && grep -qi 'openclaw' "$f" 2>/dev/null; then
        filename=$(basename "$f")
        # 备份完整文件
        cp "$f" "$SHELL_BACKUP/${filename}.full" 2>/dev/null
        # 提取 OpenClaw 相关行
        grep -i 'openclaw' "$f" > "$SHELL_BACKUP/${filename}.openclaw_lines" 2>/dev/null || true
        echo "  ✓ 已备份: $filename"
    fi
done

echo -e "${GREEN}  ✓ Shell 配置已备份${NC}"
echo

# 显示备份摘要
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}                    备份完成                                ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "${GREEN}✓ 备份已完成${NC}"
echo
echo "📦 备份信息："
echo "   • 备份目录: $BACKUP_DIR"
echo "   • 原始大小: $DIR_SIZE"
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
echo "   • 备份大小: $BACKUP_SIZE"
echo "   • 备份清单: BACKUP_MANIFEST.txt"
echo

# 确认是否删除原目录
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}                    开始清理流程                            ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

read -r -p "$(echo -e ${YELLOW}备份已完成，是否删除 ~/.openclaw 目录？${NC}) [y/N]: " delete_answer
if [[ ! "$delete_answer" =~ ^[yY]$ ]]; then
    echo -e "${YELLOW}已取消删除，仅保留备份${NC}"
    echo
    echo "备份位置: $BACKUP_DIR"
    exit 0
fi

echo
echo -e "${BLUE}==> 删除 ~/.openclaw 目录${NC}"
rm -rf "$OPENCLAW_DIR"

if [[ ! -d "$OPENCLAW_DIR" ]]; then
    echo -e "${GREEN}  ✓ 目录已删除${NC}"
else
    echo -e "${RED}  ✗ 删除失败${NC}"
    exit 1
fi

echo

# 清理 Shell 配置
echo -e "${BLUE}==> 清理 Shell 配置文件${NC}"
for f in "${SHELL_FILES[@]}"; do
    if [[ -f "$f" ]] && grep -qi 'openclaw' "$f" 2>/dev/null; then
        filename=$(basename "$f")
        # 创建备份
        cp "$f" "$f.backup_${TIMESTAMP}"
        # 删除 OpenClaw 相关行
        grep -vi 'openclaw' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
        echo "  ✓ 已清理: $filename (备份: ${filename}.backup_${TIMESTAMP})"
    fi
done

echo

# 最终总结
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}                      完成                                  ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║  ✓✓✓  备份和清理已完成  ✓✓✓                              ║${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo
echo "📋 操作摘要："
echo "   ✓ 已备份配置文件到: $BACKUP_DIR"
echo "   ✓ 已删除目录: ~/.openclaw"
echo "   ✓ 已清理 Shell 配置文件"
echo
echo "📦 备份内容："
echo "   • 完整备份: openclaw_full_backup/"
echo "   • 重要配置: important_configs/"
echo "   • Shell 配置: shell_configs/"
echo "   • 备份清单: BACKUP_MANIFEST.txt"
echo
echo "🔄 后续步骤："
echo "   1. 重启终端以应用更改: exec \$SHELL -l"
echo "   2. 验证清理结果: ./verify-uninstall.sh"
echo "   3. 如需恢复配置，查看备份目录: $BACKUP_DIR"
echo
echo "💡 提示："
echo "   • 备份将永久保留，可随时查看或恢复"
echo "   • 如确认不再需要，可手动删除备份目录"
echo "   • 现在可以重新安装 OpenClaw 了"
echo
