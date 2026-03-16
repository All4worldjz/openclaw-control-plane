# openclaw-macos-setup/scripts/

macOS 宇宙运维脚本集。对应宪章 bootstrap 顺序第 9 步（备份与可观测性）和调试循环。

---

## 脚本清单

### uninstall-openclaw.sh
**主卸载脚本**（四阶段一体化）

| 阶段 | 内容 |
|------|------|
| 1. 备份 | state 目录、配置文件、workspace、shell 配置 → `~/openclaw_backup_<timestamp>/` |
| 2. 停止 & 删除 | 官方 CLI 顺序（`gateway stop` → `gateway uninstall`）+ 手动 LaunchAgent 清理 + 文件删除 |
| 3. 清理包 | npm/pnpm/bun 全局包、可选 LiteLLM、shell 配置行 |
| 4. 验证 | 9 项检查，输出通过/失败汇总 |

支持：`OPENCLAW_STATE_DIR` / `OPENCLAW_CONFIG_PATH` env var 覆盖、多 profile（`~/.openclaw-*`）、自定义 workspace 路径。

```bash
./scripts/uninstall-openclaw.sh
```

### verify-uninstall.sh
`uninstall-openclaw.sh` 的副本，可单独运行验证阶段（直接执行会走完整四阶段）。

### backup-and-clean.sh
**独立备份工具**，仅针对 `~/.openclaw` 目录。适合只需要备份、不执行完整卸载的场景。

```bash
./scripts/backup-and-clean.sh
```

### test-cleanup-coverage.sh
验证卸载脚本是否覆盖了所有预期目录。用于脚本开发时的自测。

```bash
./scripts/test-cleanup-coverage.sh
```

### bootstrap-litellm-macos.sh
LiteLLM 独立引导脚本。适合在安装器之外手动部署 LiteLLM 的场景。

### setup-litellm-router-macos.sh
LiteLLM 路由配置脚本。配置抽象模型组（`coding_primary`、`fast_chat` 等）到具体 provider 的映射。

---

## 宪章对齐说明

这些脚本遵循以下宪章原则：

- **Git 边界**（`docs/policies/01-git-boundaries.md`）：脚本本身入库，备份产物（含 API key、OAuth token）写到 `~/openclaw_backup_*/`，永不入库
- **备份优先**（`docs/runbooks/01-bootstrap-order.md` 第9步）：所有删除操作前强制备份
- **最小权限**：脚本拒绝 sudo 运行，只操作用户目录
- **全审计**：备份清单 `BACKUP_MANIFEST.txt` 记录所有操作的文件列表和时间戳

---

## 调试循环

```bash
# 1. 发现问题，需要重置环境
./scripts/uninstall-openclaw.sh

# 2. 重启终端
exec $SHELL -l

# 3. 重新安装（通过 Tauri 安装器）
pnpm tauri dev
```

---

## 安装器开发

```bash
# 安装依赖
pnpm install

# 开发模式
pnpm tauri dev

# 构建 macOS App Bundle
pnpm tauri build
# 产物：src-tauri/target/release/bundle/macos/OpenClaw macOS Setup.app

# Rust 后端检查
cd src-tauri && cargo check
```

Node 环境（如有多版本）：
```bash
PATH="$HOME/.cargo/bin:$HOME/.nvm/versions/node/v22.22.1/bin:$PATH"
```
