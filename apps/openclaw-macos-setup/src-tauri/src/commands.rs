use std::{
    collections::HashMap,
    env,
    fs,
    path::{Path, PathBuf},
    process::Command,
};

use tauri::command;

use crate::models::{
    CloneRepoRequest, CloneRepoResult, DoctorCheckItem, DoctorCheckResult, RenderConfigRequest,
    RenderConfigResult, RenderedFile, LaunchAgentCommandRequest, LaunchAgentCommandResult,
    ProvisionLiteLlmRequest, ProvisionLiteLlmResult, ProvisionStep, SmokeCheckItem,
    SmokeCheckRequest, SmokeCheckResult, ProvisionOpenClawRuntimeRequest,
};

#[command]
pub fn doctor_check() -> Result<DoctorCheckResult, String> {
    let checks = vec![
        probe_command("git", true, &["--version"], "Required to clone the OpenClaw runtime repository"),
        probe_command("python3", true, &["--version"], "Required for Python-based setup and LiteLLM"),
        probe_command("pip3", true, &["--version"], "Required to install LiteLLM and Python dependencies"),
        probe_command("node", true, &["--version"], "Required by the OpenClaw setup app and JS tooling"),
        probe_command("npm", true, &["--version"], "Required for frontend build tooling"),
        probe_command("brew", false, &["--version"], "Recommended for dependency installation on macOS"),
        probe_command("curl", true, &["--version"], "Required for provider probing and health checks"),
        probe_command("launchctl", true, &["help"], "Required to manage LaunchAgents on macOS"),
    ];

    Ok(DoctorCheckResult {
        platform: env::consts::OS.to_string(),
        architecture: env::consts::ARCH.to_string(),
        checks,
    })
}

#[command]
pub fn clone_openclaw_repo(request: CloneRepoRequest) -> Result<CloneRepoResult, String> {
    let target_dir = expand_home(&request.target_dir)?;
    let branch = request
        .branch
        .as_ref()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty());

    if let Some(parent) = target_dir.parent() {
        fs::create_dir_all(parent).map_err(|error| format!("failed to create target parent directory: {error}"))?;
    }

    let status = if target_dir.join(".git").exists() {
        run_git(["fetch", "--all"], &target_dir)?;
        if let Some(branch_name) = branch.as_deref() {
            run_git(["checkout", branch_name], &target_dir)?;
            run_git(["pull", "--ff-only", "origin", branch_name], &target_dir)?;
        } else {
            run_git(["pull", "--ff-only"], &target_dir)?;
        }
        "updated".to_string()
    } else {
        let target_dir_str = target_dir
            .to_str()
            .ok_or_else(|| "target directory contains invalid UTF-8".to_string())?;

        if let Some(branch_name) = branch.as_deref() {
            run_git_global([
                "clone",
                "--branch",
                branch_name,
                "--single-branch",
                request.repo_url.as_str(),
                target_dir_str,
            ])?;
        } else {
            run_git_global(["clone", request.repo_url.as_str(), target_dir_str])?;
        }
        "cloned".to_string()
    };

    let head_ref = git_output(["rev-parse", "--short", "HEAD"], &target_dir)
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty());

    Ok(CloneRepoResult {
        target_dir: target_dir.display().to_string(),
        branch,
        status,
        head_ref,
    })
}

#[command]
pub fn render_prod_mac_config(request: RenderConfigRequest) -> Result<RenderConfigResult, String> {
    let install_root = expand_home(&request.install_root)?;
    let control_plane_dir = expand_home(&request.control_plane_dir)?;
    let runtime_repo_dir = expand_home(&request.runtime_repo_dir)?;

    let app_dir = install_root.join("app");
    let config_dir = install_root.join("config/prod-mac");
    let state_dir = install_root.join("state/openclaw");
    let memory_dir = install_root.join("state/memory");
    let logs_dir = install_root.join("logs");
    let launch_agents_dir = install_root.join("launch-agents");
    let scripts_dir = install_root.join("app/scripts");
    let workspace_dir = install_root.join("workspace");
    let workspace_memory_dir = workspace_dir.join("memory");

    for dir in [
        &app_dir,
        &config_dir,
        &state_dir,
        &memory_dir,
        &logs_dir,
        &launch_agents_dir,
        &scripts_dir,
        &workspace_dir,
        &workspace_memory_dir,
    ] {
        fs::create_dir_all(dir).map_err(|error| format!("failed to create {}: {error}", dir.display()))?;
    }

    let env_path = config_dir.join(".env");
    let litellm_config_path = config_dir.join("litellm.yaml");
    let openclaw_config_path = config_dir.join("openclaw.jsonc");
    let litellm_plist_path = launch_agents_dir.join("ai.openclaw.litellm.plist");
    let runtime_plist_path = launch_agents_dir.join("ai.openclaw.runtime.plist");
    let run_litellm_script = scripts_dir.join("run-litellm.sh");
    let run_openclaw_script = scripts_dir.join("run-openclaw.sh");
    let memory_md_path = workspace_dir.join("MEMORY.md");
    let agents_md_path = workspace_dir.join("AGENTS.md");

    let mut values = HashMap::new();
    values.insert("OPENCLAW_RUNTIME_DIR", runtime_repo_dir.display().to_string());
    values.insert("OPENCLAW_CONTROL_PLANE_DIR", control_plane_dir.display().to_string());
    values.insert("OPENCLAW_CONFIG_PATH", openclaw_config_path.display().to_string());
    values.insert("OPENCLAW_STATE_DIR", state_dir.display().to_string());
    values.insert("OPENCLAW_WORKSPACE_DIR", workspace_dir.display().to_string());
    values.insert("LITELLM_CONFIG_PATH", litellm_config_path.display().to_string());
    values.insert("LITELLM_MASTER_KEY", "sk-openclaw-prod-mac".to_string());
    values.insert("GEMINI_API_KEY", request.provider_keys.gemini.clone());
    values.insert("MINIMAX_API_KEY", request.provider_keys.minimax.clone());
    values.insert("DASHSCOPE_API_KEY", request.provider_keys.dashscope.clone());
    values.insert("OPENROUTER_API_KEY", request.provider_keys.openrouter.clone());
    values.insert("SILICONFLOW_API_KEY", request.provider_keys.siliconflow.clone());
    values.insert("TELEGRAM_BOT_TOKEN", request.channels.telegram_bot_token.clone());
    values.insert("FEISHU_APP_ID", request.channels.feishu_app_id.clone());
    values.insert("FEISHU_APP_SECRET", request.channels.feishu_app_secret.clone());
    values.insert(
        "FEISHU_VERIFICATION_TOKEN",
        request.channels.feishu_verification_token.clone(),
    );
    values.insert("FEISHU_ENCRYPT_KEY", request.channels.feishu_encrypt_key.clone());
    values.insert(
        "WHATSAPP_ACCOUNT_NAME",
        request.channels.whatsapp_account_name.clone(),
    );
    values.insert("MEM0_API_KEY", request.memory.mem0_api_key.clone());
    values.insert("MEM0_API_BASE", request.memory.mem0_api_base.clone());
    values.insert("OLLAMA_HOST", request.memory.ollama_host.clone());
    values.insert("EMBEDDING_MODEL", request.memory.embedding_model.clone());
    values.insert("FEISHU_ENABLED", bool_literal(!request.channels.feishu_app_id.trim().is_empty()));
    values.insert(
        "TELEGRAM_ENABLED",
        bool_literal(!request.channels.telegram_bot_token.trim().is_empty()),
    );
    values.insert("DASHSCOPE_FAST_MODEL", "qwen-flash".to_string());
    values.insert("DASHSCOPE_BALANCED_MODEL", "qwen-plus".to_string());
    values.insert("DASHSCOPE_CODE_MODEL", "qwen3-coder-plus".to_string());
    values.insert("GEMINI_FAST_MODEL", "gemini-3-flash-preview".to_string());
    values.insert("GEMINI_DEEP_MODEL", "gemini-3-pro-preview".to_string());
    values.insert("SHELL_PATH", "/bin/zsh".to_string());
    values.insert("ENV_PATH", env_path.display().to_string());
    values.insert("WORKING_DIR", runtime_repo_dir.display().to_string());
    values.insert("RUN_LITELLM_SCRIPT", run_litellm_script.display().to_string());
    values.insert("RUN_OPENCLAW_SCRIPT", run_openclaw_script.display().to_string());
    values.insert(
        "STDOUT_PATH",
        logs_dir.join("service.stdout.log").display().to_string(),
    );
    values.insert(
        "STDERR_PATH",
        logs_dir.join("service.stderr.log").display().to_string(),
    );
    values.insert(
        "RUN_AT_LOAD",
        if request.launch_at_login { "true" } else { "false" }.to_string(),
    );

    write_template("templates/prod-mac.env.tmpl", &env_path, &values)?;
    write_template(
        "templates/openclaw.prod-mac.jsonc.tmpl",
        &openclaw_config_path,
        &values,
    )?;
    write_template(
        "templates/litellm.prod-mac.yaml.tmpl",
        &litellm_config_path,
        &values,
    )?;
    write_template(
        "templates/ai.openclaw.litellm.plist.tmpl",
        &litellm_plist_path,
        &values,
    )?;
    write_template(
        "templates/ai.openclaw.runtime.plist.tmpl",
        &runtime_plist_path,
        &values,
    )?;
    write_template("templates/MEMORY.md.tmpl", &memory_md_path, &values)?;
    write_template("templates/AGENTS.md.tmpl", &agents_md_path, &values)?;

    let generated_files = vec![
        RenderedFile {
            path: env_path.display().to_string(),
            kind: "env".to_string(),
        },
        RenderedFile {
            path: openclaw_config_path.display().to_string(),
            kind: "openclaw-config".to_string(),
        },
        RenderedFile {
            path: litellm_config_path.display().to_string(),
            kind: "litellm-config".to_string(),
        },
        RenderedFile {
            path: litellm_plist_path.display().to_string(),
            kind: "launch-agent".to_string(),
        },
        RenderedFile {
            path: runtime_plist_path.display().to_string(),
            kind: "launch-agent".to_string(),
        },
        RenderedFile {
            path: memory_md_path.display().to_string(),
            kind: "workspace-memory".to_string(),
        },
        RenderedFile {
            path: agents_md_path.display().to_string(),
            kind: "workspace-agents".to_string(),
        },
    ];

    Ok(RenderConfigResult {
        profile: "prod/mac".to_string(),
        generated_files,
    })
}

#[command]
pub fn smoke_check_prod_mac(request: SmokeCheckRequest) -> Result<SmokeCheckResult, String> {
    let install_root = expand_home(&request.install_root)?;
    let config_dir = install_root.join("config/prod-mac");
    let runtime_repo_dir = install_root.join("app/openclaw-runtime");
    let env_path = config_dir.join(".env");
    let litellm_config_path = config_dir.join("litellm.yaml");
    let openclaw_config_path = config_dir.join("openclaw.jsonc");
    let litellm_plist_path = install_root.join("launch-agents/ai.openclaw.litellm.plist");
    let runtime_plist_path = install_root.join("launch-agents/ai.openclaw.runtime.plist");

    let mut checks = vec![
        file_exists_check("prod/mac env", &env_path),
        file_exists_check("LiteLLM config", &litellm_config_path),
        file_exists_check("OpenClaw config", &openclaw_config_path),
        file_exists_check("LiteLLM LaunchAgent", &litellm_plist_path),
        file_exists_check("Runtime LaunchAgent", &runtime_plist_path),
    ];

    let readiness_url = "http://127.0.0.1:4000/health/readiness";
    checks.push(http_check("LiteLLM readiness", readiness_url));
    if runtime_repo_dir.join("package.json").exists() {
        checks.push(repo_command_check(
            "OpenClaw doctor",
            &runtime_repo_dir,
            &["pnpm", "openclaw", "doctor"],
        ));
        checks.push(repo_command_check(
            "OpenClaw gateway status",
            &runtime_repo_dir,
            &["pnpm", "openclaw", "gateway", "status"],
        ));
    }

    Ok(SmokeCheckResult { checks })
}

#[command]
pub fn provision_litellm_prod_mac(request: ProvisionLiteLlmRequest) -> Result<ProvisionLiteLlmResult, String> {
    let install_root = expand_home(&request.install_root)?;
    let config_dir = install_root.join("config/prod-mac");
    let scripts_dir = install_root.join("app/scripts");
    let logs_dir = install_root.join("logs");
    let env_path = config_dir.join(".env");
    let litellm_config_path = config_dir.join("litellm.yaml");
    let openclaw_config_path = config_dir.join("openclaw.jsonc");
    let run_litellm_script = scripts_dir.join("run-litellm.sh");
    let run_openclaw_script = scripts_dir.join("run-openclaw.sh");

    fs::create_dir_all(&scripts_dir)
        .map_err(|error| format!("failed to create {}: {error}", scripts_dir.display()))?;
    fs::create_dir_all(&logs_dir).map_err(|error| format!("failed to create {}: {error}", logs_dir.display()))?;

    let mut values = HashMap::new();
    values.insert("ENV_PATH", env_path.display().to_string());
    values.insert("LITELLM_CONFIG_PATH", litellm_config_path.display().to_string());
    values.insert("OPENCLAW_CONFIG_PATH", openclaw_config_path.display().to_string());
    values.insert("OPENCLAW_RUNTIME_DIR", install_root.join("app/openclaw-runtime").display().to_string());
    values.insert("LOGS_DIR", logs_dir.display().to_string());

    write_template("templates/run-litellm.sh.tmpl", &run_litellm_script, &values)?;
    write_template("templates/run-openclaw.sh.tmpl", &run_openclaw_script, &values)?;
    ensure_executable(&run_litellm_script)?;
    ensure_executable(&run_openclaw_script)?;

    let mut steps = vec![
        ProvisionStep {
            name: "render-run-litellm-script".to_string(),
            ok: true,
            detail: run_litellm_script.display().to_string(),
        },
        ProvisionStep {
            name: "render-run-openclaw-script".to_string(),
            ok: true,
            detail: run_openclaw_script.display().to_string(),
        },
    ];

    let install_output = Command::new("python3")
        .args(["-m", "pip", "install", "--upgrade", "litellm[proxy]", "pyyaml"])
        .output();

    match install_output {
        Ok(output) if output.status.success() => {
            steps.push(ProvisionStep {
                name: "pip-install-litellm".to_string(),
                ok: true,
                detail: "Installed litellm[proxy] and pyyaml".to_string(),
            });
        }
        Ok(output) => {
            steps.push(ProvisionStep {
                name: "pip-install-litellm".to_string(),
                ok: false,
                detail: stderr_or_stdout(&output.stderr, &output.stdout),
            });
        }
        Err(error) => {
            steps.push(ProvisionStep {
                name: "pip-install-litellm".to_string(),
                ok: false,
                detail: format!("failed to invoke pip install: {error}"),
            });
        }
    }

    Ok(ProvisionLiteLlmResult { steps })
}

#[command]
pub fn provision_openclaw_runtime_prod_mac(
    request: ProvisionOpenClawRuntimeRequest,
) -> Result<ProvisionLiteLlmResult, String> {
    let runtime_repo_dir = expand_home(&request.runtime_repo_dir)?;
    if !runtime_repo_dir.join("package.json").exists() {
        return Err(format!(
            "OpenClaw runtime repo does not look valid: {}",
            runtime_repo_dir.display()
        ));
    }

    let mut steps = Vec::new();
    for (name, args, detail) in [
        ("pnpm-install", vec!["install"], "Install JS dependencies"),
        ("pnpm-ui-build", vec!["ui:build"], "Build Control UI assets"),
        ("pnpm-build", vec!["build"], "Build OpenClaw distribution"),
        ("pnpm-link-global", vec!["link", "--global"], "Expose the openclaw CLI globally"),
    ] {
        let output = Command::new("pnpm")
            .args(args)
            .current_dir(&runtime_repo_dir)
            .output();

        match output {
            Ok(output) if output.status.success() => steps.push(ProvisionStep {
                name: name.to_string(),
                ok: true,
                detail: detail.to_string(),
            }),
            Ok(output) => steps.push(ProvisionStep {
                name: name.to_string(),
                ok: false,
                detail: stderr_or_stdout(&output.stderr, &output.stdout),
            }),
            Err(error) => steps.push(ProvisionStep {
                name: name.to_string(),
                ok: false,
                detail: format!("failed to invoke pnpm: {error}"),
            }),
        }
    }

    Ok(ProvisionLiteLlmResult { steps })
}

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
        .map_err(|error| format!("failed to run launchctl print: {error}"))?;

    Ok(LaunchAgentCommandResult {
        service: request.service,
        action: "status".to_string(),
        ok: output.status.success(),
        detail: stderr_or_stdout(&output.stderr, &output.stdout),
    })
}

fn probe_command(binary: &str, required: bool, args: &[&str], detail: &str) -> DoctorCheckItem {
    match Command::new(binary).args(args).output() {
        Ok(output) if output.status.success() => {
            let version = first_non_empty_line(&output.stdout)
                .or_else(|| first_non_empty_line(&output.stderr))
                .map(|line| line.to_string());

            DoctorCheckItem {
                name: binary.to_string(),
                required,
                found: true,
                version,
                detail: detail.to_string(),
            }
        }
        Ok(output) => DoctorCheckItem {
            name: binary.to_string(),
            required,
            found: false,
            version: None,
            detail: format!(
                "{detail}. Command returned status {}",
                output.status.code().unwrap_or_default()
            ),
        },
        Err(error) => DoctorCheckItem {
            name: binary.to_string(),
            required,
            found: false,
            version: None,
            detail: format!("{detail}. {error}"),
        },
    }
}

fn first_non_empty_line(bytes: &[u8]) -> Option<&str> {
    let text = std::str::from_utf8(bytes).ok()?;
    text.lines().find(|line| !line.trim().is_empty())
}

fn expand_home(raw: &str) -> Result<PathBuf, String> {
    if raw == "~" || raw.starts_with("~/") {
        let home = env::var("HOME").map_err(|error| format!("failed to resolve HOME: {error}"))?;
        let suffix = raw.strip_prefix("~/").unwrap_or("");
        return Ok(Path::new(&home).join(suffix));
    }

    Ok(PathBuf::from(raw))
}

fn write_template(relative_path: &str, destination: &Path, values: &HashMap<&str, String>) -> Result<(), String> {
    let template_path = Path::new(env!("CARGO_MANIFEST_DIR")).join(relative_path);
    let mut content = fs::read_to_string(&template_path)
        .map_err(|error| format!("failed to read template {}: {error}", template_path.display()))?;

    for (key, value) in values {
        let token = format!("{{{{{key}}}}}");
        content = content.replace(&token, value);
    }

    fs::write(destination, content)
        .map_err(|error| format!("failed to write {}: {error}", destination.display()))
}

fn ensure_executable(path: &Path) -> Result<(), String> {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = fs::metadata(path)
            .map_err(|error| format!("failed to read metadata for {}: {error}", path.display()))?
            .permissions();
        perms.set_mode(0o755);
        fs::set_permissions(path, perms)
            .map_err(|error| format!("failed to set executable permission on {}: {error}", path.display()))
    }

    #[cfg(not(unix))]
    {
        let _ = path;
        Ok(())
    }
}

fn bool_literal(value: bool) -> String {
    if value {
        "true".to_string()
    } else {
        "false".to_string()
    }
}

fn file_exists_check(name: &str, path: &Path) -> SmokeCheckItem {
    SmokeCheckItem {
        name: name.to_string(),
        ok: path.exists(),
        detail: path.display().to_string(),
    }
}

fn http_check(name: &str, url: &str) -> SmokeCheckItem {
    match Command::new("curl").args(["-sS", "-o", "/dev/null", "-w", "%{http_code}", url]).output() {
        Ok(output) if output.status.success() => {
            let code = String::from_utf8_lossy(&output.stdout).trim().to_string();
            let ok = code == "200";
            SmokeCheckItem {
                name: name.to_string(),
                ok,
                detail: format!("GET {url} -> {code}"),
            }
        }
        Ok(output) => SmokeCheckItem {
            name: name.to_string(),
            ok: false,
            detail: format!(
                "curl failed with status {}",
                output.status.code().unwrap_or_default()
            ),
        },
        Err(error) => SmokeCheckItem {
            name: name.to_string(),
            ok: false,
            detail: format!("failed to run curl: {error}"),
        },
    }
}

fn repo_command_check(name: &str, workdir: &Path, command: &[&str]) -> SmokeCheckItem {
    let mut cmd = Command::new(command[0]);
    cmd.args(&command[1..]).current_dir(workdir);

    match cmd.output() {
        Ok(output) => SmokeCheckItem {
            name: name.to_string(),
            ok: output.status.success(),
            detail: stderr_or_stdout(&output.stderr, &output.stdout),
        },
        Err(error) => SmokeCheckItem {
            name: name.to_string(),
            ok: false,
            detail: format!("failed to run {}: {error}", command.join(" ")),
        },
    }
}

fn run_launchctl(action: &str, request: LaunchAgentCommandRequest) -> Result<LaunchAgentCommandResult, String> {
    let install_root = expand_home(&request.install_root)?;
    let plist_path = launch_agent_plist_path(&install_root, &request.service)?;
    let plist_path_str = plist_path
        .to_str()
        .ok_or_else(|| "LaunchAgent path contains invalid UTF-8".to_string())?;

    let output = Command::new("launchctl")
        .args([action, plist_path_str])
        .output()
        .map_err(|error| format!("failed to run launchctl {action}: {error}"))?;

    Ok(LaunchAgentCommandResult {
        service: request.service,
        action: action.to_string(),
        ok: output.status.success(),
        detail: stderr_or_stdout(&output.stderr, &output.stdout),
    })
}

fn launch_agent_plist_path(install_root: &Path, service: &str) -> Result<PathBuf, String> {
    let file_name = match service {
        "litellm" => "ai.openclaw.litellm.plist",
        "runtime" => "ai.openclaw.runtime.plist",
        _ => return Err(format!("unsupported service: {service}")),
    };

    Ok(install_root.join("launch-agents").join(file_name))
}

fn launch_agent_label(service: &str) -> Result<&'static str, String> {
    match service {
        "litellm" => Ok("ai.openclaw.litellm"),
        "runtime" => Ok("ai.openclaw.runtime"),
        _ => Err(format!("unsupported service: {service}")),
    }
}

fn uid_string() -> Result<String, String> {
    let output = Command::new("id")
        .arg("-u")
        .output()
        .map_err(|error| format!("failed to run id -u: {error}"))?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
    } else {
        Err(stderr_or_stdout(&output.stderr, &output.stdout))
    }
}

fn run_git<const N: usize>(args: [&str; N], workdir: &Path) -> Result<(), String> {
    let output = Command::new("git")
        .args(args)
        .current_dir(workdir)
        .output()
        .map_err(|error| format!("failed to run git {:?}: {error}", args))?;

    if output.status.success() {
        Ok(())
    } else {
        Err(format!(
            "git {:?} failed: {}",
            args,
            stderr_or_stdout(&output.stderr, &output.stdout)
        ))
    }
}

fn run_git_global<const N: usize>(args: [&str; N]) -> Result<(), String> {
    let output = Command::new("git")
        .args(args)
        .output()
        .map_err(|error| format!("failed to run git {:?}: {error}", args))?;

    if output.status.success() {
        Ok(())
    } else {
        Err(format!(
            "git {:?} failed: {}",
            args,
            stderr_or_stdout(&output.stderr, &output.stdout)
        ))
    }
}

fn git_output<const N: usize>(args: [&str; N], workdir: &Path) -> Result<String, String> {
    let output = Command::new("git")
        .args(args)
        .current_dir(workdir)
        .output()
        .map_err(|error| format!("failed to run git {:?}: {error}", args))?;

    if output.status.success() {
        String::from_utf8(output.stdout).map_err(|error| format!("git output was not UTF-8: {error}"))
    } else {
        Err(format!(
            "git {:?} failed: {}",
            args,
            stderr_or_stdout(&output.stderr, &output.stdout)
        ))
    }
}

fn stderr_or_stdout(stderr: &[u8], stdout: &[u8]) -> String {
    let stderr_text = String::from_utf8_lossy(stderr).trim().to_string();
    if !stderr_text.is_empty() {
        return stderr_text;
    }

    String::from_utf8_lossy(stdout).trim().to_string()
}
