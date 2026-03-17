use std::{
    collections::HashMap,
    env,
    fs,
    io::{BufRead, BufReader},
    path::{Path, PathBuf},
    process::{Command, Stdio},
};

use tauri::{command, AppHandle, Emitter};

use crate::models::{
    DoctorCheckItem, DoctorCheckResult, RenderConfigRequest,
    RenderConfigResult, RenderedFile, LaunchAgentCommandRequest, LaunchAgentCommandResult,
    ProvisionLiteLlmRequest, ProvisionLiteLlmResult, ProvisionStep, SmokeCheckItem,
    SmokeCheckRequest, SmokeCheckResult, InstallOpenClawRequest, InstallOpenClawResult,
};

// ── 环境检查 ──────────────────────────────────────────────────────────────────

#[command]
pub fn doctor_check() -> Result<DoctorCheckResult, String> {
    let checks = vec![
        probe_command("node",      true,  &["--version"], "运行 OpenClaw 所需的 Node.js 运行时"),
        probe_command("npm",       true,  &["--version"], "安装 OpenClaw npm 包所需"),
        probe_command("python3",   true,  &["--version"], "安装 LiteLLM 所需"),
        probe_command("pip3",      true,  &["--version"], "安装 LiteLLM Python 包所需"),
        probe_command("curl",      true,  &["--version"], "健康检查所需"),
        probe_command("launchctl", true,  &["help"],      "macOS 后台服务管理所需"),
        probe_command("brew",      false, &["--version"], "推荐安装，用于管理 macOS 依赖"),
    ];
    Ok(DoctorCheckResult {
        platform: env::consts::OS.to_string(),
        architecture: env::consts::ARCH.to_string(),
        checks,
    })
}

// ── 安装 OpenClaw（npm 全局包）────────────────────────────────────────────────

#[command]
pub fn install_openclaw(app: AppHandle, request: InstallOpenClawRequest) -> Result<InstallOpenClawResult, String> {
    let mut steps: Vec<ProvisionStep> = Vec::new();

    let version_spec = if request.version.trim().is_empty() {
        "openclaw@latest".to_string()
    } else {
        format!("openclaw@{}", request.version.trim())
    };

    // 实时输出 npm install 过程
    let _ = app.emit("install_progress", format!("开始安装 {version_spec}..."));
    
    let mut child = Command::new("npm")
        .args(["install", "-g", &version_spec])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("无法启动 npm：{e}"))?;

    // 实时读取 stdout
    if let Some(stdout) = child.stdout.take() {
        let reader = BufReader::new(stdout);
        for line in reader.lines() {
            if let Ok(line) = line {
                let _ = app.emit("install_progress", line.clone());
            }
        }
    }

    let output = child.wait_with_output()
        .map_err(|e| format!("等待 npm 完成失败：{e}"))?;

    if output.status.success() {
        steps.push(ProvisionStep {
            name: "npm-install-openclaw".to_string(),
            ok: true,
            detail: format!("已安装 {version_spec}"),
        });
        let _ = app.emit("install_progress", format!("✓ {version_spec} 安装成功"));
    } else {
        let err = stderr_or_stdout(&output.stderr, &output.stdout);
        steps.push(ProvisionStep {
            name: "npm-install-openclaw".to_string(),
            ok: false,
            detail: err.clone(),
        });
        let _ = app.emit("install_progress", format!("✗ 安装失败：{err}"));
        return Ok(InstallOpenClawResult { steps });
    }

    // 验证 openclaw 命令可用
    let _ = app.emit("install_progress", "验证 openclaw 命令...");
    let ver_out = Command::new("openclaw").args(["--version"]).output();
    match ver_out {
        Ok(out) if out.status.success() => {
            let ver = first_non_empty_line(&out.stdout)
                .or_else(|| first_non_empty_line(&out.stderr))
                .unwrap_or("unknown")
                .to_string();
            steps.push(ProvisionStep {
                name: "verify-openclaw-cli".to_string(),
                ok: true,
                detail: format!("openclaw 命令可用，版本：{ver}"),
            });
            let _ = app.emit("install_progress", format!("✓ openclaw 命令可用，版本：{ver}"));
        }
        Ok(out) => {
            let err = stderr_or_stdout(&out.stderr, &out.stdout);
            steps.push(ProvisionStep {
                name: "verify-openclaw-cli".to_string(),
                ok: false,
                detail: err.clone(),
            });
            let _ = app.emit("install_progress", format!("✗ openclaw 命令验证失败：{err}"));
        }
        Err(e) => {
            let err = format!("openclaw 命令未找到：{e}");
            steps.push(ProvisionStep {
                name: "verify-openclaw-cli".to_string(),
                ok: false,
                detail: err.clone(),
            });
            let _ = app.emit("install_progress", format!("✗ {err}"));
        }
    }

    Ok(InstallOpenClawResult { steps })
}

// ── 生成配置文件 ──────────────────────────────────────────────────────────────

#[command]
pub fn render_prod_mac_config(request: RenderConfigRequest) -> Result<RenderConfigResult, String> {
    let install_root = expand_home(&request.install_root)?;

    let config_dir          = install_root.join("config/prod-mac");
    let state_dir           = install_root.join("state/openclaw");
    let memory_dir          = install_root.join("state/memory");
    let logs_dir            = install_root.join("logs");
    let launch_agents_dir   = install_root.join("launch-agents");
    let scripts_dir         = install_root.join("app/scripts");
    let workspace_dir       = install_root.join("workspace");
    let workspace_memory_dir = workspace_dir.join("memory");

    for dir in [&config_dir, &state_dir, &memory_dir, &logs_dir,
                &launch_agents_dir, &scripts_dir, &workspace_dir, &workspace_memory_dir] {
        fs::create_dir_all(dir)
            .map_err(|e| format!("创建目录失败 {}：{e}", dir.display()))?;
    }

    let env_path             = config_dir.join(".env");
    let litellm_config_path  = config_dir.join("litellm.yaml");
    let openclaw_config_path = config_dir.join("openclaw.jsonc");
    let litellm_plist_path   = launch_agents_dir.join("ai.openclaw.litellm.plist");
    let runtime_plist_path   = launch_agents_dir.join("ai.openclaw.runtime.plist");
    let run_litellm_script   = scripts_dir.join("run-litellm.sh");
    let run_openclaw_script  = scripts_dir.join("run-openclaw.sh");
    let memory_md_path       = workspace_dir.join("MEMORY.md");
    let agents_md_path       = workspace_dir.join("AGENTS.md");
    let soul_md_path         = workspace_dir.join("SOUL.md");
    let tools_md_path        = workspace_dir.join("TOOLS.md");
    let user_md_path         = workspace_dir.join("USER.md");

    let mut v: HashMap<&str, String> = HashMap::new();
    v.insert("OPENCLAW_CONFIG_PATH",  openclaw_config_path.display().to_string());
    v.insert("OPENCLAW_STATE_DIR",    state_dir.display().to_string());
    v.insert("OPENCLAW_WORKSPACE_DIR",workspace_dir.display().to_string());
    v.insert("LITELLM_CONFIG_PATH",   litellm_config_path.display().to_string());
    v.insert("LITELLM_MASTER_KEY",    "sk-openclaw-prod-mac".to_string());
    v.insert("GEMINI_API_KEY",        request.provider_keys.gemini.clone());
    v.insert("MINIMAX_API_KEY",       request.provider_keys.minimax.clone());
    v.insert("DASHSCOPE_API_KEY",     request.provider_keys.dashscope.clone());
    v.insert("OPENROUTER_API_KEY",    request.provider_keys.openrouter.clone());
    v.insert("SILICONFLOW_API_KEY",   request.provider_keys.siliconflow.clone());
    v.insert("TELEGRAM_BOT_TOKEN",    request.channels.telegram_bot_token.clone());
    v.insert("FEISHU_APP_ID",         request.channels.feishu_app_id.clone());
    v.insert("FEISHU_APP_SECRET",     request.channels.feishu_app_secret.clone());
    v.insert("FEISHU_VERIFICATION_TOKEN", request.channels.feishu_verification_token.clone());
    v.insert("FEISHU_ENCRYPT_KEY",    request.channels.feishu_encrypt_key.clone());
    v.insert("WHATSAPP_ACCOUNT_NAME", request.channels.whatsapp_account_name.clone());
    v.insert("MEM0_API_KEY",          request.memory.mem0_api_key.clone());
    v.insert("MEM0_API_BASE",         request.memory.mem0_api_base.clone());
    v.insert("OLLAMA_HOST",           request.memory.ollama_host.clone());
    v.insert("EMBEDDING_MODEL",       request.memory.embedding_model.clone());
    v.insert("FEISHU_ENABLED",        bool_literal(!request.channels.feishu_app_id.trim().is_empty()));
    v.insert("TELEGRAM_ENABLED",      bool_literal(!request.channels.telegram_bot_token.trim().is_empty()));
    v.insert("DASHSCOPE_FAST_MODEL",  "qwen-flash".to_string());
    v.insert("DASHSCOPE_BALANCED_MODEL", "qwen-plus".to_string());
    v.insert("DASHSCOPE_CODE_MODEL",  "qwen3-coder-plus".to_string());
    v.insert("GEMINI_FAST_MODEL",     "gemini-3-flash-preview".to_string());
    v.insert("GEMINI_DEEP_MODEL",     "gemini-3-pro-preview".to_string());
    v.insert("SHELL_PATH",            "/bin/zsh".to_string());
    v.insert("ENV_PATH",              env_path.display().to_string());
    v.insert("WORKING_DIR",           install_root.display().to_string());
    v.insert("RUN_LITELLM_SCRIPT",    run_litellm_script.display().to_string());
    v.insert("RUN_OPENCLAW_SCRIPT",   run_openclaw_script.display().to_string());
    v.insert("STDOUT_PATH",           logs_dir.join("service.stdout.log").display().to_string());
    v.insert("STDERR_PATH",           logs_dir.join("service.stderr.log").display().to_string());
    v.insert("RUN_AT_LOAD",           if request.launch_at_login { "true" } else { "false" }.to_string());

    write_template("templates/prod-mac.env.tmpl",              &env_path,             &v)?;
    write_template("templates/openclaw.prod-mac.jsonc.tmpl",   &openclaw_config_path, &v)?;
    write_template("templates/litellm.prod-mac.yaml.tmpl",     &litellm_config_path,  &v)?;
    write_template("templates/ai.openclaw.litellm.plist.tmpl", &litellm_plist_path,   &v)?;
    write_template("templates/ai.openclaw.runtime.plist.tmpl", &runtime_plist_path,   &v)?;
    write_template("templates/run-litellm.sh.tmpl",            &run_litellm_script,   &v)?;
    write_template("templates/run-openclaw.sh.tmpl",           &run_openclaw_script,  &v)?;
    ensure_executable(&run_litellm_script)?;
    ensure_executable(&run_openclaw_script)?;
    write_template("templates/MEMORY.md.tmpl", &memory_md_path, &v)?;
    write_template("templates/AGENTS.md.tmpl", &agents_md_path, &v)?;
    write_template("templates/SOUL.md.tmpl",   &soul_md_path,   &v)?;
    write_template("templates/TOOLS.md.tmpl",  &tools_md_path,  &v)?;
    write_template("templates/USER.md.tmpl",   &user_md_path,   &v)?;

    let generated_files = vec![
        RenderedFile { path: env_path.display().to_string(),             kind: "env".to_string() },
        RenderedFile { path: openclaw_config_path.display().to_string(), kind: "openclaw-config".to_string() },
        RenderedFile { path: litellm_config_path.display().to_string(),  kind: "litellm-config".to_string() },
        RenderedFile { path: litellm_plist_path.display().to_string(),   kind: "launch-agent".to_string() },
        RenderedFile { path: runtime_plist_path.display().to_string(),   kind: "launch-agent".to_string() },
        RenderedFile { path: run_litellm_script.display().to_string(),   kind: "script".to_string() },
        RenderedFile { path: run_openclaw_script.display().to_string(),  kind: "script".to_string() },
        RenderedFile { path: memory_md_path.display().to_string(),       kind: "workspace".to_string() },
        RenderedFile { path: agents_md_path.display().to_string(),       kind: "workspace".to_string() },
        RenderedFile { path: soul_md_path.display().to_string(),         kind: "workspace".to_string() },
        RenderedFile { path: tools_md_path.display().to_string(),        kind: "workspace".to_string() },
        RenderedFile { path: user_md_path.display().to_string(),         kind: "workspace".to_string() },
    ];

    Ok(RenderConfigResult { profile: "prod/mac".to_string(), generated_files })
}

// ── 安装 LiteLLM ──────────────────────────────────────────────────────────────

#[command]
pub fn provision_litellm_prod_mac(app: AppHandle, request: ProvisionLiteLlmRequest) -> Result<ProvisionLiteLlmResult, String> {
    let install_root = expand_home(&request.install_root)?;
    let logs_dir = install_root.join("logs");
    fs::create_dir_all(&logs_dir)
        .map_err(|e| format!("创建日志目录失败：{e}"))?;

    let mut steps = Vec::new();
    
    let _ = app.emit("install_progress", "开始安装 LiteLLM...");
    
    let mut child = Command::new("python3")
        .args(["-m", "pip", "install", "--upgrade", "litellm[proxy]", "pyyaml"])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("无法启动 pip：{e}"))?;

    // 实时读取输出
    if let Some(stdout) = child.stdout.take() {
        let reader = BufReader::new(stdout);
        for line in reader.lines() {
            if let Ok(line) = line {
                let _ = app.emit("install_progress", line.clone());
            }
        }
    }

    let output = child.wait_with_output()
        .map_err(|e| format!("等待 pip 完成失败：{e}"))?;

    if output.status.success() {
        steps.push(ProvisionStep {
            name: "pip-install-litellm".to_string(),
            ok: true,
            detail: "litellm[proxy] 和 pyyaml 安装成功".to_string(),
        });
        let _ = app.emit("install_progress", "✓ LiteLLM 安装成功");
    } else {
        let err = stderr_or_stdout(&output.stderr, &output.stdout);
        steps.push(ProvisionStep {
            name: "pip-install-litellm".to_string(),
            ok: false,
            detail: err.clone(),
        });
        let _ = app.emit("install_progress", format!("✗ 安装失败：{err}"));
    }

    Ok(ProvisionLiteLlmResult { steps })
}

// ── Smoke 检查 ────────────────────────────────────────────────────────────────

#[command]
pub fn smoke_check_prod_mac(request: SmokeCheckRequest) -> Result<SmokeCheckResult, String> {
    let install_root = expand_home(&request.install_root)?;
    let config_dir = install_root.join("config/prod-mac");

    let mut checks = vec![
        file_exists_check("环境变量文件 (.env)",    &config_dir.join(".env")),
        file_exists_check("LiteLLM 配置文件",       &config_dir.join("litellm.yaml")),
        file_exists_check("OpenClaw 配置文件",      &config_dir.join("openclaw.jsonc")),
        file_exists_check("LiteLLM 后台服务配置",   &install_root.join("launch-agents/ai.openclaw.litellm.plist")),
        file_exists_check("OpenClaw 后台服务配置",  &install_root.join("launch-agents/ai.openclaw.runtime.plist")),
        file_exists_check("LiteLLM 启动脚本",       &install_root.join("app/scripts/run-litellm.sh")),
        file_exists_check("OpenClaw 启动脚本",      &install_root.join("app/scripts/run-openclaw.sh")),
        cli_check("openclaw 命令可用", "openclaw", &["--version"]),
        cli_check("litellm 命令可用",  "litellm",  &["--version"]),
        http_check("LiteLLM 服务就绪", "http://127.0.0.1:4000/health/readiness"),
    ];

    // 如果 openclaw 可用，顺便跑一下 doctor
    if checks.iter().find(|c| c.name == "openclaw 命令可用").map(|c| c.ok).unwrap_or(false) {
        checks.push(cli_check("openclaw doctor", "openclaw", &["doctor"]));
    }

    Ok(SmokeCheckResult { checks })
}

// ── LaunchAgent 控制 ──────────────────────────────────────────────────────────

#[command]
pub fn launch_agent_load(request: LaunchAgentCommandRequest) -> Result<LaunchAgentCommandResult, String> {
    run_launchctl("load", request)
}

#[command]
pub fn launch_agent_unload(request: LaunchAgentCommandRequest) -> Result<LaunchAgentCommandResult, String> {
    run_launchctl("unload", request)
}

#[command]
pub fn launch_agent_status(request: LaunchAgentCommandRequest) -> Result<LaunchAgentCommandResult, String> {
    let label = launch_agent_label(&request.service)?;
    let output = Command::new("launchctl")
        .args(["print", &format!("gui/{}/{}", uid_string()?, label)])
        .output()
        .map_err(|e| format!("launchctl print 失败：{e}"))?;

    Ok(LaunchAgentCommandResult {
        service: request.service,
        action: "status".to_string(),
        ok: output.status.success(),
        detail: stderr_or_stdout(&output.stderr, &output.stdout),
    })
}

// ── 内部工具函数 ──────────────────────────────────────────────────────────────

fn probe_command(binary: &str, required: bool, args: &[&str], detail: &str) -> DoctorCheckItem {
    match Command::new(binary).args(args).output() {
        Ok(out) if out.status.success() => {
            let version = first_non_empty_line(&out.stdout)
                .or_else(|| first_non_empty_line(&out.stderr))
                .map(|l| l.to_string());
            DoctorCheckItem { name: binary.to_string(), required, found: true, version, detail: detail.to_string() }
        }
        Ok(out) => DoctorCheckItem {
            name: binary.to_string(), required, found: false, version: None,
            detail: format!("{detail}（退出码 {}）", out.status.code().unwrap_or_default()),
        },
        Err(e) => DoctorCheckItem {
            name: binary.to_string(), required, found: false, version: None,
            detail: format!("{detail}（{e}）"),
        },
    }
}

fn cli_check(name: &str, binary: &str, args: &[&str]) -> SmokeCheckItem {
    match Command::new(binary).args(args).output() {
        Ok(out) => SmokeCheckItem {
            name: name.to_string(),
            ok: out.status.success(),
            detail: if out.status.success() {
                first_non_empty_line(&out.stdout)
                    .or_else(|| first_non_empty_line(&out.stderr))
                    .unwrap_or("ok")
                    .to_string()
            } else {
                stderr_or_stdout(&out.stderr, &out.stdout)
            },
        },
        Err(e) => SmokeCheckItem { name: name.to_string(), ok: false, detail: format!("命令未找到：{e}") },
    }
}

fn first_non_empty_line(bytes: &[u8]) -> Option<&str> {
    std::str::from_utf8(bytes).ok()?.lines().find(|l| !l.trim().is_empty())
}

fn expand_home(raw: &str) -> Result<PathBuf, String> {
    if raw == "~" || raw.starts_with("~/") {
        let home = env::var("HOME").map_err(|e| format!("无法解析 HOME：{e}"))?;
        let suffix = raw.strip_prefix("~/").unwrap_or("");
        return Ok(Path::new(&home).join(suffix));
    }
    Ok(PathBuf::from(raw))
}

fn write_template(rel: &str, dest: &Path, values: &HashMap<&str, String>) -> Result<(), String> {
    let tmpl = Path::new(env!("CARGO_MANIFEST_DIR")).join(rel);
    let mut content = fs::read_to_string(&tmpl)
        .map_err(|e| format!("读取模板 {} 失败：{e}", tmpl.display()))?;
    for (k, v) in values {
        content = content.replace(&format!("{{{{{k}}}}}"), v);
    }
    fs::write(dest, content).map_err(|e| format!("写入 {} 失败：{e}", dest.display()))
}

fn ensure_executable(path: &Path) -> Result<(), String> {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = fs::metadata(path)
            .map_err(|e| format!("读取权限失败 {}：{e}", path.display()))?.permissions();
        perms.set_mode(0o755);
        fs::set_permissions(path, perms)
            .map_err(|e| format!("设置可执行权限失败 {}：{e}", path.display()))
    }
    #[cfg(not(unix))]
    { let _ = path; Ok(()) }
}

fn bool_literal(v: bool) -> String { if v { "true".to_string() } else { "false".to_string() } }

fn file_exists_check(name: &str, path: &Path) -> SmokeCheckItem {
    SmokeCheckItem { name: name.to_string(), ok: path.exists(), detail: path.display().to_string() }
}

fn http_check(name: &str, url: &str) -> SmokeCheckItem {
    match Command::new("curl").args(["-sS", "-o", "/dev/null", "-w", "%{http_code}", "--max-time", "5", url]).output() {
        Ok(out) if out.status.success() => {
            let code = String::from_utf8_lossy(&out.stdout).trim().to_string();
            SmokeCheckItem { name: name.to_string(), ok: code == "200", detail: format!("HTTP {code}") }
        }
        Ok(out) => SmokeCheckItem { name: name.to_string(), ok: false, detail: stderr_or_stdout(&out.stderr, &out.stdout) },
        Err(e) => SmokeCheckItem { name: name.to_string(), ok: false, detail: format!("curl 失败：{e}") },
    }
}

fn run_launchctl(action: &str, request: LaunchAgentCommandRequest) -> Result<LaunchAgentCommandResult, String> {
    let install_root = expand_home(&request.install_root)?;
    let plist = launch_agent_plist_path(&install_root, &request.service)?;
    let plist_str = plist.to_str().ok_or("LaunchAgent 路径含非 UTF-8 字符")?;
    let out = Command::new("launchctl").args([action, plist_str]).output()
        .map_err(|e| format!("launchctl {action} 失败：{e}"))?;
    Ok(LaunchAgentCommandResult {
        service: request.service, action: action.to_string(),
        ok: out.status.success(), detail: stderr_or_stdout(&out.stderr, &out.stdout),
    })
}

fn launch_agent_plist_path(install_root: &Path, service: &str) -> Result<PathBuf, String> {
    let name = match service {
        "litellm" => "ai.openclaw.litellm.plist",
        "runtime" => "ai.openclaw.runtime.plist",
        _ => return Err(format!("未知服务：{service}")),
    };
    Ok(install_root.join("launch-agents").join(name))
}

fn launch_agent_label(service: &str) -> Result<&'static str, String> {
    match service {
        "litellm" => Ok("ai.openclaw.litellm"),
        "runtime" => Ok("ai.openclaw.runtime"),
        _ => Err(format!("未知服务：{service}")),
    }
}

fn uid_string() -> Result<String, String> {
    let out = Command::new("id").arg("-u").output()
        .map_err(|e| format!("id -u 失败：{e}"))?;
    if out.status.success() {
        Ok(String::from_utf8_lossy(&out.stdout).trim().to_string())
    } else {
        Err(stderr_or_stdout(&out.stderr, &out.stdout))
    }
}

fn stderr_or_stdout(stderr: &[u8], stdout: &[u8]) -> String {
    let s = String::from_utf8_lossy(stderr).trim().to_string();
    if !s.is_empty() { s } else { String::from_utf8_lossy(stdout).trim().to_string() }
}
