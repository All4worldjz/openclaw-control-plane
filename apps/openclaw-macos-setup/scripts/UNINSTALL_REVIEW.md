# OpenClaw 卸载脚本 Review

## 原脚本问题分析

你提供的脚本有以下问题需要改进：

### 1. 安全性问题
- ❌ Docker 清理过于激进，使用 `awk 'BEGIN{IGNORECASE=1} /openclaw|claw/'` 会匹配到所有包含 "claw" 的资源
  - 可能误删其他应用（如 "claw-tool", "data-claw" 等）
- ❌ `pkill -f -i "claw"` 会杀死所有包含 "claw" 的进程，范围太广
- ❌ Shell 配置文件清理使用 `perl -ni -e 'print unless /openclaw|open-claw/i'` 直接修改，没有充分备份

### 2. 功能缺失
- ❌ 没有卸载 npm 全局安装的 `openclaw` 包（这是主要安装方式）
- ❌ 没有处理 LaunchAgent 服务的正确卸载流程
- ❌ 没有检查进程是否成功停止
- ❌ 缺少颜色输出，用户体验差

### 3. 逻辑问题
- ❌ `find "$HOME" ... -maxdepth 4` 只显示文件但不删除，用户不知道如何处理
- ❌ LaunchAgent 清理逻辑不完整，没有先 unload 再删除
- ❌ 当前目录检测 `basename "$CURRENT_DIR" | tr '[:upper:]' '[:lower:]'` 语法错误

### 4. 用户体验问题
- ❌ 所有危险操作都需要确认，但没有批量选项
- ❌ 没有进度提示（如 [1/8]）
- ❌ 错误处理不够友好

## 改进后的脚本特性

### ✅ 安全性增强
1. 精确匹配：Docker 资源使用 `--filter "name=openclaw"` 而不是模糊匹配
2. 进程管理：只杀死 `openclaw` 和 `litellm` 进程，不使用通配符
3. 备份机制：Shell 配置文件修改前创建带时间戳的备份
4. 确认机制：所有危险操作都需要用户确认
5. 防止 sudo 运行：避免误删系统文件

### ✅ 功能完整
1. 正确的卸载顺序：
   - 停止 LaunchAgent 服务
   - 停止运行中的进程
   - 卸载 npm 包
   - 卸载 pip 包（可选）
   - 删除配置目录
   - 清理 Docker 资源
   - 清理 Shell 配置
   - 搜索残留文件

2. LaunchAgent 处理：
   - 先 `launchctl unload`
   - 再 `launchctl remove`
   - 最后删除 plist 文件

3. npm 包卸载：
   - 检查是否安装
   - 使用 `npm uninstall -g openclaw`

### ✅ 用户体验优化
1. 彩色输出：使用 ANSI 颜色代码
2. 进度提示：显示 [1/8], [2/8] 等
3. 清晰的分组：每个步骤都有明确的标题
4. 友好的提示：告诉用户正在做什么
5. 最终建议：提供验证步骤

### ✅ 不会破坏的内容
- ✅ Node.js、npm、Python、pip 等系统工具
- ✅ 其他应用的配置
- ✅ 系统级配置文件
- ✅ 用户数据（除非明确属于 OpenClaw）

## 使用方法

```bash
# 1. 赋予执行权限（已完成）
chmod +x uninstall-openclaw.sh

# 2. 运行脚本
./uninstall-openclaw.sh

# 3. 按提示操作
# - 阅读将要清理的内容
# - 确认继续
# - 对每个危险操作进行确认

# 4. 验证卸载
which openclaw  # 应该找不到
npm list -g | grep openclaw  # 应该为空
ls ~/Library/Application\ Support/ | grep -i openclaw  # 应该为空
```

## 测试建议

在实际使用前，建议：

1. 在测试环境运行一次
2. 检查备份文件是否正确创建
3. 验证不会误删其他应用的文件
4. 确认所有 OpenClaw 组件都被清理

## 与原脚本的主要区别

| 功能 | 原脚本 | 改进脚本 |
|------|--------|----------|
| npm 包卸载 | ❌ 缺失 | ✅ 完整 |
| LaunchAgent | ⚠️ 不完整 | ✅ 完整 |
| 进程管理 | ⚠️ 过于激进 | ✅ 精确匹配 |
| Docker 清理 | ⚠️ 误删风险 | ✅ 精确过滤 |
| Shell 配置 | ⚠️ 直接修改 | ✅ 备份后修改 |
| 用户体验 | ⚠️ 基础 | ✅ 友好 |
| 安全检查 | ⚠️ 基础 | ✅ 完善 |
| 错误处理 | ⚠️ 基础 | ✅ 健壮 |

## 总结

改进后的脚本：
- ✅ 更安全：不会误删其他应用的文件
- ✅ 更完整：覆盖所有 OpenClaw 组件
- ✅ 更友好：清晰的提示和进度显示
- ✅ 更可靠：完善的错误处理和备份机制

适合在调试过程中反复使用，为下次安装准备干净的环境。
