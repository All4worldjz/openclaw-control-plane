use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize)]
pub struct DoctorCheckItem {
    pub name: String,
    pub required: bool,
    pub found: bool,
    pub version: Option<String>,
    pub detail: String,
}

#[derive(Debug, Serialize)]
pub struct DoctorCheckResult {
    pub platform: String,
    pub architecture: String,
    pub checks: Vec<DoctorCheckItem>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CloneRepoRequest {
    pub repo_url: String,
    pub target_dir: String,
    pub branch: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CloneRepoResult {
    pub target_dir: String,
    pub branch: Option<String>,
    pub status: String,
    pub head_ref: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProviderKeys {
    pub gemini: String,
    pub minimax: String,
    pub dashscope: String,
    pub openrouter: String,
    pub siliconflow: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ChannelConfig {
    pub feishu_app_id: String,
    pub feishu_app_secret: String,
    pub feishu_verification_token: String,
    pub feishu_encrypt_key: String,
    pub telegram_bot_token: String,
    pub whatsapp_account_name: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MemoryConfig {
    pub mem0_api_key: String,
    pub mem0_api_base: String,
    pub ollama_host: String,
    pub embedding_model: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RenderConfigRequest {
    pub install_root: String,
    pub control_plane_dir: String,
    pub runtime_repo_dir: String,
    pub provider_keys: ProviderKeys,
    pub channels: ChannelConfig,
    pub memory: MemoryConfig,
    pub launch_at_login: bool,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RenderedFile {
    pub path: String,
    pub kind: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RenderConfigResult {
    pub profile: String,
    pub generated_files: Vec<RenderedFile>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SmokeCheckRequest {
    pub install_root: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SmokeCheckItem {
    pub name: String,
    pub ok: bool,
    pub detail: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SmokeCheckResult {
    pub checks: Vec<SmokeCheckItem>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProvisionLiteLlmRequest {
    pub install_root: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProvisionLiteLlmResult {
    pub steps: Vec<ProvisionStep>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProvisionStep {
    pub name: String,
    pub ok: bool,
    pub detail: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LaunchAgentCommandRequest {
    pub install_root: String,
    pub service: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LaunchAgentCommandResult {
    pub service: String,
    pub action: String,
    pub ok: bool,
    pub detail: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProvisionOpenClawRuntimeRequest {
    pub runtime_repo_dir: String,
}
