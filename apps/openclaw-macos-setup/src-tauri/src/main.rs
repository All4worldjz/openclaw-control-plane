mod commands;
mod models;

use commands::{clone_openclaw_repo, doctor_check, render_prod_mac_config, smoke_check_prod_mac};
use commands::{
    launch_agent_load, launch_agent_status, launch_agent_unload, provision_litellm_prod_mac,
    provision_openclaw_runtime_prod_mac,
};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            doctor_check,
            clone_openclaw_repo,
            render_prod_mac_config,
            smoke_check_prod_mac,
            provision_litellm_prod_mac,
            provision_openclaw_runtime_prod_mac,
            launch_agent_load,
            launch_agent_unload,
            launch_agent_status
        ])
        .run(tauri::generate_context!())
        .expect("error while running OpenClaw macOS Setup");
}

fn main() {
    run();
}
