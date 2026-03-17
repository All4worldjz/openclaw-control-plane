# OpenClaw 清理目录清单

## 概述

本文档列出了卸载脚本会清理的所有 OpenClaw 相关目录。

## 主要目录

### 1. OpenClaw 默认安装目录
```
~/.openclaw
```
这是 OpenClaw 的默认安装目录，包含：
- 运行时文件
- 默认配置
- 工作区数据

### 2. 配置目录

#### XDG 标准配置目录
```
~/.config/openclaw
~/.config/OpenClaw
```
存储用户级配置文件。

#### macOS 标准配置目录
```
~/Library/Application Support/OpenClaw
~/Library/Application Support/openclaw
```
macOS 应用程序配置和数据的标准位置。

### 3. 缓存目录

#### XDG 标准缓存目录
```
~/.cache/openclaw
```
临时缓存文件。

#### macOS 标准缓存目录
```
~/Library/Caches/openclaw
~/Library/Caches/OpenClaw
```
macOS 应用程序缓存的标准位置。

### 4. 数据目录

#### XDG 标准数据目录
```
~/.local/share/openclaw
~/.local/share/OpenClaw
```
应用程序数据文件。

### 5. 日志目录

#### macOS 标准日志目录
```
~/Library/Logs/openclaw
~/Library/Logs/OpenClaw
```
应用程序日志文件。

### 6. 偏好设置文件

#### macOS Preferences
```
~/Library/Preferences/ai.openclaw.*.plist
~/Library/Preferences/com.openclaw.*.plist
```
macOS 应用程序偏好设置。

### 7. LaunchAgent 配置

#### 用户级 LaunchAgent
```
~/Library/LaunchAgents/ai.openclaw.litellm.plist
~/Library/LaunchAgents/ai.openclaw.runtime.plist
```
后台服务配置文件。

## 安装器特定目录

如果使用本安装器安装，还会创建：

```
~/Library/Application Support/OpenClaw/
├── config/
│   └── prod-mac/
│       ├── .env
│       ├── litellm.yaml
│       └── openclaw.jsonc
├── state/
│   ├── openclaw/
│   └── memory/
├── logs/
│   ├── service.stdout.log
│   └── service.stderr.log
├── launch-agents/
│   ├── ai.openclaw.litellm.plist
│   └── ai.openclaw.runtime.plist
├── app/
│   └── scripts/
│       ├── run-litellm.sh
│       └── run-openclaw.sh
└── workspace/
    ├── MEMORY.md
    ├── AGENTS.md
    ├── SOUL.md
    ├── TOOLS.md
    └── USER.md
```

## 清理覆盖范围

### ✅ 会被清理的内容

1. 所有上述目录和文件
2. npm 全局安装的 `openclaw` 包
3. pip 安装的 `litellm` 包（可选）
4. Shell 配置文件中的 OpenClaw 相关环境变量
5. Docker 容器、镜像、卷（如果使用 Docker 安装）
6. 运行中的 OpenClaw 和 LiteLLM 进程

### ❌ 不会被清理的内容

1. Node.js、npm、Python、pip 等系统工具
2. 其他应用程序的配置和数据
3. 系统级配置文件
4. 用户个人文档（除非明确存放在 OpenClaw 目录中）

## 验证清理

使用验证脚本检查所有目录是否已清理：

```bash
./verify-clean.sh
```

验证脚本会检查：
- ✓ 所有配置目录是否已删除
- ✓ npm 包是否已卸载
- ✓ 命令是否已移除
- ✓ 进程是否已停止
- ✓ LaunchAgent 是否已清理
- ✓ Shell 配置是否已清理

## 测试覆盖范围

使用测试脚本验证清理脚本的覆盖范围：

```bash
./test-cleanup-coverage.sh
```

测试脚本会确认所有预期目录都在清理列表中。

## 手动清理

如果自动清理失败，可以手动执行：

```bash
# 删除主目录
rm -rf ~/.openclaw

# 删除配置
rm -rf ~/.config/openclaw ~/.config/OpenClaw

# 删除 macOS 应用支持目录
rm -rf ~/Library/Application\ Support/OpenClaw
rm -rf ~/Library/Application\ Support/openclaw

# 删除缓存
rm -rf ~/.cache/openclaw
rm -rf ~/Library/Caches/openclaw ~/Library/Caches/OpenClaw

# 删除日志
rm -rf ~/Library/Logs/openclaw ~/Library/Logs/OpenClaw

# 删除 LaunchAgent
rm ~/Library/LaunchAgents/ai.openclaw.*.plist

# 卸载 npm 包
npm uninstall -g openclaw

# 卸载 pip 包（可选）
pip3 uninstall -y litellm
```

## 注意事项

1. **备份重要数据**：清理前请确保已备份重要的配置和数据
2. **确认目录内容**：如果不确定某个目录是否应该删除，先查看其内容
3. **Shell 配置备份**：脚本会自动备份 Shell 配置文件，备份文件格式为 `.zshrc.backup.YYYYMMDD_HHMMSS`
4. **Docker 资源**：Docker 镜像和卷的删除需要手动确认

## 更新日志

- 2024-03-16: 初始版本，包含所有 OpenClaw 可能使用的目录
- 2024-03-16: 明确标注 `~/.openclaw` 为默认安装目录
- 2024-03-16: 添加大小写变体（openclaw/OpenClaw）以确保完整覆盖
