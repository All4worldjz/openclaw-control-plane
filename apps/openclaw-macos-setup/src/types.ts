export type InstallStepId =
  | "welcome"
  | "environment"
  | "source"
  | "providers"
  | "channels"
  | "launchAgent"
  | "review";

export type InstallStageStatus = "idle" | "running" | "succeeded" | "failed";

export type InstallStage = {
  id: string;
  label: string;
  status: InstallStageStatus;
  detail: string;
};

export type DoctorCheckItem = {
  name: string;
  required: boolean;
  found: boolean;
  version?: string | null;
  detail: string;
};

export type DoctorCheckResult = {
  platform: string;
  architecture: string;
  checks: DoctorCheckItem[];
};

export type CloneRepoResult = {
  targetDir: string;
  branch: string | null;
  status: "cloned" | "updated";
  headRef: string | null;
};

export type ProviderKeys = {
  gemini: string;
  minimax: string;
  dashscope: string;
  openrouter: string;
  siliconflow: string;
};

export type ChannelConfig = {
  feishuAppId: string;
  feishuAppSecret: string;
  feishuVerificationToken: string;
  feishuEncryptKey: string;
  telegramBotToken: string;
  whatsappAccountName: string;
};

export type MemoryConfig = {
  mem0ApiKey: string;
  mem0ApiBase: string;
  ollamaHost: string;
  embeddingModel: string;
};

export type InstallerForm = {
  installRoot: string;
  repoUrl: string;
  repoBranch: string;
  providerKeys: ProviderKeys;
  channels: ChannelConfig;
  memory: MemoryConfig;
  launchAtLogin: boolean;
};

export type RenderedFile = {
  path: string;
  kind: string;
};

export type RenderConfigResult = {
  profile: string;
  generatedFiles: RenderedFile[];
};

export type SmokeCheckItem = {
  name: string;
  ok: boolean;
  detail: string;
};

export type SmokeCheckResult = {
  checks: SmokeCheckItem[];
};

export type ProvisionStep = {
  name: string;
  ok: boolean;
  detail: string;
};

export type ProvisionLiteLlmResult = {
  steps: ProvisionStep[];
};

export type ProvisionOpenClawRuntimeResult = {
  steps: ProvisionStep[];
};

export type LaunchAgentCommandResult = {
  service: string;
  action: string;
  ok: boolean;
  detail: string;
};
