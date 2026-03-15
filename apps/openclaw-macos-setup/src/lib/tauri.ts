import { invoke } from "@tauri-apps/api/core";
import type {
  CloneRepoResult,
  DoctorCheckResult,
  InstallerForm,
  LaunchAgentCommandResult,
  ProvisionLiteLlmResult,
  ProvisionOpenClawRuntimeResult,
  RenderConfigResult,
  SmokeCheckResult
} from "../types";

export async function runDoctorCheck(): Promise<DoctorCheckResult> {
  return invoke<DoctorCheckResult>("doctor_check");
}

export async function cloneOpenClawRepo(repoUrl: string, targetDir: string, branch?: string): Promise<CloneRepoResult> {
  return invoke<CloneRepoResult>("clone_openclaw_repo", {
    request: {
      repoUrl,
      targetDir,
      branch: branch?.trim() || null
    }
  });
}

export async function renderProdMacConfig(
  form: InstallerForm,
  controlPlaneDir: string,
  runtimeRepoDir: string
): Promise<RenderConfigResult> {
  return invoke<RenderConfigResult>("render_prod_mac_config", {
    request: {
      installRoot: form.installRoot,
      controlPlaneDir,
      runtimeRepoDir,
      providerKeys: form.providerKeys,
      channels: form.channels,
      memory: form.memory,
      launchAtLogin: form.launchAtLogin
    }
  });
}

export async function runProdMacSmokeCheck(installRoot: string): Promise<SmokeCheckResult> {
  return invoke<SmokeCheckResult>("smoke_check_prod_mac", {
    request: {
      installRoot
    }
  });
}

export async function provisionLiteLlmProdMac(installRoot: string): Promise<ProvisionLiteLlmResult> {
  return invoke<ProvisionLiteLlmResult>("provision_litellm_prod_mac", {
    request: {
      installRoot
    }
  });
}

export async function provisionOpenClawRuntime(runtimeRepoDir: string): Promise<ProvisionOpenClawRuntimeResult> {
  return invoke<ProvisionOpenClawRuntimeResult>("provision_openclaw_runtime_prod_mac", {
    request: {
      runtimeRepoDir
    }
  });
}

export async function launchAgentAction(
  action: "load" | "unload" | "status",
  installRoot: string,
  service: "litellm" | "runtime"
): Promise<LaunchAgentCommandResult> {
  const command =
    action === "load"
      ? "launch_agent_load"
      : action === "unload"
        ? "launch_agent_unload"
        : "launch_agent_status";

  return invoke<LaunchAgentCommandResult>(command, {
    request: {
      installRoot,
      service
    }
  });
}
