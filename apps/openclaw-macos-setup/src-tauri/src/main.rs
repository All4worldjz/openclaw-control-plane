mod commands;
mod models;

use commands::{
    doctor_check,
    install_openclaw,
    render_prod_mac_config,
    provision_litellm_prod_mac,
    smoke_check_prod_mac,
    launch_agent_load,
    launch_agent_unload,
    launch_agent_status,
};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            doctor_check,
            install_openclaw,
            render_prod_mac_config,
            provision_litellm_prod_mac,
            smoke_check_prod_mac,
            launch_agent_load,
            launch_agent_unload,
            launch_agent_status,
        ])
        .run(tauri::generate_context!())
        .expect("error while running OpenClaw macOS Setup");
}

fn main() {
    run();
}
