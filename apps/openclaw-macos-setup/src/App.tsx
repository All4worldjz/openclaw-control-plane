import { useMemo, useState } from "react";
import {
  cloneOpenClawRepo,
  launchAgentAction,
  provisionOpenClawRuntime,
  provisionLiteLlmProdMac,
  renderProdMacConfig,
  runDoctorCheck,
  runProdMacSmokeCheck
} from "./lib/tauri";
import type {
  CloneRepoResult,
  DoctorCheckResult,
  InstallStage,
  InstallStepId,
  InstallerForm,
  LaunchAgentCommandResult,
  ProvisionLiteLlmResult,
  ProvisionOpenClawRuntimeResult,
  RenderConfigResult,
  SmokeCheckResult
} from "./types";

const steps: Array<{ id: InstallStepId; title: string; description: string }> = [
  {
    id: "welcome",
    title: "Welcome",
    description: "Define the macOS prod installer scope and target directory."
  },
  {
    id: "environment",
    title: "Environment",
    description: "Check required macOS dependencies before installation."
  },
  {
    id: "source",
    title: "OpenClaw Source",
    description: "Clone or update the OpenClaw runtime repository from GitHub."
  },
  {
    id: "providers",
    title: "Providers",
    description: "Collect provider keys for LiteLLM and OpenClaw runtime."
  },
  {
    id: "channels",
    title: "Channels",
    description: "Configure Feishu and Telegram, keep WhatsApp as a placeholder."
  },
  {
    id: "launchAgent",
    title: "LaunchAgent",
    description: "Prepare launch-at-login and managed background services."
  },
  {
    id: "review",
    title: "Review",
    description: "Review the prod/mac plan before wiring the rest of the installer."
  }
];

const initialForm: InstallerForm = {
  installRoot: "~/Library/Application Support/OpenClaw",
  repoUrl: "git@github.com:All4worldjz/OpenClaw.git",
  repoBranch: "main",
  providerKeys: {
    gemini: "",
    minimax: "",
    dashscope: "",
    openrouter: "",
    siliconflow: ""
  },
  channels: {
    feishuAppId: "",
    feishuAppSecret: "",
    feishuVerificationToken: "",
    feishuEncryptKey: "",
    telegramBotToken: "",
    whatsappAccountName: ""
  },
  memory: {
    mem0ApiKey: "",
    mem0ApiBase: "",
    ollamaHost: "http://127.0.0.1:11434",
    embeddingModel: "nomic-embed-text"
  },
  launchAtLogin: true
};

const initialStages: InstallStage[] = [
  { id: "doctor", label: "Environment doctor", status: "idle", detail: "Not started" },
  { id: "repo", label: "OpenClaw repository", status: "idle", detail: "Not started" },
  { id: "config", label: "prod/mac config rendering", status: "idle", detail: "Not started" },
  { id: "litellm", label: "LiteLLM provisioning", status: "idle", detail: "Config template ready; service install pending" },
  { id: "channels", label: "Channel provisioning", status: "idle", detail: "Wizard fields ready; config generation pending" },
  { id: "launchAgent", label: "LaunchAgent registration", status: "idle", detail: "Template generation pending" },
  { id: "smoke", label: "Smoke validation", status: "idle", detail: "Not started" }
];

export function App() {
  const [activeStep, setActiveStep] = useState<InstallStepId>("welcome");
  const [form, setForm] = useState<InstallerForm>(initialForm);
  const [doctorResult, setDoctorResult] = useState<DoctorCheckResult | null>(null);
  const [cloneResult, setCloneResult] = useState<CloneRepoResult | null>(null);
  const [renderResult, setRenderResult] = useState<RenderConfigResult | null>(null);
  const [smokeResult, setSmokeResult] = useState<SmokeCheckResult | null>(null);
  const [provisionResult, setProvisionResult] = useState<ProvisionLiteLlmResult | null>(null);
  const [runtimeProvisionResult, setRuntimeProvisionResult] = useState<ProvisionOpenClawRuntimeResult | null>(null);
  const [serviceEvents, setServiceEvents] = useState<LaunchAgentCommandResult[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [stages, setStages] = useState<InstallStage[]>(initialStages);
  const controlPlaneDir = "/Users/whoami2023/Documents/GitRepo/openclaw-control-plane";

  const stepIndex = steps.findIndex((step) => step.id === activeStep);
  const currentStep = steps[stepIndex];
  const canGoBack = stepIndex > 0;
  const canGoNext = stepIndex < steps.length - 1;

  const summary = useMemo(
    () => [
      ["Environment", doctorResult ? "Checked" : "Pending"],
      ["Runtime repo", cloneResult ? `${cloneResult.status} at ${cloneResult.targetDir}` : "Pending"],
      ["Config render", renderResult ? `${renderResult.generatedFiles.length} files generated` : "Pending"],
      ["Runtime build", runtimeProvisionResult ? `${runtimeProvisionResult.steps.filter((item) => item.ok).length}/${runtimeProvisionResult.steps.length} steps ok` : "Pending"],
      ["LiteLLM provision", provisionResult ? `${provisionResult.steps.filter((item) => item.ok).length}/${provisionResult.steps.length} steps ok` : "Pending"],
      ["Smoke check", smokeResult ? `${smokeResult.checks.filter((item) => item.ok).length}/${smokeResult.checks.length} passed` : "Pending"],
      ["Install target", form.installRoot],
      ["Feishu", form.channels.feishuAppId ? "Configured" : "Pending"],
      ["Telegram", form.channels.telegramBotToken ? "Configured" : "Pending"],
      ["WhatsApp", form.channels.whatsappAccountName || "Placeholder only"]
    ],
    [cloneResult, doctorResult, form, provisionResult, renderResult, runtimeProvisionResult, smokeResult]
  );

  function updateStage(id: string, patch: Partial<InstallStage>) {
    setStages((items) => items.map((item) => (item.id === id ? { ...item, ...patch } : item)));
  }

  async function handleDoctorCheck() {
    setBusy(true);
    setError(null);
    updateStage("doctor", { status: "running", detail: "Checking macOS prerequisites" });
    try {
      const result = await runDoctorCheck();
      setDoctorResult(result);
      const missingRequired = result.checks.filter((check) => check.required && !check.found).length;
      updateStage("doctor", {
        status: missingRequired === 0 ? "succeeded" : "failed",
        detail: missingRequired === 0 ? "Required tools found" : `${missingRequired} required tools missing`
      });
    } catch (cause) {
      const message = cause instanceof Error ? cause.message : String(cause);
      setError(message);
      updateStage("doctor", { status: "failed", detail: message });
    } finally {
      setBusy(false);
    }
  }

  async function handleCloneRepo() {
    setBusy(true);
    setError(null);
    updateStage("repo", { status: "running", detail: "Cloning or updating OpenClaw runtime" });
    try {
      const result = await cloneOpenClawRepo(form.repoUrl, `${form.installRoot}/app/openclaw-runtime`, form.repoBranch);
      setCloneResult(result);
      updateStage("repo", {
        status: "succeeded",
        detail: `${result.status} ${result.headRef ?? "unknown revision"}`
      });
    } catch (cause) {
      const message = cause instanceof Error ? cause.message : String(cause);
      setError(message);
      updateStage("repo", { status: "failed", detail: message });
    } finally {
      setBusy(false);
    }
  }

  async function handleRenderConfig() {
    setBusy(true);
    setError(null);
    updateStage("config", { status: "running", detail: "Rendering prod/mac config bundle" });
    updateStage("launchAgent", { status: "running", detail: "Generating LaunchAgent plist templates" });
    try {
      const runtimeRepoDir = cloneResult?.targetDir ?? `${form.installRoot}/app/openclaw-runtime`;
      const result = await renderProdMacConfig(form, controlPlaneDir, runtimeRepoDir);
      setRenderResult(result);
      updateStage("config", {
        status: "succeeded",
        detail: `${result.generatedFiles.length} files generated`
      });
      updateStage("launchAgent", {
        status: "succeeded",
        detail: "LaunchAgent plist files generated"
      });
      updateStage("channels", {
        status: "succeeded",
        detail: "Channel env/config placeholders rendered"
      });
      updateStage("litellm", {
        status: "succeeded",
        detail: "LiteLLM config rendered; runtime install still pending"
      });
    } catch (cause) {
      const message = cause instanceof Error ? cause.message : String(cause);
      setError(message);
      updateStage("config", { status: "failed", detail: message });
      updateStage("launchAgent", { status: "failed", detail: message });
    } finally {
      setBusy(false);
    }
  }

  async function handleSmokeCheck() {
    setBusy(true);
    setError(null);
    updateStage("smoke", { status: "running", detail: "Running prod/mac smoke checks" });
    try {
      const result = await runProdMacSmokeCheck(form.installRoot);
      setSmokeResult(result);
      const failed = result.checks.filter((item) => !item.ok).length;
      updateStage("smoke", {
        status: failed === 0 ? "succeeded" : "failed",
        detail: failed === 0 ? "All smoke checks passed" : `${failed} smoke checks failed`
      });
    } catch (cause) {
      const message = cause instanceof Error ? cause.message : String(cause);
      setError(message);
      updateStage("smoke", { status: "failed", detail: message });
    } finally {
      setBusy(false);
    }
  }

  async function handleProvisionLiteLlm() {
    setBusy(true);
    setError(null);
    updateStage("litellm", { status: "running", detail: "Installing LiteLLM and generating service scripts" });
    try {
      const result = await provisionLiteLlmProdMac(form.installRoot);
      setProvisionResult(result);
      const failed = result.steps.filter((item) => !item.ok).length;
      updateStage("litellm", {
        status: failed === 0 ? "succeeded" : "failed",
        detail: failed === 0 ? "LiteLLM provisioning completed" : `${failed} provisioning steps failed`
      });
    } catch (cause) {
      const message = cause instanceof Error ? cause.message : String(cause);
      setError(message);
      updateStage("litellm", { status: "failed", detail: message });
    } finally {
      setBusy(false);
    }
  }

  async function handleProvisionRuntime() {
    setBusy(true);
    setError(null);
    updateStage("repo", { status: "running", detail: "Building OpenClaw runtime from source" });
    try {
      const runtimeRepoDir = cloneResult?.targetDir ?? `${form.installRoot}/app/openclaw-runtime`;
      const result = await provisionOpenClawRuntime(runtimeRepoDir);
      setRuntimeProvisionResult(result);
      const failed = result.steps.filter((item) => !item.ok).length;
      updateStage("repo", {
        status: failed === 0 ? "succeeded" : "failed",
        detail: failed === 0 ? "OpenClaw source build completed" : `${failed} runtime build steps failed`
      });
    } catch (cause) {
      const message = cause instanceof Error ? cause.message : String(cause);
      setError(message);
      updateStage("repo", { status: "failed", detail: message });
    } finally {
      setBusy(false);
    }
  }

  async function handleLaunchAgent(action: "load" | "unload" | "status", service: "litellm" | "runtime") {
    setBusy(true);
    setError(null);
    try {
      const result = await launchAgentAction(action, form.installRoot, service);
      setServiceEvents((items) => [result, ...items].slice(0, 8));
      updateStage("launchAgent", {
        status: result.ok ? "succeeded" : "failed",
        detail: `${service} ${action}: ${result.ok ? "ok" : "failed"}`
      });
    } catch (cause) {
      const message = cause instanceof Error ? cause.message : String(cause);
      setError(message);
      updateStage("launchAgent", { status: "failed", detail: message });
    } finally {
      setBusy(false);
    }
  }

  function nextStep() {
    if (canGoNext) {
      setActiveStep(steps[stepIndex + 1].id);
    }
  }

  function previousStep() {
    if (canGoBack) {
      setActiveStep(steps[stepIndex - 1].id);
    }
  }

  return (
    <div className="shell">
      <aside className="sidebar">
        <div>
          <p className="eyebrow">OpenClaw</p>
          <h1>macOS Setup App</h1>
          <p className="muted">Tauri installer scaffold for `prod/mac`.</p>
        </div>
        <ol className="stepList">
          {steps.map((step, index) => (
            <li key={step.id} className={step.id === activeStep ? "step active" : "step"}>
              <span>{String(index + 1).padStart(2, "0")}</span>
              <div>
                <strong>{step.title}</strong>
                <p>{step.description}</p>
              </div>
            </li>
          ))}
        </ol>
      </aside>

      <main className="content">
        <header className="panel hero">
          <div>
            <p className="eyebrow">Installer Flow</p>
            <h2>{currentStep.title}</h2>
            <p>{currentStep.description}</p>
          </div>
          <div className="pill">{busy ? "Working" : "Ready"}</div>
        </header>

        <section className="panel grid">
          <article className="card span-8">{renderStep()}</article>
          <aside className="card span-4">
            <h3>Plan Snapshot</h3>
            <ul className="statusList">
              {stages.map((stage) => (
                <li key={stage.id}>
                  <strong>{stage.label}</strong>
                  <span className={`status ${stage.status}`}>{stage.status}</span>
                  <p>{stage.detail}</p>
                </li>
              ))}
            </ul>
          </aside>
        </section>

        <section className="panel grid compact">
          <article className="card span-7">
            <h3>Review Summary</h3>
            <dl className="summary">
              {summary.map(([label, value]) => (
                <div key={label}>
                  <dt>{label}</dt>
                  <dd>{value}</dd>
                </div>
              ))}
            </dl>
          </article>
          <article className="card span-5">
            <h3>Installer Notes</h3>
            <ul className="notes">
              <li>`prod/mac` is the only target in v1.</li>
              <li>Feishu and Telegram are real setup targets.</li>
              <li>WhatsApp stays as a placeholder in v1.</li>
              <li>Later steps will render configs and LaunchAgents outside Git.</li>
            </ul>
          </article>
        </section>

        {error ? (
          <section className="panel errorPanel">
            <strong>Command Error</strong>
            <p>{error}</p>
          </section>
        ) : null}

        <footer className="footer">
          <button className="secondary" onClick={previousStep} disabled={!canGoBack || busy}>
            Back
          </button>
          <button className="primary" onClick={nextStep} disabled={!canGoNext || busy}>
            Next
          </button>
        </footer>
      </main>
    </div>
  );

  function renderStep() {
    switch (activeStep) {
      case "welcome":
        return (
          <div className="stack">
            <h3>Installation Profile</h3>
            <label>
              Install root
              <input
                value={form.installRoot}
                onChange={(event) => setForm({ ...form, installRoot: event.target.value })}
              />
            </label>
            <p className="muted">
              Runtime files, generated configs, logs and LaunchAgent assets should live outside this control-plane repo.
            </p>
          </div>
        );
      case "environment":
        return (
          <div className="stack">
            <div className="toolbar">
              <div>
                <h3>Environment Doctor</h3>
                <p className="muted">Check for core tools before provisioning `prod/mac`.</p>
              </div>
              <button className="primary" onClick={handleDoctorCheck} disabled={busy}>
                Run Check
              </button>
            </div>
            {doctorResult ? (
              <div className="doctorResults">
                <p>
                  Platform: <strong>{doctorResult.platform}</strong> / <strong>{doctorResult.architecture}</strong>
                </p>
                <ul className="statusList">
                  {doctorResult.checks.map((check) => (
                    <li key={check.name}>
                      <strong>{check.name}</strong>
                      <span className={`status ${check.found ? "succeeded" : "failed"}`}>
                        {check.found ? "found" : "missing"}
                      </span>
                      <p>{check.version ? `${check.version} · ` : ""}{check.detail}</p>
                    </li>
                  ))}
                </ul>
              </div>
            ) : (
              <p className="muted">No check has been executed yet.</p>
            )}
          </div>
        );
      case "source":
        return (
          <div className="stack">
            <h3>OpenClaw Runtime Source</h3>
            <label>
              GitHub repo URL
              <input value={form.repoUrl} onChange={(event) => setForm({ ...form, repoUrl: event.target.value })} />
            </label>
            <label>
              Branch or tag
              <input value={form.repoBranch} onChange={(event) => setForm({ ...form, repoBranch: event.target.value })} />
            </label>
            <button className="primary" onClick={handleCloneRepo} disabled={busy}>
              Clone or Update
            </button>
            {cloneResult ? (
              <div className="resultBox">
                <p>Status: <strong>{cloneResult.status}</strong></p>
                <p>Target: <code>{cloneResult.targetDir}</code></p>
                <p>Revision: <code>{cloneResult.headRef ?? "unknown"}</code></p>
              </div>
            ) : null}
          </div>
        );
      case "providers":
        return (
          <div className="stack">
            <h3>Provider Keys</h3>
            {renderMaskedInput("Gemini API key", "gemini")}
            {renderMaskedInput("MiniMax API key", "minimax")}
            {renderMaskedInput("DashScope API key", "dashscope")}
            {renderMaskedInput("OpenRouter API key", "openrouter")}
            {renderMaskedInput("SiliconFlow API key", "siliconflow")}
            <h3>Memory</h3>
            <label>
              Mem0 API key
              <input
                type="password"
                value={form.memory.mem0ApiKey}
                onChange={(event) =>
                  setForm({ ...form, memory: { ...form.memory, mem0ApiKey: event.target.value } })
                }
              />
            </label>
            <label>
              Mem0 API base
              <input
                value={form.memory.mem0ApiBase}
                onChange={(event) =>
                  setForm({ ...form, memory: { ...form.memory, mem0ApiBase: event.target.value } })
                }
              />
            </label>
            <label>
              Ollama host
              <input
                value={form.memory.ollamaHost}
                onChange={(event) =>
                  setForm({ ...form, memory: { ...form.memory, ollamaHost: event.target.value } })
                }
              />
            </label>
            <label>
              Embedding model
              <input
                value={form.memory.embeddingModel}
                onChange={(event) =>
                  setForm({ ...form, memory: { ...form.memory, embeddingModel: event.target.value } })
                }
              />
            </label>
          </div>
        );
      case "channels":
        return (
          <div className="stack">
            <h3>Channel Wizard</h3>
            <label>
              Feishu App ID
              <input
                value={form.channels.feishuAppId}
                onChange={(event) =>
                  setForm({ ...form, channels: { ...form.channels, feishuAppId: event.target.value } })
                }
              />
            </label>
            <label>
              Feishu App Secret
              <input
                type="password"
                value={form.channels.feishuAppSecret}
                onChange={(event) =>
                  setForm({ ...form, channels: { ...form.channels, feishuAppSecret: event.target.value } })
                }
              />
            </label>
            <label>
              Telegram Bot Token
              <input
                type="password"
                value={form.channels.telegramBotToken}
                onChange={(event) =>
                  setForm({ ...form, channels: { ...form.channels, telegramBotToken: event.target.value } })
                }
              />
            </label>
            <label>
              WhatsApp account name
              <input
                value={form.channels.whatsappAccountName}
                onChange={(event) =>
                  setForm({ ...form, channels: { ...form.channels, whatsappAccountName: event.target.value } })
                }
              />
            </label>
            <p className="muted">WhatsApp remains a placeholder in v1 and is not part of smoke validation.</p>
          </div>
        );
      case "launchAgent":
        return (
          <div className="stack">
            <h3>LaunchAgent Plan</h3>
            <label className="toggle">
              <input
                type="checkbox"
                checked={form.launchAtLogin}
                onChange={(event) => setForm({ ...form, launchAtLogin: event.target.checked })}
              />
              Register LiteLLM and OpenClaw LaunchAgents at login
            </label>
            <p className="muted">
              A later revision will generate user-level plist files under `~/Library/LaunchAgents`.
            </p>
          </div>
        );
      case "review":
        return (
          <div className="stack">
            <h3>Current Scope</h3>
            <p>
              This revision now supports three concrete installer actions: environment doctor, runtime repo clone, and
              `prod/mac` config plus LaunchAgent template rendering. Smoke checks can validate the rendered bundle and
              local LiteLLM readiness endpoint.
            </p>
            <div className="toolbar">
              <button className="secondary" onClick={handleProvisionRuntime} disabled={busy}>
                Build OpenClaw Runtime
              </button>
              <button className="secondary" onClick={handleProvisionLiteLlm} disabled={busy}>
                Provision LiteLLM
              </button>
              <button className="secondary" onClick={handleRenderConfig} disabled={busy}>
                Render prod/mac Config
              </button>
              <button className="primary" onClick={handleSmokeCheck} disabled={busy}>
                Run Smoke Check
              </button>
            </div>
            {renderResult ? (
              <div className="resultBox">
                <strong>Generated files</strong>
                <ul className="notes">
                  {renderResult.generatedFiles.map((item) => (
                    <li key={item.path}>
                      <code>{item.kind}</code> {item.path}
                    </li>
                  ))}
                </ul>
              </div>
            ) : null}
            {smokeResult ? (
              <div className="resultBox">
                <strong>Smoke checks</strong>
                <ul className="notes">
                  {smokeResult.checks.map((item) => (
                    <li key={item.name}>
                      {item.ok ? "PASS" : "FAIL"} {item.name}: {item.detail}
                    </li>
                  ))}
                </ul>
              </div>
            ) : null}
            {provisionResult ? (
              <div className="resultBox">
                <strong>LiteLLM provisioning</strong>
                <ul className="notes">
                  {provisionResult.steps.map((item) => (
                    <li key={item.name}>
                      {item.ok ? "PASS" : "FAIL"} {item.name}: {item.detail}
                    </li>
                  ))}
                </ul>
              </div>
            ) : null}
            {runtimeProvisionResult ? (
              <div className="resultBox">
                <strong>OpenClaw source build</strong>
                <ul className="notes">
                  {runtimeProvisionResult.steps.map((item) => (
                    <li key={item.name}>
                      {item.ok ? "PASS" : "FAIL"} {item.name}: {item.detail}
                    </li>
                  ))}
                </ul>
              </div>
            ) : null}
            <div className="resultBox">
              <strong>LaunchAgent controls</strong>
              <div className="toolbar wrap">
                <button className="secondary" onClick={() => handleLaunchAgent("load", "litellm")} disabled={busy}>
                  Load LiteLLM
                </button>
                <button className="secondary" onClick={() => handleLaunchAgent("status", "litellm")} disabled={busy}>
                  LiteLLM Status
                </button>
                <button className="secondary" onClick={() => handleLaunchAgent("unload", "litellm")} disabled={busy}>
                  Unload LiteLLM
                </button>
              </div>
              <div className="toolbar wrap">
                <button className="secondary" onClick={() => handleLaunchAgent("load", "runtime")} disabled={busy}>
                  Load Runtime
                </button>
                <button className="secondary" onClick={() => handleLaunchAgent("status", "runtime")} disabled={busy}>
                  Runtime Status
                </button>
                <button className="secondary" onClick={() => handleLaunchAgent("unload", "runtime")} disabled={busy}>
                  Unload Runtime
                </button>
              </div>
              {serviceEvents.length > 0 ? (
                <ul className="notes">
                  {serviceEvents.map((event, index) => (
                    <li key={`${event.service}-${event.action}-${index}`}>
                      {event.ok ? "PASS" : "FAIL"} {event.service} {event.action}: {event.detail || "(no output)"}
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
      <label>
        {label}
        <input
          type="password"
          value={form.providerKeys[key]}
          onChange={(event) =>
            setForm({
              ...form,
              providerKeys: { ...form.providerKeys, [key]: event.target.value }
            })
          }
        />
      </label>
    );
  }
}
