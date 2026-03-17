import { useMemo, useState, useEffect } from "react";
import { listen } from "@tauri-apps/api/event";
import {
  installOpenclaw,
  launchAgentAction,
  provisionLiteLlmProdMac,
  renderProdMacConfig,
  runDoctorCheck,
  runProdMacSmokeCheck,
} from "./lib/tauri";
import type {
  DoctorCheckResult,
  InstallOpenClawResult,
  InstallStage,
  InstallStepId,
  InstallerForm,
  LaunchAgentCommandResult,
  ProvisionLiteLlmResult,
  RenderConfigResult,
  SmokeCheckResult,
} from "./types";

const steps: Array<{ id: InstallStepId; title: string; description: string; goal: string }> = [
  { id: "welcome",     title: "开始安装",   description: "确认安装目录，了解整个安装流程。",           goal: "先知道会安装什么，以及文件会写到哪里。" },
  { id: "environment", title: "环境检查",   description: "检查本机是否具备所有必要工具。",             goal: "提前发现缺失的工具，避免安装到一半失败。" },
  { id: "install",     title: "安装程序",   description: "通过 npm 安装 OpenClaw 和 LiteLLM。",       goal: "把核心程序安装到本机。" },
  { id: "providers",   title: "模型与记忆", description: "填写 AI 模型的密钥和记忆系统地址。",         goal: "让 OpenClaw 能真正调用 AI 模型和记忆服务。" },
  { id: "channels",    title: "消息渠道",   description: "配置飞书或 Telegram 作为消息入口。",         goal: "至少打通一个你真正要用的消息渠道。" },
  { id: "launchAgent", title: "开机自启",   description: "决定是否在登录后自动启动服务。",             goal: "让服务持续可用，不用每次手工启动。" },
  { id: "review",      title: "执行安装",   description: "一键完成配置生成、服务注册和安装验证。",     goal: "把前面填写的信息真正落地为可运行的本地服务。" },
];

const initialForm: InstallerForm = {
  installRoot: "~/Library/Application Support/OpenClaw",
  openclaw_version: "",
  providerKeys: { gemini: "", minimax: "", dashscope: "", openrouter: "", siliconflow: "" },
  channels: { feishuAppId: "", feishuAppSecret: "", feishuVerificationToken: "", feishuEncryptKey: "", telegramBotToken: "", whatsappAccountName: "" },
  memory: { mem0ApiKey: "", mem0ApiBase: "", ollamaHost: "http://127.0.0.1:11434", embeddingModel: "nomic-embed-text" },
  launchAtLogin: true,
};

const initialStages: InstallStage[] = [
  { id: "doctor",      label: "环境检查",        status: "idle", detail: "尚未执行" },
  { id: "openclaw",    label: "安装 OpenClaw",   status: "idle", detail: "尚未安装" },
  { id: "litellm",     label: "安装 LiteLLM",    status: "idle", detail: "尚未安装" },
  { id: "config",      label: "生成配置",         status: "idle", detail: "尚未生成" },
  { id: "launchAgent", label: "后台服务",         status: "idle", detail: "尚未注册" },
  { id: "smoke",       label: "安装验证",         status: "idle", detail: "尚未执行" },
];

const toolLabels: Record<string, string> = {
  node:      "Node.js（运行时）",
  npm:       "npm（包管理器）",
  python3:   "Python 3",
  pip3:      "pip3（Python 包管理器）",
  curl:      "curl（网络工具）",
  launchctl: "launchctl（macOS 服务管理）",
  brew:      "Homebrew（推荐，可选）",
};

const stepLabels: Record<string, string> = {
  "npm-install-openclaw":  "npm install -g openclaw@latest",
  "verify-openclaw-cli":   "验证 openclaw 命令",
  "pip-install-litellm":   "pip install litellm[proxy]",
};

export function App() {
  const [activeStep, setActiveStep] = useState<InstallStepId>("welcome");
  const [form, setForm] = useState<InstallerForm>(initialForm);
  const [doctorResult, setDoctorResult] = useState<DoctorCheckResult | null>(null);
  const [installResult, setInstallResult] = useState<InstallOpenClawResult | null>(null);
  const [renderResult, setRenderResult] = useState<RenderConfigResult | null>(null);
  const [smokeResult, setSmokeResult] = useState<SmokeCheckResult | null>(null);
  const [litellmResult, setLitellmResult] = useState<ProvisionLiteLlmResult | null>(null);
  const [serviceEvents, setServiceEvents] = useState<LaunchAgentCommandResult[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [installRunning, setInstallRunning] = useState(false);
  const [stages, setStages] = useState<InstallStage[]>(initialStages);
  const [installLogs, setInstallLogs] = useState<string[]>([]);

  const stepIndex = steps.findIndex((s) => s.id === activeStep);
  const currentStep = steps[stepIndex];
  const completedStages = stages.filter((s) => s.status === "succeeded").length;
  const progress = Math.round((completedStages / stages.length) * 100);

  // 监听安装进度事件
  useEffect(() => {
    const unlisten = listen<string>("install_progress", (event) => {
      setInstallLogs((logs) => [...logs, event.payload].slice(-100)); // 保留最近 100 行
    });
    return () => { unlisten.then((fn) => fn()); };
  }, []);

  const summary = useMemo(() => [
    ["安装目录", form.installRoot],
    ["OpenClaw", installResult
      ? installResult.steps.every((s) => s.ok) ? "安装成功" : "安装有问题"
      : "尚未安装"],
    ["LiteLLM", litellmResult
      ? litellmResult.steps.every((s) => s.ok) ? "安装成功" : "安装有问题"
      : "尚未安装"],
    ["配置文件", renderResult ? `已生成 ${renderResult.generatedFiles.length} 个文件` : "尚未生成"],
    ["安装验证", smokeResult
      ? `${smokeResult.checks.filter((s) => s.ok).length}/${smokeResult.checks.length} 项通过`
      : "尚未执行"],
  ], [form.installRoot, installResult, litellmResult, renderResult, smokeResult]);

  function updateStage(id: string, patch: Partial<InstallStage>) {
    setStages((items) => items.map((item) => (item.id === id ? { ...item, ...patch } : item)));
  }

  async function handleDoctorCheck() {
    setBusy(true); setError(null);
    updateStage("doctor", { status: "running", detail: "正在检查本机工具…" });
    try {
      const result = await runDoctorCheck();
      setDoctorResult(result);
      const missing = result.checks.filter((c) => c.required && !c.found).length;
      updateStage("doctor", {
        status: missing === 0 ? "succeeded" : "failed",
        detail: missing === 0 ? "所有必要工具已就绪" : `还缺少 ${missing} 个必要工具，请先安装后再继续`,
      });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      setError(msg); updateStage("doctor", { status: "failed", detail: msg });
    } finally { setBusy(false); }
  }

  async function handleInstallOpenclaw() {
    setBusy(true); setError(null); setInstallLogs([]);
    updateStage("openclaw", { status: "running", detail: "正在执行 npm install -g openclaw@latest，请稍候…" });
    try {
      const result = await installOpenclaw(form.openclaw_version);
      setInstallResult(result);
      const failed = result.steps.filter((s) => !s.ok).length;
      updateStage("openclaw", {
        status: failed === 0 ? "succeeded" : "failed",
        detail: failed === 0 ? "OpenClaw 安装成功" : `有 ${failed} 个步骤失败`,
      });
      if (failed > 0) {
        setError("OpenClaw 安装失败，请查看详情。");
      } else {
        setInstallLogs((logs) => [...logs, "", "✓ OpenClaw 安装完成！可以继续安装 LiteLLM。"]);
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      setError(msg); updateStage("openclaw", { status: "failed", detail: msg });
    } finally { setBusy(false); }
  }

  async function handleProvisionLiteLlm() {
    setBusy(true); setError(null); setInstallLogs([]);
    updateStage("litellm", { status: "running", detail: "正在执行 pip install litellm[proxy]，这可能需要几分钟…" });
    try {
      const result = await provisionLiteLlmProdMac(form.installRoot);
      setLitellmResult(result);
      const failed = result.steps.filter((s) => !s.ok).length;
      updateStage("litellm", {
        status: failed === 0 ? "succeeded" : "failed",
        detail: failed === 0 ? "LiteLLM 安装成功" : `有 ${failed} 个步骤失败`,
      });
      if (failed > 0) {
        setError("LiteLLM 安装失败，请查看详情。");
      } else {
        setInstallLogs((logs) => [...logs, "", "✓ LiteLLM 安装完成！现在可以进入下一步配置模型密钥。"]);
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      setError(msg); updateStage("litellm", { status: "failed", detail: msg });
    } finally { setBusy(false); }
  }

  async function handleRenderConfig() {
    setBusy(true); setError(null);
    updateStage("config", { status: "running", detail: "正在生成配置文件…" });
    updateStage("launchAgent", { status: "running", detail: "正在生成后台服务配置…" });
    try {
      const result = await renderProdMacConfig(form);
      setRenderResult(result);
      updateStage("config", { status: "succeeded", detail: `已生成 ${result.generatedFiles.length} 个配置文件` });
      updateStage("launchAgent", { status: "succeeded", detail: "后台服务配置已生成" });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      setError(msg);
      updateStage("config", { status: "failed", detail: msg });
      updateStage("launchAgent", { status: "failed", detail: msg });
    } finally { setBusy(false); }
  }

  async function handleSmokeCheck() {
    setBusy(true); setError(null);
    updateStage("smoke", { status: "running", detail: "正在验证安装结果…" });
    try {
      const result = await runProdMacSmokeCheck(form.installRoot);
      setSmokeResult(result);
      const failed = result.checks.filter((s) => !s.ok).length;
      updateStage("smoke", {
        status: failed === 0 ? "succeeded" : "failed",
        detail: failed === 0 ? "所有检查通过，安装成功" : `有 ${failed} 项检查未通过`,
      });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      setError(msg); updateStage("smoke", { status: "failed", detail: msg });
    } finally { setBusy(false); }
  }

  async function handleOneClickInstall() {
    setInstallRunning(true); setBusy(true); setError(null); setInstallLogs([]);
    try {
      // 1. 安装 OpenClaw
      updateStage("openclaw", { status: "running", detail: "正在安装 OpenClaw…" });
      const ocResult = await installOpenclaw(form.openclaw_version);
      setInstallResult(ocResult);
      const ocFailed = ocResult.steps.filter((s) => !s.ok).length;
      updateStage("openclaw", {
        status: ocFailed === 0 ? "succeeded" : "failed",
        detail: ocFailed === 0 ? "OpenClaw 安装成功" : `有 ${ocFailed} 个步骤失败`,
      });
      if (ocFailed > 0) { setError("OpenClaw 安装失败，请查看详情后重试。"); setBusy(false); setInstallRunning(false); return; }

      // 显示完成提示，等待用户看到结果
      setInstallLogs((logs) => [...logs, "", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", "✓ 步骤 1/4 完成：OpenClaw 安装成功", "准备进入步骤 2/4：安装 LiteLLM...", ""]);
      await new Promise((resolve) => setTimeout(resolve, 3000));
      setInstallLogs([]);

      // 2. 安装 LiteLLM
      updateStage("litellm", { status: "running", detail: "正在安装 LiteLLM，这可能需要几分钟…" });
      const llmResult = await provisionLiteLlmProdMac(form.installRoot);
      setLitellmResult(llmResult);
      const llmFailed = llmResult.steps.filter((s) => !s.ok).length;
      updateStage("litellm", {
        status: llmFailed === 0 ? "succeeded" : "failed",
        detail: llmFailed === 0 ? "LiteLLM 安装成功" : `有 ${llmFailed} 个步骤失败`,
      });
      if (llmFailed > 0) { setError("LiteLLM 安装失败，请查看详情后重试。"); setBusy(false); setInstallRunning(false); return; }

      setInstallLogs((logs) => [...logs, "", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", "✓ 步骤 2/4 完成：LiteLLM 安装成功", "准备进入步骤 3/4：生成配置文件...", ""]);
      await new Promise((resolve) => setTimeout(resolve, 3000));
      setInstallLogs([]);

      // 3. 生成配置
      updateStage("config", { status: "running", detail: "正在生成配置文件…" });
      updateStage("launchAgent", { status: "running", detail: "正在生成后台服务配置…" });
      const cfgResult = await renderProdMacConfig(form);
      setRenderResult(cfgResult);
      updateStage("config", { status: "succeeded", detail: `已生成 ${cfgResult.generatedFiles.length} 个配置文件` });
      updateStage("launchAgent", { status: "succeeded", detail: "后台服务配置已生成" });

      setInstallLogs((logs) => [...logs, "✓ 步骤 3/4 完成：配置文件生成成功", `已生成 ${cfgResult.generatedFiles.length} 个配置文件`, "准备进入步骤 4/4：验证安装...", ""]);
      await new Promise((resolve) => setTimeout(resolve, 2000));

      // 4. 验证
      updateStage("smoke", { status: "running", detail: "正在验证安装结果…" });
      const smokeRes = await runProdMacSmokeCheck(form.installRoot);
      setSmokeResult(smokeRes);
      const smokeFailed = smokeRes.checks.filter((s) => !s.ok).length;
      updateStage("smoke", {
        status: smokeFailed === 0 ? "succeeded" : "failed",
        detail: smokeFailed === 0 ? "所有检查通过，安装成功" : `有 ${smokeFailed} 项检查未通过`,
      });

      if (smokeFailed === 0) {
        setInstallLogs((logs) => [...logs, "", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", "✓ 步骤 4/4 完成：安装验证通过", "🎉 所有安装步骤已完成！", "", "现在可以使用下方的「服务控制」启动 OpenClaw 服务。"]);
      } else {
        setInstallLogs((logs) => [...logs, "", "⚠ 步骤 4/4：部分验证未通过", "请查看下方详情，可能需要手动检查配置。"]);
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      setError(msg);
    } finally { setBusy(false); setInstallRunning(false); }
  }

  async function handleLaunchAgent(action: "load" | "unload" | "status", service: "litellm" | "runtime") {
    setBusy(true); setError(null);
    try {
      const result = await launchAgentAction(action, form.installRoot, service);
      setServiceEvents((items) => [result, ...items].slice(0, 8));
      updateStage("launchAgent", {
        status: result.ok ? "succeeded" : "failed",
        detail: `${service === "litellm" ? "LiteLLM" : "OpenClaw"} ${translateAction(action)} ${result.ok ? "成功" : "失败"}`,
      });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      setError(msg); updateStage("launchAgent", { status: "failed", detail: msg });
    } finally { setBusy(false); }
  }

  function nextStep() { if (stepIndex < steps.length - 1) setActiveStep(steps[stepIndex + 1].id); }
  function previousStep() { if (stepIndex > 0) setActiveStep(steps[stepIndex - 1].id); }

  return (
    <div className="shell">
      <aside className="sidebar">
        <div>
          <p className="eyebrow">OpenClaw 安装向导</p>
          <h1>macOS 一键安装</h1>
          <p className="muted">按步骤填写信息，最后在「执行安装」页一键完成部署。</p>
        </div>
        <div className="progressCard">
          <div className="progressHeader"><strong>安装进度</strong><span>{progress}%</span></div>
          <div className="progressTrack"><div className="progressValue" style={{ width: `${progress}%` }} /></div>
          <p className="muted">已完成 {completedStages} / {stages.length} 项任务</p>
        </div>
        <ol className="stepList">
          {steps.map((step, index) => (
            <li key={step.id} className={step.id === activeStep ? "step active" : "step"} onClick={() => setActiveStep(step.id)}>
              <span>{String(index + 1).padStart(2, "0")}</span>
              <div><strong>{step.title}</strong><p>{step.description}</p></div>
            </li>
          ))}
        </ol>
      </aside>

      <main className="content">
        <header className="panel hero">
          <div>
            <p className="eyebrow">步骤 {String(stepIndex + 1).padStart(2, "0")} / {steps.length}</p>
            <h2>{currentStep.title}</h2>
            <p>{currentStep.description}</p>
            <p className="heroGoal">目标：{currentStep.goal}</p>
          </div>
          <div className={`pill ${busy ? "pill-busy" : ""}`}>{busy ? "执行中…" : "待操作"}</div>
        </header>

        <section className="panel grid">
          <article className="card span-8">{renderStep()}</article>
          <aside className="card span-4">
            <h3>安装状态</h3>
            <ul className="statusList">
              {stages.map((stage) => (
                <li key={stage.id}>
                  <strong>{stage.label}</strong>
                  <span className={`status ${stage.status}`}>{translateStatus(stage.status)}</span>
                  <p>{stage.detail}</p>
                </li>
              ))}
            </ul>
          </aside>
        </section>

        <section className="panel grid compact">
          <article className="card span-12">
            <h3>安装摘要</h3>
            <dl className="summary">
              {summary.map(([label, value]) => (
                <div key={label}><dt>{label}</dt><dd>{value}</dd></div>
              ))}
            </dl>
          </article>
        </section>

        {error ? (
          <section className="panel errorPanel"><strong>出错了</strong><p>{error}</p></section>
        ) : null}

        <footer className="footer">
          <button className="secondary" onClick={previousStep} disabled={stepIndex === 0 || busy}>上一步</button>
          <button className="primary" onClick={nextStep} disabled={stepIndex === steps.length - 1 || busy}>下一步</button>
        </footer>
      </main>
    </div>
  );

  function renderStep() {
    switch (activeStep) {
      case "welcome":
        return (
          <div className="stack">
            <div className="callout">
              <strong>这个向导会帮你做什么？</strong>
              <p>自动完成 OpenClaw 本地安装：通过 npm 安装 OpenClaw、通过 pip 安装 LiteLLM（AI 模型网关）、生成配置文件、注册后台服务，最后验证一切正常。你只需要填写必要的密钥和渠道信息。</p>
            </div>
            <label>安装目录（配置文件和日志的存放位置）
              <input value={form.installRoot} onChange={(e) => setForm({ ...form, installRoot: e.target.value })} />
            </label>
            <div className="tipGrid">
              <div className="tipCard"><strong>保持默认即可</strong><p>安装器会自动创建所有子目录，无需手动操作。</p></div>
              <div className="tipCard"><strong>不影响现有文件</strong><p>配置和日志只写入你的用户目录，不会修改任何系统文件。</p></div>
            </div>
          </div>
        );

      case "environment":
        return (
          <div className="stack">
            <div className="actionHeader">
              <div>
                <h3>检查本机工具</h3>
                <p className="muted">点击「开始检查」，安装器会扫描本机是否具备所有必要工具。如有缺失，会告诉你需要安装什么。</p>
              </div>
              <button className="primary" onClick={handleDoctorCheck} disabled={busy}>开始检查</button>
            </div>
            {doctorResult ? (
              <div>
                <p className="muted">系统：{doctorResult.platform} / {doctorResult.architecture}</p>
                <ul className="statusList">
                  {doctorResult.checks.map((check) => (
                    <li key={check.name}>
                      <strong>{toolLabels[check.name] ?? check.name}{check.required ? "" : "（可选）"}</strong>
                      <span className={`status ${check.found ? "succeeded" : check.required ? "failed" : "idle"}`}>
                        {check.found ? "已安装" : "未找到"}
                      </span>
                      <p>{check.found ? (check.version ?? "已就绪") : check.required ? "请先安装此工具再继续" : "可选，不影响核心功能"}</p>
                    </li>
                  ))}
                </ul>
              </div>
            ) : (
              <div className="emptyState">
                <strong>还没有执行检查</strong>
                <p>点击右上角「开始检查」按钮，确认所有必要工具已安装。</p>
              </div>
            )}
          </div>
        );

      case "install":
        return (
          <div className="stack">
            <div className="callout">
              <strong>安装 OpenClaw 和 LiteLLM</strong>
              <p>OpenClaw 通过 npm 安装（官方推荐方式）。LiteLLM 是本地 AI 模型网关，通过 pip 安装。两者都会安装到系统全局，安装完成后即可使用。</p>
            </div>
            <div className="actionHeader">
              <div>
                <h3>OpenClaw</h3>
                <p className="muted">执行：<code>npm install -g openclaw@latest</code></p>
              </div>
              <button className="primary" onClick={handleInstallOpenclaw} disabled={busy}>安装 OpenClaw</button>
            </div>
            <label>版本（留空安装最新版）
              <input
                placeholder="latest"
                value={form.openclaw_version}
                onChange={(e) => setForm({ ...form, openclaw_version: e.target.value })}
                disabled={busy}
              />
            </label>
            {installLogs.length > 0 && (
              <div className="logBox">
                <div className="logHeader">
                  <strong>安装日志</strong>
                  <button className="secondary small" onClick={() => setInstallLogs([])}>清空</button>
                </div>
                <pre className="logContent">
                  {installLogs.map((log, i) => (
                    <div key={i}>{log}</div>
                  ))}
                </pre>
              </div>
            )}
            {installResult ? (
              <div className="resultBox">
                <strong>安装详情</strong>
                <ul className="notes">
                  {installResult.steps.map((s) => (
                    <li key={s.name}>{s.ok ? "✓" : "✗"} {stepLabels[s.name] ?? s.name}
                      {!s.ok ? <span className="errorInline"> — {s.detail}</span> : <span className="muted"> — {s.detail}</span>}
                    </li>
                  ))}
                </ul>
              </div>
            ) : null}
            <div className="actionHeader">
              <div>
                <h3>LiteLLM</h3>
                <p className="muted">执行：<code>pip3 install litellm[proxy] pyyaml</code></p>
              </div>
              <button className="secondary" onClick={handleProvisionLiteLlm} disabled={busy}>安装 LiteLLM</button>
            </div>
            {litellmResult ? (
              <div className="resultBox">
                <strong>安装详情</strong>
                <ul className="notes">
                  {litellmResult.steps.map((s) => (
                    <li key={s.name}>{s.ok ? "✓" : "✗"} {stepLabels[s.name] ?? s.name}
                      {!s.ok ? <span className="errorInline"> — {s.detail}</span> : <span className="muted"> — {s.detail}</span>}
                    </li>
                  ))}
                </ul>
              </div>
            ) : null}
          </div>
        );

      case "providers":
        return (
          <div className="stack">
            <div className="callout">
              <strong>配置 LiteLLM 支持 OpenClaw</strong>
              <p>LiteLLM 是本地 AI 模型网关，OpenClaw 通过它调用各家 AI 服务。这里填写的密钥会配置到 LiteLLM，让 OpenClaw 能够真正使用 AI 模型。至少填写一个模型密钥，推荐 DashScope（阿里云）或 Gemini。</p>
            </div>
            <div className="callout soft">
              <strong>密钥安全说明</strong>
              <p>所有密钥只保存在本机配置文件中，不会上传到任何服务器。</p>
            </div>
            <div className="fieldGrid">
              {renderMaskedInput("DashScope（阿里云）API Key", "dashscope")}
              {renderMaskedInput("Gemini API Key", "gemini")}
              {renderMaskedInput("MiniMax API Key", "minimax")}
              {renderMaskedInput("OpenRouter API Key", "openrouter")}
              {renderMaskedInput("SiliconFlow API Key", "siliconflow")}
            </div>
            <h3>记忆系统（可选）</h3>
            <p className="muted">如果不使用 Mem0 或 Ollama，保持默认值即可，不影响核心功能。</p>
            <div className="fieldGrid">
              <label>Mem0 API Key<input type="password" value={form.memory.mem0ApiKey} onChange={(e) => setForm({ ...form, memory: { ...form.memory, mem0ApiKey: e.target.value } })} /></label>
              <label>Mem0 服务地址<input value={form.memory.mem0ApiBase} onChange={(e) => setForm({ ...form, memory: { ...form.memory, mem0ApiBase: e.target.value } })} /></label>
              <label>Ollama 地址<input value={form.memory.ollamaHost} onChange={(e) => setForm({ ...form, memory: { ...form.memory, ollamaHost: e.target.value } })} /></label>
              <label>向量模型<input value={form.memory.embeddingModel} onChange={(e) => setForm({ ...form, memory: { ...form.memory, embeddingModel: e.target.value } })} /></label>
            </div>
          </div>
        );

      case "channels":
        return (
          <div className="stack">
            <div className="callout soft">
              <strong>配置消息渠道</strong>
              <p>选择你要用的消息入口，至少填写一个。飞书和 Telegram 都支持，填哪个用哪个。</p>
            </div>
            <h3>飞书</h3>
            <div className="fieldGrid">
              <label>App ID<input value={form.channels.feishuAppId} onChange={(e) => setForm({ ...form, channels: { ...form.channels, feishuAppId: e.target.value } })} /></label>
              <label>App Secret<input type="password" value={form.channels.feishuAppSecret} onChange={(e) => setForm({ ...form, channels: { ...form.channels, feishuAppSecret: e.target.value } })} /></label>
              <label>Verification Token<input value={form.channels.feishuVerificationToken} onChange={(e) => setForm({ ...form, channels: { ...form.channels, feishuVerificationToken: e.target.value } })} /></label>
              <label>Encrypt Key<input type="password" value={form.channels.feishuEncryptKey} onChange={(e) => setForm({ ...form, channels: { ...form.channels, feishuEncryptKey: e.target.value } })} /></label>
            </div>
            <h3>Telegram</h3>
            <div className="fieldGrid">
              <label>Bot Token<input type="password" value={form.channels.telegramBotToken} onChange={(e) => setForm({ ...form, channels: { ...form.channels, telegramBotToken: e.target.value } })} /></label>
            </div>
          </div>
        );

      case "launchAgent":
        return (
          <div className="stack">
            <h3>开机自动启动</h3>
            <label className="toggle">
              <input type="checkbox" checked={form.launchAtLogin} onChange={(e) => setForm({ ...form, launchAtLogin: e.target.checked })} />
              登录 macOS 后自动启动 LiteLLM 和 OpenClaw
            </label>
            <div className="tipGrid">
              <div className="tipCard"><strong>推荐开启</strong><p>开启后，每次开机 OpenClaw 会自动在后台运行，无需手动启动。</p></div>
              <div className="tipCard"><strong>随时可以修改</strong><p>在「执行安装」页可以随时手动启动、停止或查看服务状态。</p></div>
            </div>
          </div>
        );

      case "review":
        return (
          <div className="stack">
            <div className="callout">
              <strong>准备好了吗？点击下方按钮开始安装</strong>
              <p>安装器会按顺序自动完成：安装 OpenClaw → 安装 LiteLLM → 生成配置 → 验证安装。全程无需手动操作，耐心等待即可。</p>
            </div>
            
            {smokeResult && smokeResult.checks.every((c) => c.ok) ? (
              <div className="successPanel">
                <strong>🎉 安装成功！</strong>
                <p>所有安装步骤已完成，OpenClaw 已准备就绪。现在可以使用下方的「服务控制」启动服务。</p>
              </div>
            ) : null}
            
            <div className="actionBlock">
              <button className="primary installBtn" onClick={handleOneClickInstall} disabled={busy || installRunning}>
                {installRunning ? "安装中，请稍候…" : "一键安装"}
              </button>
              <p className="muted">如果某步失败，也可以单独重试：</p>
              <div className="actionGrid">
                <button className="secondary" onClick={handleInstallOpenclaw} disabled={busy}>单独：安装 OpenClaw</button>
                <button className="secondary" onClick={handleProvisionLiteLlm} disabled={busy}>单独：安装 LiteLLM</button>
                <button className="secondary" onClick={handleRenderConfig} disabled={busy}>单独：生成配置文件</button>
                <button className="secondary" onClick={handleSmokeCheck} disabled={busy}>单独：验证安装</button>
              </div>
            </div>

            {installResult ? (
              <div className="resultBox">
                <strong>OpenClaw 安装详情</strong>
                <ul className="notes">
                  {installResult.steps.map((s) => (
                    <li key={s.name}>{s.ok ? "✓" : "✗"} {stepLabels[s.name] ?? s.name}
                      {!s.ok ? <span className="errorInline"> — {s.detail}</span> : <span className="muted"> — {s.detail}</span>}
                    </li>
                  ))}
                </ul>
              </div>
            ) : null}

            {litellmResult ? (
              <div className="resultBox">
                <strong>LiteLLM 安装详情</strong>
                <ul className="notes">
                  {litellmResult.steps.map((s) => (
                    <li key={s.name}>{s.ok ? "✓" : "✗"} {stepLabels[s.name] ?? s.name}
                      {!s.ok ? <span className="errorInline"> — {s.detail}</span> : <span className="muted"> — {s.detail}</span>}
                    </li>
                  ))}
                </ul>
              </div>
            ) : null}

            {renderResult ? (
              <div className="resultBox">
                <strong>已生成的配置文件</strong>
                <ul className="notes">
                  {renderResult.generatedFiles.map((f) => <li key={f.path}><code>{f.path}</code></li>)}
                </ul>
              </div>
            ) : null}

            {smokeResult ? (
              <div className="resultBox">
                <strong>安装验证结果</strong>
                <ul className="notes">
                  {smokeResult.checks.map((c) => (
                    <li key={c.name}>{c.ok ? "✓" : "✗"} {c.name}
                      {!c.ok ? <span className="errorInline"> — {c.detail}</span> : null}
                    </li>
                  ))}
                </ul>
              </div>
            ) : null}

            <div className="resultBox">
              <strong>服务控制</strong>
              <p className="muted">安装完成后，可以在这里手动控制后台服务。</p>
              <div className="serviceGrid">
                <div>
                  <p className="serviceLabel">LiteLLM（AI 模型网关）</p>
                  <div className="toolbar wrap">
                    <button className="secondary" onClick={() => handleLaunchAgent("load", "litellm")} disabled={busy}>启动</button>
                    <button className="secondary" onClick={() => handleLaunchAgent("status", "litellm")} disabled={busy}>查看状态</button>
                    <button className="secondary" onClick={() => handleLaunchAgent("unload", "litellm")} disabled={busy}>停止</button>
                  </div>
                </div>
                <div>
                  <p className="serviceLabel">OpenClaw（主服务）</p>
                  <div className="toolbar wrap">
                    <button className="secondary" onClick={() => handleLaunchAgent("load", "runtime")} disabled={busy}>启动</button>
                    <button className="secondary" onClick={() => handleLaunchAgent("status", "runtime")} disabled={busy}>查看状态</button>
                    <button className="secondary" onClick={() => handleLaunchAgent("unload", "runtime")} disabled={busy}>停止</button>
                  </div>
                </div>
              </div>
              {serviceEvents.length > 0 ? (
                <ul className="notes">
                  {serviceEvents.map((ev, i) => (
                    <li key={`${ev.service}-${ev.action}-${i}`}>
                      {ev.ok ? "✓" : "✗"} {ev.service === "litellm" ? "LiteLLM" : "OpenClaw"} {translateAction(ev.action as "load" | "unload" | "status")} — {ev.detail || "无输出"}
                    </li>
                  ))}
                </ul>
              ) : null}
            </div>
          </div>
        );
    }
  }

  function renderMaskedInput(label: string, key: keyof InstallerForm["providerKeys"]) {
    return (
      <label key={key}>{label}
        <input type="password" value={form.providerKeys[key]}
          onChange={(e) => setForm({ ...form, providerKeys: { ...form.providerKeys, [key]: e.target.value } })} />
      </label>
    );
  }
}

function translateStatus(status: InstallStage["status"]) {
  if (status === "idle") return "未开始";
  if (status === "running") return "执行中";
  if (status === "succeeded") return "已完成";
  return "失败";
}

function translateAction(action: "load" | "unload" | "status") {
  if (action === "load") return "启动";
  if (action === "unload") return "停止";
  return "查看状态";
}
