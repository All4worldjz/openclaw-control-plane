# scripts/

维护脚本集合，用于 OpenClaw macOS 环境的安装调试和清理。

---

## uninstall-openclaw.sh

OpenClaw macOS 完整卸载脚本，四阶段自动执行：

| 阶段 | 内容 |
|------|------|
| 1. 备份 | 将 state 目录、配置文件、workspace、shell 配置备份到 `~/openclaw_backup_<timestamp>/` |
| 2. 停止 & 删除 | 停止 LaunchAgent 服务，删除所有 OpenClaw 文件和目录 |
| 3. 清理包 | 卸载 npm 全局包，可选卸载 LiteLLM，清理 shell 配置 |
| 4. 验证 | 9 项检查，输出通过/失败汇总 |

### 用法

```bash
# 从项目根目录运行
./scripts/uninstall-openclaw.sh

# 或从 openclaw-macos-setup 目录运行（同一脚本）
./openclaw-macos-setup/uninstall-openclaw.sh
```

### 支持的场景

- 尊重 `OPENCLAW_STATE_DIR` / `OPENCLAW_CONFIG_PATH` / `OPENCLAW_PROFILE` 环境变量覆盖
- 自动检测安装器生成的 `install_root`（从 LaunchAgent plist 推断）
- 处理多 profile 目录（`~/.openclaw-<profile>`）
- 读取 `openclaw.jsonc` 中的自定义 workspace 路径（可能在 state dir 之外）
- 处理所有 LaunchAgent labels：`ai.openclaw.litellm`、`ai.openclaw.runtime`、`ai.openclaw.gateway`、遗留 `com.openclaw.*`

### 备份说明

备份目录结构：

```
~/openclaw_backup_<timestamp>/
├── state/openclaw/          # 完整 state 目录（含 credentials/、agents/、memory/）
├── install_root/            # 安装器生成的目录（config、launch-agents、workspace 等）
├── profiles/                # 多 profile 目录 ~/.openclaw-*
├── workspace/               # 自定义 workspace（如在 state dir 之外）
├── configs/                 # 重要配置文件单独备份
│   ├── openclaw.json
│   ├── .env
│   └── prod-mac/
│       ├── openclaw.jsonc
│       ├── .env
│       └── litellm.yaml
├── shell_configs/           # shell 配置文件备份 + openclaw 相关行提取
└── BACKUP_MANIFEST.txt      # 备份清单（文件列表 + 大小）
```

> ⚠️ 备份可能包含 API 密钥、OAuth token 等敏感信息，请妥善保管或在确认无需恢复后安全删除。

### 注意事项

- 不要使用 `sudo` 运行
- 仅支持 macOS
- LiteLLM 卸载为可选项（脚本会询问确认）
- 脚本会在删除前自动备份，无需手动操作
