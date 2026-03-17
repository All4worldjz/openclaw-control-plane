import { invoke } from "@tauri-apps/api/core";
import type {
  DoctorCheckResult,
  InstallOpenClawResult,
  InstallerForm,
  LaunchAgentCommandResult,
  ProvisionLiteLlmResult,
  RenderConfigResult,
  SmokeCheckResult,
} from "../types";

export async function runDoctorCheck(): Promise<DoctorCheckResult> {
  return invoke<DoctorCheckResult>("doctor_check");
}

export async function installOpenclaw(version = ""): Promise<InstallOpenClawResult> {
  return invoke<InstallOpenClawResult>("install_openclaw", { request: { version } });
}

export async function renderProdMacConfig(form: InstallerForm): Promise<RenderConfigResult> {
  return invoke<RenderConfigResult>("render_prod_mac_config", {
    request: {
      installRoot: form.installRoot,
      providerKeys: form.providerKeys,
      channels: form.channels,
      memory: form.memory,
      launchAtLogin: form.launchAtLogin,
    },
  });
}

export async function runProdMacSmokeCheck(installRoot: string): Promise<SmokeCheckResult> {
  return invoke<SmokeCheckResult>("smoke_check_prod_mac", { request: { installRoot } });
}

export async function provisionLiteLlmProdMac(installRoot: string): Promise<ProvisionLiteLlmResult> {
  return invoke<ProvisionLiteLlmResult>("provision_litellm_prod_mac", { request: { installRoot } });
}

export async function launchAgentAction(
  action: "load" | "unload" | "status",
  installRoot: string,
  service: "litellm" | "runtime"
): Promise<LaunchAgentCommandResult> {
  const command = action === "load" ? "launch_agent_load"
    : action === "unload" ? "launch_agent_unload"
    : "launch_agent_status";
  return invoke<LaunchAgentCommandResult>(command, { request: { installRoot, service } });
}
